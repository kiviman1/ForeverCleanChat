#!/usr/bin/env python3
"""Package the tested runtime; optionally copy it to an existing AddOns directory."""
from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parent.parent
REPORT = ROOT / "tests/results/latest.json"
DOCS = ("README.md", "README_TR.md", "CHANGELOG.md", "TEST_REPORT.txt")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", type=Path, help="Existing target client's Interface/AddOns directory")
    args = parser.parse_args()
    toc = ROOT / "ForeverCleanChat.toc"
    content = toc.read_text(encoding="utf-8")
    version = re.search(r"^## Version: ([0-9.]+)$", content, re.MULTILINE).group(1)
    files = [toc.name] + [line.strip() for line in content.splitlines() if line.strip() and not line.startswith("#")]
    files += list(DOCS)
    for name in files:
        path = (ROOT / name).resolve()
        if path.parent != ROOT or not path.is_file():
            raise SystemExit(f"Invalid or missing runtime file: {name}")
    report = json.loads(REPORT.read_text(encoding="utf-8"))
    if report.get("compiler", {}).get("status") != "passed":
        raise SystemExit("Run the full test suite before packaging.")
    for engine in ("lupa.lua51", "lupa.lua53"):
        runtime = next((r for r in report["runtimes"] if r["engine"] == engine), None)
        if not runtime or set(runtime["suites"]) != {"regression", "research", "adversarial", "ui"}:
            raise SystemExit(f"Full executed test results are required for {engine}.")
        for name, result in runtime["suites"].items():
            if result.get("execution_error") or result.get("failed", 0) or result.get("status") == "failed_to_complete":
                raise SystemExit(f"Failed {engine} {name} checks.")
            if any(result.get(group, {}).get("failed", 0) for group in ("classification", "adapter")):
                raise SystemExit(f"Failed {engine} {name} classification/callback checks.")
            if any(row.get("status") == "failed" for row in result.get("checks", []) + result.get("contracts", [])):
                raise SystemExit(f"Failed {engine} {name} engineering checks.")
    if any((ROOT / name).stat().st_mtime > REPORT.stat().st_mtime for name in files if name.endswith(".lua")):
        raise SystemExit("Runtime Lua changed after the test report. Run tests again.")
    archive = ROOT.parent / f"ForeverCleanChat-v{version}.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as release:
        for name in files:
            release.write(ROOT / name, "ForeverCleanChat/" + name)
    result = {"version": version, "archive": str(archive), "files": len(files), "archive_sha256": digest(archive)}
    if args.install:
        addons = args.install.resolve(strict=True)
        if not addons.is_dir() or addons.name.lower() != "addons":
            raise SystemExit("Installation target must be an existing AddOns directory.")
        target = (addons / "ForeverCleanChat").resolve()
        if target.parent != addons or target == ROOT:
            raise SystemExit("Unexpected installation target.")
        if target.exists():
            backup = ROOT.parent / "backups" / ("ForeverCleanChat-before-" + version + "-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
            backup = backup.resolve()
            if ROOT.parent not in backup.parents:
                raise SystemExit("Backup must remain within the workspace.")
            shutil.copytree(target, backup)
            result["backup"] = str(backup)
        target.mkdir(exist_ok=True)
        for name in files:
            shutil.copy2(ROOT / name, target / name)
            if digest(ROOT / name) != digest(target / name):
                raise SystemExit(f"Installed file verification failed: {name}")
        result["installed_to"] = str(target)
        result["verified_files"] = len(files)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
