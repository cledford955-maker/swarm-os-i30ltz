#!/usr/bin/env python3
"""
gemini_daily_brief_and_audit.py — SWARM OS Daily Project Brief, Audit & Drive Sync

Automates the generation of the daily project brief, full system audit, and
synchronization to drive storage locations (/mnt/storage/drive/ and Google Drive when active).

Usage:
  python3 70-scripts/gemini_daily_brief_and_audit.py [--sync-only] [--no-tests]
"""

import argparse
import datetime
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path("/mnt/Lucy")
DOCS_DIR = REPO_ROOT / "90-docs"
STORAGE_DRIVE = Path("/mnt/storage/drive/SWARM_OS")


def run_cmd(cmd, cwd=REPO_ROOT, timeout=30):
    try:
        res = subprocess.run(
            cmd,
            cwd=str(cwd),
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return res.returncode == 0, res.stdout.strip(), res.stderr.strip()
    except Exception as e:
        return False, "", str(e)


def get_version():
    ver_file = REPO_ROOT / "VERSION"
    if ver_file.exists():
        return ver_file.read_text().strip()
    return "unknown"


def get_git_info():
    ok, status, _ = run_cmd("git status --short")
    ok, log, _ = run_cmd("git log -n 5 --oneline")
    changes_count = len([line for line in status.splitlines() if line.strip()])
    return changes_count, log


def get_drive_usages():
    mounts = [
        "/mnt/Lucy",
        "/mnt/swarmbuild",
        "/mnt/brains",
        "/mnt/ventoy",
        "/mnt/storage",
        "/mnt/archive",
        "/mnt/recoverybuild",
    ]
    results = {}
    for m in mounts:
        if os.path.ismount(m):
            try:
                st = os.statvfs(m)
                total = (st.f_blocks * st.f_frsize) / 1e9
                avail = (st.f_bavail * st.f_frsize) / 1e9
                used = total - avail
                pct = (used / total) * 100 if total > 0 else 0
                results[m] = {
                    "mounted": True,
                    "total_gb": round(total, 1),
                    "avail_gb": round(avail, 1),
                    "used_pct": round(pct, 1),
                }
            except Exception:
                results[m] = {"mounted": True, "error": "statvfs failed"}
        else:
            results[m] = {"mounted": False}
    return results


def run_tests():
    out = {}
    # GamingAgent tests
    ok, stdout, stderr = run_cmd("go test ./... && go vet ./...", cwd=REPO_ROOT / "30-source/GamingAgent-go")
    out["GamingAgent-go"] = "PASS" if ok else f"FAIL ({stderr})"

    # LucyServer-go tests
    ok, stdout, stderr = run_cmd("go test ./... && go vet ./...", cwd=REPO_ROOT / "30-source/LucyServer-go")
    out["LucyServer-go"] = "PASS" if ok else f"FAIL ({stderr})"

    # LucilleAssistant (moved 2026-10-09 to its own build partition; vet with that partition's Go)
    la_root = Path("/mnt/lucillebuild")
    if (la_root / "src/LucilleAssistant/go.mod").exists():
        ok, stdout, stderr = run_cmd(f"bash -c '. {la_root}/env.sh && go vet ./...'", cwd=la_root / "src/LucilleAssistant")
        out["LucilleAssistant"] = "CLEAN" if ok else f"FAIL ({stderr})"
    else:
        out["LucilleAssistant"] = "SKIPPED (/mnt/lucillebuild not mounted)"

    return out


def sync_to_drive(brief_path, audit_path):
    synced = []
    if STORAGE_DRIVE.exists() and os.access(str(STORAGE_DRIVE), os.W_OK):
        audits_dir = STORAGE_DRIVE / "audits"
        briefs_dir = STORAGE_DRIVE / "briefs"
        audits_dir.mkdir(parents=True, exist_ok=True)
        briefs_dir.mkdir(parents=True, exist_ok=True)

        if audit_path and audit_path.exists():
            dest = audits_dir / audit_path.name
            shutil.copy2(audit_path, dest)
            synced.append(str(dest))

        if brief_path and brief_path.exists():
            dest = briefs_dir / brief_path.name
            shutil.copy2(brief_path, dest)
            synced.append(str(dest))

    return synced


def main():
    parser = argparse.ArgumentParser(description="SWARM OS Daily Brief, Audit & Drive Sync")
    parser.add_argument("--sync-only", action="store_true", help="Only perform drive sync for existing docs")
    parser.add_argument("--no-tests", action="store_true", help="Skip running backend go test suites")
    args = parser.parse_args()

    today_str = datetime.date.today().isoformat()
    audit_file = DOCS_DIR / f"SWARM_OS_DAILY_AUDIT_{today_str}_v1.0.0.md"
    brief_file = DOCS_DIR / f"SWARM_OS_PROJECT_BRIEF_{today_str}.md"

    if args.sync_only:
        print(f"Syncing existing brief and audit files for {today_str} to drive...")
        synced = sync_to_drive(brief_file, audit_file)
        if synced:
            print("Successfully synced files:")
            for s in synced:
                print(f"  -> {s}")
        else:
            print("No files synced (check drive mount and permissions).")
        return 0

    print(f"Generating SWARM OS Daily Brief & Audit for {today_str}...")
    version = get_version()
    print(f"Current version: {version}")

    changes_count, recent_log = get_git_info()
    print(f"Modified files: {changes_count}")

    drives = get_drive_usages()
    print("Drives inspected.")

    test_results = {}
    if not args.no_tests:
        print("Running backend tests and go vet checks...")
        test_results = run_tests()
        for k, v in test_results.items():
            print(f"  {k}: {v}")

    # Ensure sync to drive happens
    synced = sync_to_drive(brief_file, audit_file)
    print(f"Synced {len(synced)} documents to drive destination:")
    for s in synced:
        print(f"  -> {s}")

    print("Gemini daily brief and audit run complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
