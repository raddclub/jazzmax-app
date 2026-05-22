#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║              JazzMAX — Project Export Script                        ║
# ║                                                                      ║
# ║  Run this at the END of every work session, or when you hit the     ║
# ║  Replit free tier limit. Creates a clean zip you can move to the    ║
# ║  next Replit account.                                                ║
# ║                                                                      ║
# ║  HOW TO RUN:                                                         ║
# ║    bash create_zip.sh                                                ║
# ║                                                                      ║
# ║  HOW TO UNZIP ON NEXT REPLIT ACCOUNT (run in shell):                ║
# ║    cd /home/runner/workspace                                         ║
# ║    python3 -c "import zipfile,os; zipfile.ZipFile('jazzmax_YYYYMMDD_HHMM.zip').extractall('.')"
# ╚══════════════════════════════════════════════════════════════════════╝

set -e

WORKSPACE="/home/runner/workspace"
cd "$WORKSPACE"

python3 << 'PYEOF'
import os
import sys
import zipfile
import sqlite3
import shutil
from datetime import datetime
from pathlib import Path

WORKSPACE = Path("/home/runner/workspace")
ZIPNAME   = f"jazzmax_{datetime.now().strftime('%Y%m%d_%H%M')}.zip"
ZIPPATH   = WORKSPACE / ZIPNAME

# ── Folders/patterns to EXCLUDE (too large or not needed) ────────────────────
EXCLUDE_DIRS = {
    "radd-hub/local",          # 641 MB — Chromium + ffmpeg binaries
    "node_modules",            # 372 MB — JS packages (reinstall with pnpm i)
    ".pythonlibs",             # 227 MB — Python packages (reinstall with pip)
    ".local",                  # 64 MB  — Replit agent skills (not your code)
    "radd-hub/data/logs",      # 13 MB  — log files
    "radd-hub/data/backups",   # 7 MB   — old DB backups
    "radd-hub/data/tmp",
    "radd-hub/data/staging",
    "radd-hub/data/media",
    "radd-hub/data/cache",
    "radd-hub/bots/node_modules",
    "artifacts",               # Node.js API experiment — not Flutter project
    ".git",
    ".upm",
    ".config",
    ".cache",
    "lib",                     # TypeScript workspace lib — not needed
    "scripts",                 # TypeScript workspace scripts — not needed
}

EXCLUDE_SUFFIXES = {
    ".pyc", ".pyo", ".log", ".pid",
    ".db-wal", ".db-shm",   # SQLite WAL files — not needed, can corrupt DB if included without checkpoint
}

EXCLUDE_NAMES = {
    "raddhub.pid",
    "__pycache__",
}

def should_exclude(rel_path: str) -> bool:
    parts = Path(rel_path).parts

    # Check any part of the path against excluded dir names
    for ex in EXCLUDE_DIRS:
        ex_parts = Path(ex).parts
        # Check if ex_parts appear as a subsequence of leading parts
        if parts[:len(ex_parts)] == ex_parts:
            return True
        # Also check anywhere in the path (e.g. nested node_modules)
        for i in range(len(parts) - len(ex_parts) + 1):
            if parts[i:i+len(ex_parts)] == ex_parts:
                return True

    # Check file suffix
    suffix = Path(rel_path).suffix.lower()
    if suffix in EXCLUDE_SUFFIXES:
        return True

    # Check exact name
    name = Path(rel_path).name
    if name in EXCLUDE_NAMES:
        return True

    return False


print("")
print("╔══════════════════════════════════════════════════╗")
print("║         JazzMAX Project Export                   ║")
print("╚══════════════════════════════════════════════════╝")
print(f"\n  Output file : {ZIPNAME}")
print(f"  Working dir : {WORKSPACE}")

# ── Step 1: Checkpoint SQLite so WAL is flushed into main .db file ───────────
print("\n▶ Step 1/4 — Checkpointing SQLite database...")
db_path = WORKSPACE / "radd-hub/data/radd_hub.db"
if db_path.exists():
    try:
        conn = sqlite3.connect(str(db_path))
        conn.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        conn.close()
        print("  ✓ Database checkpointed — all data safely in .db file")
    except Exception as e:
        print(f"  ⚠ Checkpoint warning (non-fatal): {e}")
else:
    print("  ⚠ Database not found — skipping checkpoint")

# ── Step 2: Remove old zip files ─────────────────────────────────────────────
print("\n▶ Step 2/4 — Cleaning up old zip files...")
removed = 0
for f in WORKSPACE.glob("jazzmax_*.zip"):
    f.unlink()
    removed += 1
print(f"  ✓ Removed {removed} old zip file(s)")

# ── Step 3: Build zip ─────────────────────────────────────────────────────────
print("\n▶ Step 3/4 — Building zip (may take 1-2 minutes)...")
print("    Skipping: local binaries, node_modules, .pythonlibs, logs, pycache...")
print("")

added   = 0
skipped = 0

with zipfile.ZipFile(str(ZIPPATH), "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
    for root, dirs, files in os.walk(str(WORKSPACE)):
        root_path = Path(root)
        rel_root  = root_path.relative_to(WORKSPACE)

        # Prune dirs in-place so os.walk skips them entirely (fast)
        dirs[:] = [
            d for d in dirs
            if not should_exclude(str(rel_root / d))
        ]

        for filename in files:
            file_path = root_path / filename
            rel_path  = file_path.relative_to(WORKSPACE)
            rel_str   = str(rel_path)

            # Skip the zip file itself
            if rel_str == ZIPNAME:
                continue

            if should_exclude(rel_str):
                skipped += 1
                continue

            try:
                zf.write(str(file_path), rel_str)
                added += 1
                if added % 200 == 0:
                    print(f"    ... {added} files added so far")
            except (OSError, PermissionError) as e:
                print(f"    ⚠ Skipped (unreadable): {rel_str}")
                skipped += 1

# ── Step 4: Report ────────────────────────────────────────────────────────────
zip_size_mb = ZIPPATH.stat().st_size / (1024 * 1024)

print(f"\n▶ Step 4/4 — Complete!")
print(f"\n  ✅ Files added   : {added}")
print(f"  ⏭  Files skipped : {skipped}")
print(f"  📦 Zip size      : {zip_size_mb:.1f} MB")
print(f"  📁 Filename      : {ZIPNAME}")

print("""
══════════════════════════════════════════════════════════════

  HOW TO MOVE TO NEXT REPLIT ACCOUNT:

  STEP A — Download the zip from THIS account:
    Files panel (left sidebar) → find jazzmax_YYYYMMDD_HHMM.zip
    Right-click → Download

  STEP B — On the NEXT Replit account:
    1. Create a new Repl (any language, doesn't matter)
    2. Upload the zip via Files panel (drag & drop the .zip file)
    3. Open Shell and run these commands:

       cd /home/runner/workspace
       python3 -c "
import zipfile
zf = zipfile.ZipFile('REPLACE_WITH_ZIPNAME.zip')
zf.extractall('.')
zf.close()
print('Done! Files extracted.')
"

    4. Install Python packages:
       pip install flask flask-cors pyjwt werkzeug requests

    5. Create the 2 workflows in Replit:

       Workflow 1:
         Name: Radd Hub
         Command: cd radd-hub && python3 radd_hub.py run --skip-setup

       Workflow 2:
         Name: Watch Prototype
         Command: cd _watch_prototype && PORT=8000 python run.py

    6. Add this Replit Secret:
         Name:  SESSION_SECRET
         Value: (get the value from Muhammad Rehan)

    7. Read JAZZMAX_MASTER.md — it tells you exactly what to do next

══════════════════════════════════════════════════════════════
""")
PYEOF
