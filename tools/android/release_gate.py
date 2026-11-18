#!/usr/bin/env python3
"""Fail closed unless a Read Release tag belongs to the tested mainline source."""
import json
import os
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def guard():
    event = os.environ.get("GITHUB_EVENT_NAME", "")
    ref = os.environ.get("GITHUB_REF", "")
    tag = os.environ.get("RELEASE_TAG", "").strip()
    if event == "push":
        if not ref.startswith("refs/tags/") or ref[10:] != tag:
            raise SystemExit("RELEASE BLOCKED: only the pushed tag may be released")
    elif event != "workflow_dispatch" or not tag:
        raise SystemExit("RELEASE BLOCKED: explicit release tag required")
    version_match = re.fullmatch(r"v(\d+\.\d+\.\d+)-preview", tag)
    if not version_match:
        raise SystemExit("RELEASE BLOCKED: tag must use vX.Y.Z-preview")
    pubspec = (ROOT / "pubspec.yaml").read_text()
    pubversion = re.search(r"(?m)^version:\s*(\d+\.\d+\.\d+)\+([0-9]+)$", pubspec)
    if not pubversion or pubversion.group(1) != version_match.group(1):
        raise SystemExit("RELEASE BLOCKED: tag and pubspec.yaml version differ")
    baseline = json.loads((ROOT / "tools/android/read_release_baseline.json").read_text())
    old_version = tuple(int(x) for x in baseline["released_version"].split("."))
    new_version = tuple(int(x) for x in pubversion.group(1).split("."))
    if new_version <= old_version or int(pubversion.group(2)) <= int(baseline["released_build_number"]):
        raise SystemExit("RELEASE BLOCKED: version and Android build number must both increase")
    changelog = (ROOT / "lib/src/profile/changelog_page.dart").read_text()
    first_note = re.search(r"ReadReleaseNote\\('([0-9.]+)'", changelog)
    if not first_note or first_note.group(1) != version_match.group(1):
        raise SystemExit("RELEASE BLOCKED: latest in-app changelog must match the release version")
    current = git("rev-parse", "HEAD")
    if git("rev-parse", f"refs/tags/{tag}^{{commit}}") != current:
        raise SystemExit("RELEASE BLOCKED: checkout differs from target tag")
    try:
        git("merge-base", "--is-ancestor", current, "refs/remotes/origin/main")
    except subprocess.CalledProcessError:
        raise SystemExit("RELEASE BLOCKED: release commit is not merged into main")
    # The tag must point at main itself, rather than an arbitrary older commit
    # (re-releasing old code should be an explicit rollback process).
    if git("rev-parse", "refs/remotes/origin/main") != current:
        raise SystemExit("RELEASE BLOCKED: tag must point to latest origin/main")
    print(json.dumps({"source_commit": current, "tag": tag,
                      "version": pubversion.group(1),
                      "version_code": int(pubversion.group(2))}, ensure_ascii=False))
    return current


if __name__ == "__main__":
    guard()
