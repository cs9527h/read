#!/usr/bin/env python3
"""Prevent publishing a build whose version, in-app changelog or source code disagree."""
from __future__ import annotations
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

def main() -> int:
    pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    version_file = (ROOT / "lib/src/version.dart").read_text(encoding="utf-8")
    notes = (ROOT / "lib/src/profile/changelog_page.dart").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", pubspec, re.M)
    if not match:
        print("::error::Read semantic version + build number not found", file=sys.stderr)
        return 1
    version, code = match.groups()
    errors = []
    if f"appVersion = '{version}'" not in version_file:
        errors.append("lib/src/version.dart is not aligned with pubspec.yaml")
    first = re.search(r"ReadReleaseNote\('([0-9.]+)'", notes)
    if not first or first.group(1) != version:
        errors.append("first in-app changelog entry does not match installed version")
    if int(code) <= 17:
        errors.append("Read Preview must increment versionCode beyond 17")
    for error in errors:
        print("::error::" + error, file=sys.stderr)
    if errors:
        return 1
    print(f"Read version and in-app notes verified: {version}+{code}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
