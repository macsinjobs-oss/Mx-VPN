#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="$project_root/build-mx-helper"
stage_root="${MX_PACKAGE_STAGE:-$project_root/build-mx-package}"
app="$stage_root/Mx VPN.app"
signing_identity="${MX_SIGNING_IDENTITY:-}"
if [[ -z "$signing_identity" || "$signing_identity" == - ]]; then
    echo "An Apple development signing identity is required. Ad-hoc hardened-runtime library loading failed in local tests."
    exit 2
fi
if ! security find-identity -v -p codesigning | rg -F -- "$signing_identity" >/dev/null; then
    echo "Requested signing identity is not available in the local Keychain."
    exit 2
fi
if [[ -e "$app" ]]; then
    echo "Package stage already exists. Choose a fresh MX_PACKAGE_STAGE for a new build."
    exit 2
fi
mkdir -p "$stage_root"
ditto "$build_root/client/Mx VPN.app" "$app"
for executable in MxVPN-service amneziawg-go openvpn tun2socks; do
    cp "$build_root/service/server/$executable" "$app/Contents/MacOS/$executable"
done
for data in geoip.dat geosite.dat; do
    cp "$build_root/service/server/$data" "$app/Contents/MacOS/$data"
done
ditto "$build_root/service/server/pf" "$app/Contents/MacOS/pf"
mkdir -p "$app/Contents/Resources/licenses"
cp "$project_root/LICENSE" "$app/Contents/Resources/licenses/Amnezia-GPL.txt"
cp "$project_root/THIRD_PARTY_LICENSES.md" "$app/Contents/Resources/licenses/THIRD_PARTY_LICENSES.md"
qt_path="${MX_QT_PATH:-/opt/homebrew/opt/qt}"
python3.11 "$project_root/mx/prepare-qt-deployment.py" "$app/Contents/MacOS/Mx VPN" "$qt_path/lib"
"$qt_path/bin/macdeployqt" "$app" \
    "-qmldir=$project_root/client/ui/qml" \
    "-libpath=$qt_path/lib" \
    "-executable=$app/Contents/MacOS/MxVPN-service" \
    "-executable=$app/Contents/MacOS/openvpn" \
    -no-strip -no-codesign 2>&1 | tee "$stage_root/macdeploy.log"
if rg -q '^ERROR:' "$stage_root/macdeploy.log"; then
    echo "Dependency deployment reported errors. Package rejected."
    exit 2
fi
python3.11 "$project_root/mx/remove-development-rpaths.py" "$app"
python3.11 "$project_root/mx/check-package.py" "$app"
python3.11 "$project_root/mx/sign-package.py" "$app" "$signing_identity"
echo "Staged local bundle: $app"
echo "Not installed. UI, administrator helper integration and VPN testing remain required."
