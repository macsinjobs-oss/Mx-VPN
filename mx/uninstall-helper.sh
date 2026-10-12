#!/bin/bash
# Disconnect the Mx tunnel first. Preserve files in a root-owned local archive.
set -euo pipefail
[[ "$(id -u)" == 0 ]] || { echo "Administrator authorization required." >&2; exit 2; }
[[ "${1:-}" == --confirm-disconnected ]] || {
    echo "Disconnect Mx VPN first, then use --confirm-disconnected." >&2
    exit 2
}
app="/Applications/Mx VPN.app"
trust="/Library/Application Support/MxVPN"
plist="/Library/LaunchDaemons/org.macsinjobs.mxvpn.helper.plist"
[[ -d "$app" && ! -L "$app" ]] || { echo "Expected Mx app unavailable." >&2; exit 2; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")" == org.macsinjobs.mxvpn ]] || exit 2
archive="/Library/Application Support/MxVPN-uninstalled-$(date +%Y%m%d-%H%M%S)"
[[ ! -e "$archive" ]] || exit 2
install -d -o root -g wheel -m 700 "$archive"
launchctl bootout system/org.macsinjobs.mxvpn.helper
mv "$app" "$archive/Mx VPN.app"
mv "$plist" "$archive/org.macsinjobs.mxvpn.helper.plist"
mv "$trust" "$archive/trust"
echo "Helper stopped. Installation archived at $archive. User configurations and unrelated VPNs preserved."
