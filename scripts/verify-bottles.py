#!/usr/bin/env python3
"""Require real test-bot results and one checksum-verified Tycho bottle."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET


def verify_reports(root):
    summary = (root / "steps_output.txt").read_text()
    if re.search(r"[1-9]\d* failed steps?", summary):
        raise ValueError("test-bot reported failed or ignored steps")
    failures = list(root.glob("skipped_or_failed_formulae-*.txt"))
    if not failures or any(path.read_text().strip() for path in failures):
        raise ValueError("missing skip report or skipped/failed formulae")
    cases = ET.parse(root / "brew-test-bot.xml").findall(".//testcase")
    tests = [case for case in cases if re.match(r"test\s", case.get("name", ""))
             and "firewalker06/tycho/tycho" in case.get("name", "")]
    if not tests or any(case.get("status") != "passed" or list(case) for case in tests):
        raise ValueError("required Tycho installed-formula test did not pass")


def verify(root, version, tag):
    if not (tag.startswith("arm64_") or tag == "x86_64_linux"):
        raise ValueError("unsupported bottle platform")
    verify_reports(root)
    rows = []
    for path in root.glob("*.bottle.json"):
        data = json.loads(path.read_text())
        entry = data.get("firewalker06/tycho/tycho")
        if not entry:
            continue
        if entry["formula"]["pkg_version"] != version:
            raise ValueError("bottle metadata version mismatch")
        tags = entry["bottle"]["tags"]
        if set(tags) != {tag}:
            raise ValueError("missing or unexpected bottle platform")
        item = tags[tag]
        name = item.get("local_filename") or item["filename"]
        if Path(name).name != name:
            raise ValueError("bottle filename must be local")
        bottle = root / name
        if not bottle.is_file() or bottle.stat().st_size == 0:
            raise ValueError("required bottle is absent or empty")
        digest = hashlib.sha256(bottle.read_bytes()).hexdigest()
        if digest != item["sha256"]:
            raise ValueError("bottle checksum mismatch")
        rows.append({"file": name, "sha256": digest, "bytes": bottle.stat().st_size,
                     "metadata": path.name, "tag": tag, "version": version})
    if len(rows) != 1:
        raise ValueError("expected exactly one verified Tycho bottle")
    return rows


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--directory", type=Path, default=Path.cwd())
    args = parser.parse_args()
    try:
        rows = verify(args.directory, args.version, args.tag)
    except (ValueError, KeyError, OSError, ET.ParseError, json.JSONDecodeError) as error:
        parser.exit(1, f"Bottle verification failed: {error}\n")
    output = json.dumps(rows, indent=2) + "\n"
    (args.directory / "bottle-verification.json").write_text(output)
    print(output, end="")
