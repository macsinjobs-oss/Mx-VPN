#!/usr/bin/env python3
"""Refresh only a rebuilt GUI when its audited runtime dependency set is unchanged.

New dependencies require the full package-helper.sh deployment. A fresh output
directory is mandatory; the verified base and installed app are never modified.
"""
import argparse
import pathlib
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("base", type=pathlib.Path)
parser.add_argument("built", type=pathlib.Path)
parser.add_argument("stage", type=pathlib.Path)
parser.add_argument("identity")
args = parser.parse_args()
scripts = pathlib.Path(__file__).resolve().parent
base, built, stage = args.base.resolve(), args.built.resolve(), args.stage.resolve()
if stage.exists():
    parser.error("Choose a new stage; existing output is preserved.")

def dependencies(binary):
    output = subprocess.run(["otool", "-L", str(binary)], text=True,
                            capture_output=True, check=True).stdout
    result = {}
    for line in output.splitlines()[1:]:
        dependency = line.strip().split(" (compatibility version", 1)[0]
        if dependency.startswith(("/System/Library/", "/usr/lib/")):
            identity = dependency
        elif ".framework/" in dependency:
            parts = dependency.split("/")
            index = next(i for i, p in enumerate(parts) if p.endswith(".framework"))
            identity = "/".join(parts[index:])
        else:
            identity = pathlib.PurePosixPath(dependency).name
        if identity in result:
            raise SystemExit("Ambiguous dependency; full deployment required.")
        result[identity] = dependency
    return result

reference = dependencies(base / "Contents/MacOS/Mx VPN")
incoming = dependencies(built / "Contents/MacOS/Mx VPN")
if reference.keys() != incoming.keys():
    raise SystemExit("Runtime dependency set changed; use full deployment.")
subprocess.run(["codesign", "--verify", "--deep", "--strict", str(base)], check=True)
subprocess.run(["python3.11", str(scripts / "check-package.py"), str(base)], check=True)
stage.mkdir()
app = stage / "Mx VPN.app"
subprocess.run(["ditto", str(base), str(app)], check=True)
binary = app / "Contents/MacOS/Mx VPN"
subprocess.run(["ditto", str(built / "Contents/MacOS/Mx VPN"), str(binary)], check=True)
options = []
for identity, dependency in incoming.items():
    if dependency != reference[identity]:
        options += ["-change", dependency, reference[identity]]
if options:
    subprocess.run(["install_name_tool", *options, str(binary)], check=True)
subprocess.run(["python3.11", str(scripts / "remove-development-rpaths.py"), str(app)], check=True)
subprocess.run(["python3.11", str(scripts / "check-package.py"), str(app)], check=True)
# Unchanged nested code already carries verified real signatures. Sign the new
# GUI and enclosing resource seal together, then independently audit everything.
subprocess.run(["codesign", "--force", "--options", "runtime", "--sign", args.identity, str(app)], check=True)
subprocess.run(["python3.11", str(scripts / "sign-package.py"), str(app), "--verify-only"], check=True)
print(f"PASS: refreshed client with identical audited dependencies: {app}")
