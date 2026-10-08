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
import struct
import zipfile

ROOT = Path(__file__).resolve().parent.parent
REPORT = ROOT / "tests/results/latest.json"
DOCS = ("README.md", "README_TR.md", "CHANGELOG.md", "TEST_REPORT.txt")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_test_summary(report, version):
    def fraction(result):
        return f"{result.get('passed', 0)}/{result.get('total', 0)}"

    lines = [f"Forever Clean Chat {version} - ACTUALLY EXECUTED LOCAL TEST REPORT", "",
             f"Executed at UTC: {report['executed_at_utc']}",
             f"Host Python: {report['python_version']} ({report['python_executable']})", ""]
    for runtime in report['runtimes']:
        suites = runtime['suites']
        lines += [f"{runtime['engine']} / Lua {runtime['lua_version']}:",
                  "  Adapted regression: " + fraction(suites['regression']),
                  "  JSON classifier/profile checks: " + fraction(suites['research']['classification']),
                  "  JSON mock callback/profile checks: " + fraction(suites['research']['adapter']),
                  "  Adversarial classifier/profile checks: " + fraction(suites['adversarial']['classification']),
                  "  Adversarial mock callback/profile checks: " + fraction(suites['adversarial']['adapter']),
                  "  Control panel and minimap interaction assertions: " + fraction(suites['ui']), ""]
    compiler = report['compiler']
    lines += [f"Compiler validation unit tests: {compiler['compiler_unit_tests']['tests_run']} actually executed.",
              f"Compilation determinism: {compiler['separate_compilations']} matching compilations; checked-in artifacts match.", "",
              "Actual live WoW/Forever validation: NOT RUN. Mock APIs, actual Lua interpreters.",
              "UI previews render production geometry with local font/border/mask approximations, not the game client.",
              "Tests sent no real chat messages and performed no report/ignore actions.",
              "Settings remain account-wide; no SavedVariables files are copied by the release installer.",
              "Forever Mini Reminder was not modified.", "",
              "Detailed results: tests/results/latest.md and latest.json.",
              "Run: python tests/run_all.py", ""]
    (ROOT / 'TEST_REPORT.txt').write_text('\n'.join(lines), encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", type=Path, help="Existing target client's Interface/AddOns directory")
    args = parser.parse_args()
    toc = ROOT / "ForeverCleanChat.toc"
    content = toc.read_text(encoding="utf-8")
    version = re.search(r"^## Version: ([0-9.]+)$", content, re.MULTILINE).group(1)
    files = [toc.name] + [line.strip() for line in content.splitlines() if line.strip() and not line.startswith("#")]
    files += list(DOCS)
    files += [path.relative_to(ROOT).as_posix() for path in sorted((ROOT / 'Media').rglob('*.tga'))]
    files += ['Media/ASSETS.md']
    for name in files:
        path = (ROOT / name).resolve()
        if ROOT not in path.parents or not path.is_file():
            raise SystemExit(f"Invalid or missing runtime file: {name}")
        if path.suffix == '.tga':
            data = path.read_bytes()
            if len(data) < 18:
                raise SystemExit(f"Invalid texture header: {name}")
            width, height = struct.unpack_from('<HH', data, 12)
            if (data[1] != 0 or data[2] != 2 or data[16] != 32 or data[17] & 15 != 8
                    or width <= 0 or height <= 0 or width & (width-1) or height & (height-1)
                    or len(data) < 18 + data[0] + width * height * 4):
                raise SystemExit(f"Texture must be power-of-two uncompressed RGBA TGA: {name}")
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
    if any((ROOT / name).stat().st_mtime > REPORT.stat().st_mtime for name in files if name.endswith((".lua", ".tga"))):
        raise SystemExit("Runtime Lua or artwork changed after the test report. Run tests again.")
    write_test_summary(report, version)
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
            (target / name).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target / name)
            if digest(ROOT / name) != digest(target / name):
                raise SystemExit(f"Installed file verification failed: {name}")
        result["installed_to"] = str(target)
        result["verified_files"] = len(files)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
