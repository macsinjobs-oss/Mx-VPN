#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
output=${1:-"$root/dist"}
mkdir -p "$output"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT HUP INT TERM
mkdir -p "$stage/DEBIAN" "$stage/usr/lib/mxvpn" "$stage/usr/bin" "$stage/usr/share/applications" "$stage/usr/share/doc/mxvpn"
cat > "$stage/DEBIAN/control" <<'CONTROL'
Package: mxvpn
Version: 0.1.0-1
Section: net
Priority: optional
Architecture: all
Maintainer: Mx VPN <macsinjobs-oss@users.noreply.github.com>
Depends: python3 (>= 3.10), python3-gi, gir1.2-gtk-3.0, network-manager (>= 1.36), policykit-1
Description: Simple WireGuard VPN client for Linux Mint
 Import a private WireGuard profile and connect through NetworkManager.
 No custom privileged helper, automatic connection or bundled credentials.
CONTROL
install -m 644 "$root/mxvpn_core.py" "$root/mxvpn_gui.py" "$stage/usr/lib/mxvpn/"
install -m 755 "$root/mxvpn" "$stage/usr/bin/mxvpn"
install -m 644 "$root/mxvpn.desktop" "$stage/usr/share/applications/"
install -m 644 "$root/README.md" "$stage/usr/share/doc/mxvpn/"
cp "$root/../LICENSE" "$stage/usr/share/doc/mxvpn/copyright"
dpkg-deb --root-owner-group --build "$stage" "$output/mxvpn_0.1.0-1_all.deb"
