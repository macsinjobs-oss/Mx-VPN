"""Strict WireGuard import and scoped NetworkManager operations."""
import base64
import binascii
import configparser
import pwd
import ipaddress
import os
import re
import stat
import subprocess
import sys
import uuid
from dataclasses import dataclass
from pathlib import Path

PREFIX = "Mx VPN - "
MAX_CONFIG = 65536


class ConfigError(ValueError):
    pass


class VpnError(RuntimeError):
    pass


def _key(value):
    try:
        decoded = base64.b64decode(value, validate=True)
        return len(decoded) == 32 and any(decoded)
    except (ValueError, binascii.Error):
        return False


def _items(value):
    return [part.strip() for part in value.split(",") if part.strip()]


def validate_config(text):
    """Return validated text; never include input values in diagnostics."""
    if not text or len(text.encode("utf-8")) > MAX_CONFIG or "\x00" in text:
        raise ConfigError("Configuration is empty, oversized or invalid.")
    parser = configparser.ConfigParser(interpolation=None, strict=True, inline_comment_prefixes=("#", ";"))
    parser.optionxform = str
    try:
        parser.read_string(text)
        if set(parser.sections()) != {"Interface", "Peer"} or parser.defaults():
            raise ValueError()
        interface, peer = parser["Interface"], parser["Peer"]
        if set(interface) - {"PrivateKey", "Address", "DNS", "MTU", "ListenPort"}:
            raise ValueError()
        if set(peer) - {"PublicKey", "PresharedKey", "AllowedIPs", "Endpoint", "PersistentKeepalive"}:
            raise ValueError()
        if not _key(interface["PrivateKey"]) or not _key(peer["PublicKey"]):
            raise ValueError()
        if "PresharedKey" in peer and not _key(peer["PresharedKey"]):
            raise ValueError()
        addresses = [ipaddress.ip_interface(v) for v in _items(interface["Address"])]
        dns = [ipaddress.ip_address(v) for v in _items(interface["DNS"])]
        routes = [ipaddress.ip_network(v, strict=False) for v in _items(peer["AllowedIPs"])]
        if not addresses or not dns or ipaddress.ip_network("0.0.0.0/0") not in routes:
            raise ValueError()
        if any(v.version == 6 for v in addresses + dns + routes) and ipaddress.ip_network("::/0") not in routes:
            raise ValueError()
        endpoint = peer["Endpoint"]
        if endpoint.startswith("["):
            match = re.fullmatch(r"\[([^\]]+)\]:(\d+)", endpoint)
            if not match or ipaddress.ip_address(match[1]).version != 6:
                raise ValueError()
            port = int(match[2])
        else:
            host, port_text = endpoint.rsplit(":", 1)
            if not re.fullmatch(r"[A-Za-z0-9.-]+", host) or len(host) > 253:
                raise ValueError()
            port = int(port_text)
        if not 1 <= port <= 65535:
            raise ValueError()
        for section, field, minimum, maximum in [
            (interface, "MTU", 576, 65535), (interface, "ListenPort", 1, 65535),
            (peer, "PersistentKeepalive", 0, 65535),
        ]:
            if field in section and not minimum <= int(section[field]) <= maximum:
                raise ValueError()
    except (ValueError, KeyError, configparser.Error):
        raise ConfigError("Use a valid single-peer full-tunnel WireGuard configuration with tunnel DNS. Scripts are not allowed.") from None
    return text


def read_config(path):
    try:
        fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0))
        with os.fdopen(fd, "rb") as stream:
            metadata = os.fstat(stream.fileno())
            if not stat.S_ISREG(metadata.st_mode) or metadata.st_size > MAX_CONFIG:
                raise ConfigError("Choose a regular configuration file smaller than 64 KiB.")
            text = stream.read(MAX_CONFIG + 1).decode("utf-8-sig")
    except (OSError, UnicodeError):
        raise ConfigError("Configuration file could not be read safely.") from None
    return validate_config(text)


@dataclass(frozen=True)
class Profile:
    uuid: str
    name: str


def _split_escaped(line):
    fields, current, escaped = [], [], False
    for char in line:
        if escaped:
            current.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            fields.append("".join(current))
            current = []
        else:
            current.append(char)
    fields.append("".join(current))
    return fields


def parse_profiles(text):
    result = []
    for line in text.splitlines():
        fields = _split_escaped(line)
        if len(fields) != 3:
            continue
        identifier, name, kind = fields
        try:
            uuid.UUID(identifier)
        except ValueError:
            continue
        if kind == "wireguard" and name.startswith(PREFIX):
            result.append(Profile(identifier, name[len(PREFIX):]))
    return result


class NetworkManager:
    def _run(self, arguments):
        try:
            result = subprocess.run(
                ["nmcli", "--wait", "25", *arguments], capture_output=True,
                text=True, timeout=35, env={**os.environ, "LC_ALL": "C"},
            )
        except (OSError, subprocess.TimeoutExpired):
            raise VpnError("NetworkManager did not respond. Check the network service and try again.") from None
        if result.returncode:
            messages = {
                4: "VPN activation failed. Check your configuration and network connection.",
                6: "VPN could not be disconnected. Refresh its state and try again.",
                8: "NetworkManager is not running.",
                10: "VPN profile is no longer available.",
                13: "Network permission denied. Authorize the operation through Linux Mint's normal authentication prompt.",
            }
            raise VpnError(messages.get(result.returncode, "Network operation failed. Check the configuration and your network permissions."))
        return result.stdout.strip()

    def list_profiles(self):
        return parse_profiles(self._run(["--terse", "--fields", "UUID,NAME,TYPE", "connection", "show"]))

    def active_ids(self):
        return set(self._run(["--get-values", "UUID", "connection", "show", "--active"]).splitlines())

    def _owned(self, identifier):
        if identifier not in {profile.uuid for profile in self.list_profiles()}:
            raise VpnError("Select an available Mx VPN profile.")

    def _add_connection(self, settings):
        # Add complete settings atomically: importing via nmcli can enable
        # autoconnect before a subsequent modify operation disables it.
        import gi
        from gi.repository import Gio, GLib
        signatures = {
            "id": "s", "uuid": "s", "type": "s", "interface-name": "s",
            "autoconnect": "b", "permissions": "as", "method": "s",
            "address-data": "aa{sv}", "dns": None, "private-key": "s",
            "private-key-flags": "u", "peer-routes": "b", "peers": "aa{sv}",
            "mtu": "u", "listen-port": "u",
        }
        def dictionary(values):
            types = {"address": "s", "prefix": "u", "public-key": "s",
                     "preshared-key": "s", "preshared-key-flags": "u",
                     "endpoint": "s", "allowed-ips": "as", "persistent-keepalive": "u"}
            return {key: GLib.Variant(types[key], value) for key, value in values.items()}
        payload = {}
        for section, values in settings.items():
            payload[section] = {}
            for key, value in values.items():
                signature = signatures[key]
                if key == "dns": signature = "au" if section == "ipv4" else "aay"
                if key in {"address-data", "peers"}: value = [dictionary(item) for item in value]
                payload[section][key] = GLib.Variant(signature, value)
        try:
            bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
            bus.call_sync(
                "org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager/Settings",
                "org.freedesktop.NetworkManager.Settings", "AddConnection",
                GLib.Variant("(a{sa{sv}})", (payload,)), GLib.VariantType.new("(o)"),
                Gio.DBusCallFlags.ALLOW_INTERACTIVE_AUTHORIZATION, 30000, None,
            )
        except GLib.Error:
            raise VpnError("Import failed. Check NetworkManager and authorize the operation through Linux Mint's normal authentication prompt.") from None

    def import_profile(self, path):
        text = read_config(path)
        label = re.sub(r"[\x00-\x1f\x7f]", "", Path(path).stem).strip()[:60] or "WireGuard"
        parser = configparser.ConfigParser(interpolation=None, inline_comment_prefixes=("#", ";"))
        parser.optionxform = str
        parser.read_string(text)
        interface, peer = parser["Interface"], parser["Peer"]
        identifier = str(uuid.uuid4())
        peer_settings = {
            "public-key": peer["PublicKey"], "endpoint": peer["Endpoint"],
            "allowed-ips": _items(peer["AllowedIPs"]),
            "persistent-keepalive": int(peer.get("PersistentKeepalive", "0")),
        }
        if "PresharedKey" in peer:
            peer_settings.update({"preshared-key": peer["PresharedKey"], "preshared-key-flags": 0})
        settings = {
            "connection": {"id": PREFIX + label, "uuid": identifier, "type": "wireguard",
                           "interface-name": "mxwg" + identifier.replace("-", "")[:8],
                           "autoconnect": False, "permissions": ["user:" + pwd.getpwuid(os.getuid()).pw_name + ":"]},
            "wireguard": {"private-key": interface["PrivateKey"], "private-key-flags": 0,
                          "peer-routes": True, "peers": [peer_settings]},
        }
        for field, property_name in [("MTU", "mtu"), ("ListenPort", "listen-port")]:
            if field in interface: settings["wireguard"][property_name] = int(interface[field])
        addresses = [ipaddress.ip_interface(item) for item in _items(interface["Address"])]
        dns = [ipaddress.ip_address(item) for item in _items(interface["DNS"])]
        for version, section in [(4, "ipv4"), (6, "ipv6")]:
            family = [address for address in addresses if address.version == version]
            settings[section] = {"method": "manual" if family else "disabled"}
            if family:
                settings[section]["address-data"] = [{"address": str(address.ip), "prefix": address.network.prefixlen} for address in family]
                settings[section]["dns"] = [int.from_bytes(address.packed, sys.byteorder) if version == 4 else list(address.packed) for address in dns if address.version == version]
        self._add_connection(settings)
        return identifier

    def connect(self, identifier):
        self._owned(identifier)
        owned = {profile.uuid for profile in self.list_profiles()}
        for active in (self.active_ids() & owned) - {identifier}:
            self._run(["connection", "down", "uuid", active])
        self._run(["connection", "up", "uuid", identifier])

    def disconnect(self, identifier):
        self._owned(identifier)
        if identifier in self.active_ids():
            self._run(["connection", "down", "uuid", identifier])
