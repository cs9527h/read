#!/usr/bin/env python3
"""Fail closed when a Read release tag does not represent the current main source."""
from __future__ import annotations
import argparse
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()

def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--tag", required=True)
    args = p.parse_args()
    errors: list[str] = []
    pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    version_file = (ROOT / "lib/src/version.dart").read_text(encoding="utf-8")
    log = (ROOT / "lib/src/profile/changelog_page.dart").read_text(encoding="utf-8")
    version_match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", pubspec, re.M)
    if not version_match:
        raise SystemExit("pubspec.yaml version not found")
    version = version_match.group(1)
    expected = "v" + version + "-preview"
    if args.tag != expected:
        errors.append(f"release tag {args.tag!r} != expected {expected!r}")
    if f"appVersion = '{version}'" not in version_file:
        errors.append("lib/src/version.dart must match pubspec.yaml")
    if f"ReadReleaseNote('{version}'" not in log:
        errors.append("installed version must appear in in-app changelog")
    if not re.search(rf"readReleaseNotes\s*=.*?ReadReleaseNote\('{re.escape(version)}'", log, re.S):
        errors.append("newest changelog entry must match the version")
    head = git("rev-parse", "HEAD")
    main_head = git("rev-parse", "refs/remotes/origin/main")
    if head != main_head:
        errors.append(f"tagged commit {head[:12]} is not current main HEAD {main_head[:12]}")
    target = git("rev-list", "-n", "1", "refs/tags/" + args.tag)
    if target != head:
        errors.append(f"tag {args.tag} does not target current source commit")
    if errors:
        for error in errors:
            print("::error::" + error, file=sys.stderr)
        return 1
    print(f"release source verified: tag={args.tag} commit={head} versionCode={version_match.group(2)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
