#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║           JazzMAX — New Account Setup Script                        ║
# ║                                                                      ║
# ║  Run this on any NEW Replit account to set up JazzMAX from GitHub.  ║
# ║                                                                      ║
# ║  HOW TO RUN (in Replit Shell):                                       ║
# ║    bash setup_new_account.sh                                         ║
# ║                                                                      ║
# ║  REQUIREMENT FIRST: Add GITHUB_TOKEN to Replit Secrets              ║
# ║    Sidebar → Secrets (lock icon) → + Add Secret                     ║
# ║    Name: GITHUB_TOKEN   Value: (your token)                         ║
# ╚══════════════════════════════════════════════════════════════════════╝

set -e

GITHUB_USER="raddclub"
GITHUB_REPO="jazzmax-app"
WORKSPACE="/home/runner/workspace"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║       JazzMAX — New Account Setup                    ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Check GITHUB_TOKEN ────────────────────────────────────────────────────────
if [ -z "$GITHUB_TOKEN" ]; then
    echo "  ❌ ERROR: GITHUB_TOKEN secret is not set!"
    echo ""
    echo "  Fix:"
    echo "    1. Replit sidebar → Secrets (🔒 lock icon) → + Add Secret"
    echo "    2. Name:  GITHUB_TOKEN"
    echo "    3. Value: (your GitHub personal access token)"
    echo "    4. Run this script again"
    echo ""
    exit 1
fi
echo "  ✓ GITHUB_TOKEN found"

# ── Step 1: Test GitHub access ────────────────────────────────────────────────
echo ""
echo "▶ Step 1/4 — Checking GitHub access..."

HTTP_STATUS=$(curl -s -o /tmp/gh_check.json -w "%{http_code}" \
    -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO")

if [ "$HTTP_STATUS" != "200" ]; then
    echo "  ❌ Cannot access github.com/$GITHUB_USER/$GITHUB_REPO (HTTP $HTTP_STATUS)"
    echo "  Check that GITHUB_TOKEN has 'repo' permission."
    cat /tmp/gh_check.json
    exit 1
fi
echo "  ✓ Access confirmed: github.com/$GITHUB_USER/$GITHUB_REPO"

# ── Step 2: Download project zip from GitHub ──────────────────────────────────
echo ""
echo "▶ Step 2/4 — Downloading project from GitHub..."
echo "  (This may take 30-60 seconds — the repo is ~90MB)"
echo ""

curl -s -L \
    -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/zipball/main" \
    -o /tmp/jazzmax_github.zip

ZIP_SIZE=$(du -sh /tmp/jazzmax_github.zip | cut -f1)
echo "  ✓ Downloaded: $ZIP_SIZE"

# ── Step 3: Extract project files ─────────────────────────────────────────────
echo ""
echo "▶ Step 3/4 — Extracting project files..."

python3 << 'PYEOF'
import zipfile, os, shutil
from pathlib import Path

src = '/tmp/jazzmax_github.zip'
dest = '/home/runner/workspace'

z = zipfile.ZipFile(src)
names = z.namelist()

# GitHub zips wrap everything in a top-level folder like "raddclub-jazzmax-app-abc123/"
prefix = names[0].split('/')[0] + '/'

# These Replit-managed files must NEVER be overwritten
PROTECTED = {
    '.replit', 'replit.nix', '.replitignore',
    'pnpm-workspace.yaml', 'pnpm-lock.yaml', 'package.json',
    'tsconfig.json', 'tsconfig.base.json',
}
PROTECTED_DIRS = {
    '.git/', 'node_modules/', 'artifacts/', 'lib/', 'scripts/',
}

# Heavy binaries we don't need (large Chromium/ffmpeg installs)
SKIP_CONTAINS = [
    'local/browsers/',
    'local/.chromium',
]

extracted = 0
skipped = 0

for name in names:
    rel = name[len(prefix):]
    if not rel:
        continue

    # Skip heavy binaries
    skip = False
    for sc in SKIP_CONTAINS:
        if sc in rel:
            skip = True
            break
    if skip:
        skipped += 1
        continue

    # Skip Replit-managed files
    base = Path(rel).name
    if base in PROTECTED:
        skipped += 1
        continue
    for pd in PROTECTED_DIRS:
        if rel.startswith(pd):
            skip = True
            break
    if skip:
        skipped += 1
        continue

    dest_path = os.path.join(dest, rel)

    if name.endswith('/'):
        os.makedirs(dest_path, exist_ok=True)
    else:
        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
        with z.open(name) as src_f, open(dest_path, 'wb') as dst_f:
            shutil.copyfileobj(src_f, dst_f)
        extracted += 1

print(f"  ✓ Extracted {extracted} files  (skipped {skipped} protected/binary files)")
PYEOF

# ── Step 4: Install Python packages ───────────────────────────────────────────
echo ""
echo "▶ Step 4/4 — Installing Python packages..."
pip install flask flask-cors pyjwt werkzeug requests -q
echo "  ✓ Python packages ready"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "  ✅ FILES SETUP COMPLETE!"
echo ""
echo "  ──────────────────────────────────────────────────────────"
echo "  NEXT STEPS (do these now):"
echo "  ──────────────────────────────────────────────────────────"
echo ""
echo "  1. Add SESSION_SECRET to Replit Secrets (if not already):"
echo "     Sidebar → Secrets (🔒) → + Add Secret"
echo "     Name: SESSION_SECRET   Value: (ask Muhammad Rehan)"
echo ""
echo "  2. Tell the Replit Agent (type this in the chat):"
echo ""
echo '     "Set up the Radd Hub and Watch Prototype workflows"'
echo ""
echo "     The agent will create both workflows automatically."
echo ""
echo "  3. Read JAZZMAX_MASTER.md → go to Section 14 (Task Checklist)"
echo "     Find the first unchecked [ ] item → tell the agent to build it"
echo ""
echo "══════════════════════════════════════════════════════════════"
echo ""
