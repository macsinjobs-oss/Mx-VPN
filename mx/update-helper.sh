#!/bin/bash
# Update the approved personal installation while disconnected, with rollback.
set -euo pipefail
source_app="${MX_UPDATE_SOURCE:?Set MX_UPDATE_SOURCE to the verified candidate app.}"
target_app="/Applications/Mx VPN.app"
pending_app="/Applications/Mx VPN.pending.app"
trust_dir="/Library/Application Support/MxVPN"
plist="/Library/LaunchDaemons/org.macsinjobs.mxvpn.helper.plist"
label="org.macsinjobs.mxvpn.helper"
fail() { echo "$1" >&2; exit 2; }
for path in "$source_app" "$target_app" "$trust_dir" "$plist"; do
    [[ -e "$path" && ! -L "$path" ]] || fail "Missing or symlinked update path."
done
[[ ! -e "$pending_app" && ! -L "$pending_app" ]] || fail "Pending update already exists; preserve it for review."
[[ "$(stat -f '%u' "$target_app")" == 0 && "$(stat -f '%u' "$trust_dir")" == 0 ]] || fail "Installed app/trust must be root-owned."
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$source_app/Contents/Info.plist")" == org.macsinjobs.mxvpn ]] || fail "Unexpected app identity."
codesign --verify --deep --strict "$source_app"
codesign --verify --deep --strict "$target_app"
old_team="$(codesign -dvv "$target_app" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
new_team="$(codesign -dvv "$source_app" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
[[ "$old_team" =~ ^[A-Z0-9]{10}$ && "$new_team" == "$old_team" ]] || fail "Update must use the installed real signing team."
for executable in 'Mx VPN' MxVPN-service amneziawg-go openvpn tun2socks; do
    signature="$(codesign -dvv "$source_app/Contents/MacOS/$executable" 2>&1)"
    [[ "$signature" == *runtime* && "$signature" == *"TeamIdentifier=$old_team"* ]] || fail "Every executable needs hardened runtime and the installed signing team."
done
if /bin/ps -axo comm | /usr/bin/grep -F -x "$target_app/Contents/MacOS/amneziawg-go" >/dev/null; then
    fail "Disconnect Mx VPN before updating."
fi
if [[ "${1:-}" == --check ]]; then
    echo "Update identity, signatures, matching team and disconnected-engine checks passed."
    exit 0
fi
[[ "${1:-}" == --update && "$(id -u)" == 0 ]] || fail "Use --check, or administrator-authorized --update."
if /bin/ps -axo comm | /usr/bin/grep -F -x "$target_app/Contents/MacOS/Mx VPN" >/dev/null; then
    fail "Quit Mx VPN before updating."
fi
[[ ! -L "$trust_dir/updates" ]] || fail "Unsafe rollback directory."
install -d -o root -g wheel -m 700 "$trust_dir/updates"
archive="$trust_dir/updates/$(date -u +%Y%m%dT%H%M%SZ)-$$"
install -d -o root -g wheel -m 700 "$archive"
cp "$trust_dir/client.cdhash" "$archive/client.cdhash"
ditto "$source_app" "$pending_app"
chown -R root:wheel "$pending_app"
chmod -R a-w "$pending_app"
codesign --verify --deep --strict "$pending_app"
new_hash="$(codesign -dvvv "$pending_app/Contents/MacOS/Mx VPN" 2>&1 | sed -n 's/^CDHash=//p')"
[[ "$new_hash" =~ ^[0-9a-f]{40}$ ]] || fail "New client pin unavailable; installed version retained."
stopped=false
rollback() {
    trap - ERR
    if [[ -d "$archive/Mx VPN.app" ]]; then
        launchctl bootout "system/$label" >/dev/null 2>&1 || true
        [[ ! -e "$target_app" ]] || mv "$target_app" "$archive/failed-update.app"
        mv "$archive/Mx VPN.app" "$target_app"
        cp "$archive/client.cdhash" "$trust_dir/client.cdhash"
    fi
    if [[ "$stopped" == true ]]; then launchctl bootstrap system "$plist" || true; fi
    echo "Update failed; previous installation restored where replacement had started." >&2
    exit 1
}
trap rollback ERR
launchctl bootout "system/$label"
stopped=true
mv "$target_app" "$archive/Mx VPN.app"
mv "$pending_app" "$target_app"
printf '%s\n' "$new_hash" > "$trust_dir/client.cdhash.new"
chown root:wheel "$trust_dir/client.cdhash.new"
chmod 644 "$trust_dir/client.cdhash.new"
mv "$trust_dir/client.cdhash.new" "$trust_dir/client.cdhash"
launchctl bootstrap system "$plist"
trap - ERR
echo "Updated Mx app and authenticated helper pin. Rollback retained at $archive"
