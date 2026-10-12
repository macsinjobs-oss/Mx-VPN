#!/usr/bin/env python3
"""Reject development library paths and absent bundled runtime dependencies."""
import pathlib
import subprocess
import sys
import struct

app = pathlib.Path(sys.argv[1]).resolve()
frameworks = app / "Contents/Frameworks"
failures = []
checked = 0
for binary in app.rglob("*"):
    if binary.is_symlink() or not binary.is_file():
        continue
    with binary.open("rb") as stream:
        header = stream.read(16)
    magic = header[:4]
    if magic not in (b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"):
        continue
    checked += 1
    listing = subprocess.run(["otool", "-L", str(binary)], text=True, capture_output=True, check=True).stdout
    lines = listing.splitlines()[1:]
    # otool -L includes a dylib's own install ID first. This is not an
    # incoming dependency and may retain its upstream build identity.
    if magic == b"\xcf\xfa\xed\xfe" and struct.unpack("<I", header[12:16])[0] == 6:
        lines = lines[1:]
    for line in lines:
        dependency = line.strip().split(" (compatibility version", 1)[0]
        if dependency.startswith(("/System/Library/", "/usr/lib/")):
            continue
        if dependency.startswith("@rpath/"):
            candidate = frameworks / dependency[len("@rpath/"):]
        elif dependency.startswith("@executable_path/"):
            candidate = app / "Contents/MacOS" / dependency[len("@executable_path/"):]
        elif dependency.startswith("@loader_path/"):
            candidate = binary.parent / dependency[len("@loader_path/"):]
        elif dependency.startswith(str(app) + "/"):
            candidate = pathlib.Path(dependency)
        else:
            failures.append((binary.relative_to(app), "external dependency", dependency))
            continue
        if not candidate.exists():
            failures.append((binary.relative_to(app), "missing bundled dependency", dependency))
    commands = subprocess.run(["otool", "-l", str(binary)], text=True, capture_output=True, check=True).stdout
    for section in commands.split("cmd LC_RPATH")[1:]:
        for line in section.splitlines()[:4]:
            if "path " in line:
                runtime_path = line.strip().split("path ", 1)[1].split(" (offset", 1)[0]
                if runtime_path.startswith(("/opt/homebrew", "/Volumes/", "/Users/")):
                    failures.append((binary.relative_to(app), "development rpath", runtime_path))
for binary, reason, dependency in failures[:10]:
    print(f"FAIL: {binary}: {reason}: {dependency}")
if failures:
    print(f"FAIL: {len(failures)} dependency findings across {checked} Mach-O files.")
    sys.exit(1)
if not checked:
    sys.exit("FAIL: no Mach-O files found")
print(f"PASS: {checked} Mach-O files; bundled dependencies present; no development paths.")
