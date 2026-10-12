#!/usr/bin/env python3
"""Sign nested code before enclosing bundles and verify every Mach-O team."""
import argparse
import json
import pathlib
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("app", type=pathlib.Path)
parser.add_argument("identity", nargs="?")
parser.add_argument("--verify-only", action="store_true")
args = parser.parse_args()
if not args.verify_only and (not args.identity or args.identity == "-"):
    parser.error("A real Apple signing identity is required.")
app = args.app.resolve()
magic = {b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"}
binaries = []
for path in app.rglob("*"):
    if path.is_symlink() or not path.is_file():
        continue
    with path.open("rb") as stream:
        if stream.read(4) in magic:
            binaries.append(path)
frameworks = [p for p in app.rglob("*.framework") if p.is_dir() and not p.is_symlink()]
# Upstream keeps routing assets and resolver scripts beside its executables.
# macOS treats everything in Contents/MacOS as nested code, including data.
# Sign those generic objects explicitly instead of relying on deprecated --deep.
generic = [p for p in (app / "Contents/MacOS").rglob("*")
           if p.is_file() and not p.is_symlink() and p not in binaries]
leaves = [p for p in binaries if not any(parent.suffix == ".framework" for parent in p.parents)
          and p != app / "Contents/MacOS/Mx VPN"]
targets = sorted(leaves + generic + frameworks, key=lambda p: len(p.parts), reverse=True) + [app]
if not args.verify_only:
    result = subprocess.run(["codesign", "--force", "--options", "runtime", "--sign", args.identity,
                             *map(str, targets)])
    if result.returncode:
        raise SystemExit("Signing failed. Package rejected; inspect preceding codesign diagnostic.")
subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
teams = set()
for binary in binaries + generic:
    subprocess.run(["codesign", "--verify", "--strict", str(binary)], check=True)
    result = subprocess.run(["codesign", "-dv", "--verbose=2", str(binary)],
                            text=True, capture_output=True, check=True).stderr
    team = re.search(r"^TeamIdentifier=([A-Z0-9]{10})$", result, re.M)
    if not team or "(runtime)" not in result:
        raise SystemExit(f"Missing real team or hardened runtime: {binary.relative_to(app)}")
    teams.add(team.group(1))
if len(teams) != 1 or not binaries:
    raise SystemExit("Package must contain code signed by one real Apple team.")
manifest = {"mach_o_files": len(binaries), "framework_bundles": len(frameworks),
            "generic_nested_files": len(generic),
            "team": next(iter(teams)), "deep_strict_verification": True,
            "all_signatures_verified": True, "all_hardened_runtime": True}
(app.parent / "signature-audit.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"PASS: {len(binaries)} Mach-O signatures, hardened runtime, one signing team.")
