#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
if ! xcodebuild -version >/dev/null 2>&1; then
    echo "Full Xcode must be installed and selected before building Mx VPN."
    exit 2
fi
if [[ ! "${MX_DEVELOPMENT_TEAM:-}" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "Set MX_DEVELOPMENT_TEAM to your provisioned Apple Developer team ID."
    exit 2
fi
qt_path="${MX_QT_PATH:-/opt/homebrew/opt/qt}"
cmake -S "$project_root" -B "$project_root/build-mx-ne" -G Xcode \
    -C "$project_root/mx/branding.cmake" \
    -DBUILD_VPN_DEVELOPMENT_TEAM="$MX_DEVELOPMENT_TEAM" \
    -DCMAKE_PREFIX_PATH="$qt_path" -DDEPLOY=OFF
cmake --build "$project_root/build-mx-ne" --config Debug --target MxVPN
echo "Build finished. Signed extension loading, UI and VPN behavior still require verification."
