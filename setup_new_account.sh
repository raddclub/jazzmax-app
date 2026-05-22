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

# ── Step 3: Extract project files (Node.js — always available on Replit) ──────
echo ""
echo "▶ Step 3/4 — Extracting project files..."

# Install adm-zip quietly (tiny package, ~1 second)
cd /tmp && npm install adm-zip --save --silent 2>/dev/null; cd "$WORKSPACE"

node << 'JSEOF'
const AdmZip = require('/tmp/node_modules/adm-zip');
const fs = require('fs');
const path = require('path');

const PROTECTED = new Set([
  '.replit', 'replit.nix', '.replitignore',
  'pnpm-workspace.yaml', 'pnpm-lock.yaml', 'package.json',
  'tsconfig.json', 'tsconfig.base.json',
]);
const PROTECTED_DIRS = ['node_modules/', 'artifacts/', 'lib/', 'scripts/'];
const SKIP_CONTAINS = ['local/browsers/', 'local/.chromium'];

const dest = '/home/runner/workspace';
const zip = new AdmZip('/tmp/jazzmax_github.zip');
const entries = zip.getEntries();

const prefix = entries[0].entryName.split('/')[0] + '/';
let extracted = 0, skipped = 0;

for (const entry of entries) {
  const rel = entry.entryName.slice(prefix.length);
  if (!rel) { skipped++; continue; }
  if (SKIP_CONTAINS.some(sc => rel.includes(sc))) { skipped++; continue; }
  const base = path.basename(rel);
  if (PROTECTED.has(base)) { skipped++; continue; }
  if (PROTECTED_DIRS.some(pd => rel.startsWith(pd))) { skipped++; continue; }
  const destPath = path.join(dest, rel);
  if (entry.isDirectory) {
    fs.mkdirSync(destPath, { recursive: true });
  } else {
    fs.mkdirSync(path.dirname(destPath), { recursive: true });
    fs.writeFileSync(destPath, entry.getData());
    extracted++;
  }
}
console.log(`  ✓ Extracted ${extracted} files  (skipped ${skipped} protected/binary files)`);
JSEOF

# ── Step 4: Install Python packages (if Python is available) ──────────────────
echo ""
echo "▶ Step 4/4 — Python packages..."

if command -v python3 &>/dev/null && command -v pip3 &>/dev/null; then
    pip3 install flask flask-cors pyjwt werkzeug requests -q
    echo "  ✓ Python packages ready"
elif command -v pip &>/dev/null; then
    pip install flask flask-cors pyjwt werkzeug requests -q
    echo "  ✓ Python packages ready"
else
    echo "  ⚠  Python3/pip not found — the Replit Agent will install it automatically."
    echo "  Just tell the Agent: \"Set up the Radd Hub and Watch Prototype workflows\""
fi

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
