#!/usr/bin/env python3
"""Keep Homebrew's umbrella Qt path available to macdeployqt's QML pass.

macdeployqt carries only paths used to resolve a dependency into its QML pass.
Homebrew's absolute module-specific install names otherwise discard the umbrella
path, preventing discovery of QML-only modules such as QtStateMachine.
Only the staged application's load commands change; build outputs stay intact.
"""
import pathlib
import subprocess
import sys

binary = pathlib.Path(sys.argv[1]).resolve()
qt_lib = pathlib.Path(sys.argv[2]).resolve()
listing = subprocess.run(["otool", "-L", str(binary)], capture_output=True,
                         text=True, check=True).stdout
changed = 0
for line in listing.splitlines()[1:]:
    dependency = line.strip().split(" (compatibility version", 1)[0]
    if not dependency.startswith("/opt/homebrew/") or "/Qt" not in dependency:
        continue
    parts = dependency.split("/")
    framework_index = next((i for i, part in enumerate(parts)
                            if part.startswith("Qt") and part.endswith(".framework")), None)
    if framework_index is None:
        continue
    relative = "/".join(parts[framework_index:])
    source = qt_lib / relative
    if not source.is_file() or source.resolve() != pathlib.Path(dependency).resolve():
        raise SystemExit(f"Qt umbrella dependency does not match installed framework: {relative}")
    subprocess.run(["install_name_tool", "-change", dependency,
                    "@rpath/" + relative, str(binary)], check=True)
    changed += 1
if not changed:
    raise SystemExit("No Qt framework dependencies normalized; fresh build required.")
print(f"Normalized {changed} staged Qt dependencies for QML deployment.")
