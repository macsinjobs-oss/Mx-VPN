#!/bin/bash
# Personal local development installer. Run only after reviewing and approving
# persistent root helper installation. No configuration files are installed.
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
source_app="${MX_INSTALL_SOURCE:-$script_dir/../build-mx-package/Mx VPN.app}"
target_app="/Applications/Mx VPN.app"
trust_dir="/Library/Application Support/MxVPN"
daemon_plist="/Library/LaunchDaemons/org.macsinjobs.mxvpn.helper.plist"

fail() { echo "$1" >&2; exit 2; }
[[ -d "$source_app" && ! -L "$source_app" ]] || fail "Packaged Mx app missing or symlinked."
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$source_app/Contents/Info.plist")" == org.macsinjobs.mxvpn ]] || fail "Unexpected app identity."
codesign --verify --deep --strict "$source_app"
for executable in 'Mx VPN' MxVPN-service amneziawg-go openvpn tun2socks; do
    codesign --verify --strict "$source_app/Contents/MacOS/$executable"
done
client_signing="$(codesign -dvv "$source_app/Contents/MacOS/Mx VPN" 2>&1)"
[[ "$client_signing" == *runtime* ]] || fail "Client must have hardened runtime enabled."
team_id="$(printf '%s\n' "$client_signing" | sed -n 's/^TeamIdentifier=//p')"
[[ "$team_id" =~ ^[A-Z0-9]{10}$ ]] || fail "Real Apple development signing identity required; ad-hoc runtime package rejected."
for executable in MxVPN-service amneziawg-go openvpn tun2socks; do
    executable_team="$(codesign -dvv "$source_app/Contents/MacOS/$executable" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
    [[ "$executable_team" == "$team_id" ]] || fail "Nested executable signing team mismatch."
done
[[ ! -e "$target_app" && ! -L "$target_app" ]] || fail "Existing Mx installation requires a separate reviewed update."
[[ ! -e "$trust_dir" && ! -L "$trust_dir" ]] || fail "Existing Mx trust directory requires a separate reviewed update."
[[ ! -e "$daemon_plist" && ! -L "$daemon_plist" ]] || fail "Existing Mx LaunchDaemon requires a separate reviewed update."
if [[ "${1:-}" == --check ]]; then
    echo "Package signatures, identity and fresh-install destinations passed preflight."
    exit 0
fi
[[ "$(id -u)" == 0 ]] || fail "Administrator authorization required. Review this installer before running it with sudo."
[[ "${1:-}" == --install ]] || fail "Use --check for preflight, or --install after explicit installation approval."

ditto "$source_app" "$target_app"
chown -R root:wheel "$target_app"
chmod -R a-w "$target_app"
codesign --verify --deep --strict "$target_app"
client_hash="$(codesign -dvvv "$target_app/Contents/MacOS/Mx VPN" 2>&1 | sed -n 's/^CDHash=//p')"
[[ "$client_hash" =~ ^[0-9a-f]{40}$ ]] || fail "Final client code hash unavailable. Helper was not started."
install -d -o root -g wheel -m 755 "$trust_dir"
printf '%s\n' "$client_hash" > "$trust_dir/client.cdhash"
chown root:wheel "$trust_dir/client.cdhash"
chmod 644 "$trust_dir/client.cdhash"
install -o root -g wheel -m 644 "$script_dir/org.macsinjobs.mxvpn.helper.plist" "$daemon_plist"
plutil -lint "$daemon_plist"
launchctl bootstrap system "$daemon_plist"
launchctl print system/org.macsinjobs.mxvpn.helper
echo "Helper installed and registered. Real VPN behavior still requires testing."
