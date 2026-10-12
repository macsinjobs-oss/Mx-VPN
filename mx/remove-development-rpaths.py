#!/usr/bin/env python3
"""Remove build-machine search paths; leave Apple and relative paths intact."""
import pathlib
import subprocess
import sys

app = pathlib.Path(sys.argv[1]).resolve()
removed = 0
for binary in app.rglob("*"):
    if binary.is_symlink() or not binary.is_file():
        continue
    with binary.open("rb") as stream:
        magic = stream.read(4)
    if magic not in (b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"):
        continue
    commands = subprocess.run(["otool", "-l", str(binary)], text=True, capture_output=True, check=True).stdout
    for section in commands.split("cmd LC_RPATH")[1:]:
        for line in section.splitlines()[:4]:
            if "path " not in line:
                continue
            runtime_path = line.strip().split("path ", 1)[1].split(" (offset", 1)[0]
            if runtime_path.startswith(("/opt/homebrew", "/Volumes/", "/Users/")):
                subprocess.run(["install_name_tool", "-delete_rpath", runtime_path, str(binary)], check=True)
                removed += 1
print(f"Removed {removed} development search paths. Re-signing and dependency verification required.")
