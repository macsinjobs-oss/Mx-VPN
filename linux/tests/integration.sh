#!/bin/bash
# Run inside a disposable Linux CI runner: sudo unshare --mount bash this-file.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
client="mxclient$$"
server="mxserver$$"
cleanup() {
  result=$?
  if [[ "$result" != 0 && -f "$work/nm.log" ]]; then
    sed -n "/failed\|error\|unmanaged\|unavailable\|activation/p" "$work/nm.log" | tail -25
  fi
  for ns in "$client" "$server"; do
    ip netns pids "$ns" 2>/dev/null | xargs -r kill 2>/dev/null || true
    ip netns del "$ns" 2>/dev/null || true
  done
  rm -rf "$work"
}
trap cleanup EXIT
mount --make-rprivate /
mkdir -p "$work/nm-etc/system-connections" "$work/nm-run" "$work/nm-var"
mkdir -p /etc/NetworkManager /run/NetworkManager /var/lib/NetworkManager
mount --bind "$work/nm-etc" /etc/NetworkManager
mount --bind "$work/nm-run" /run/NetworkManager
mount --bind "$work/nm-var" /var/lib/NetworkManager
ip netns add "$client"
ip netns add "$server"
ip link add mxvethc type veth peer name mxveths
ip link set mxvethc netns "$client"
ip link set mxveths netns "$server"
ip -n "$client" addr add 192.0.2.2/24 dev mxvethc
ip -n "$server" addr add 192.0.2.1/24 dev mxveths
for ns in "$client" "$server"; do ip -n "$ns" link set lo up; done
ip -n "$client" link set mxvethc up
ip -n "$server" link set mxveths up
umask 077
wg genkey > "$work/client.key"
wg genkey > "$work/server.key"
wg pubkey < "$work/client.key" > "$work/client.pub"
wg pubkey < "$work/server.key" > "$work/server.pub"
ip -n "$server" link add wgsrv type wireguard
ip netns exec "$server" wg set wgsrv private-key "$work/server.key" listen-port 51820 peer "$(cat "$work/client.pub")" allowed-ips 10.111.0.2/32,fd11::2/128
ip -n "$server" addr add 10.111.0.1/24 dev wgsrv
ip -n "$server" -6 addr add fd11::1/64 dev wgsrv
ip -n "$server" link set wgsrv up
cat > "$work/houston-test.conf" <<EOF
[Interface]
PrivateKey = $(cat "$work/client.key")
Address = 10.111.0.2/32, fd11::2/128
DNS = 10.111.0.1, fd11::1
[Peer]
PublicKey = $(cat "$work/server.pub")
Endpoint = 192.0.2.1:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF
cat > "$work/NetworkManager.conf" <<EOF
[main]
plugins=keyfile
dns=none
[device-test-link]
match-device=interface-name:mxvethc
managed=0
EOF
ip netns exec "$client" dbus-daemon --system --nofork --nopidfile --address="unix:path=$work/system-bus" > "$work/dbus.log" 2>&1 &
export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$work/system-bus"
for attempt in $(seq 1 50); do [[ -S "$work/system-bus" ]] && break; sleep .1; done
ip netns exec "$client" /usr/sbin/NetworkManager --no-daemon --config="$work/NetworkManager.conf" --state-file="$work/nm.state" --pid-file="$work/nm.pid" > "$work/nm.log" 2>&1 &
ready=false
for attempt in $(seq 1 50); do
  if ip netns exec "$client" nmcli general status >/dev/null 2>&1; then ready=true; break; fi
  sleep .2
 done
[[ "$ready" == true ]] || { echo 'Isolated NetworkManager startup failed'; exit 1; }
mkdir -m 700 "$work/xdg"
export XDG_RUNTIME_DIR="$work/xdg"
export MX_TEST_CONFIG="$work/houston-test.conf"
export MX_SCREENSHOT="$root/dist/linux-connected.png"
ip netns exec "$client" dbus-run-session -- xvfb-run -a python3 "$root/tests/live_flow.py"
# Confirm root-only NetworkManager profile storage while mounted privately.
if find /etc/NetworkManager/system-connections -type f -perm /077 | grep -q .; then echo 'Profile permissions were too broad'; exit 1; fi
printf 'Isolated WireGuard integration and secret-storage checks passed.\n'
