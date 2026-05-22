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
# ║    Name: GITHUB_TOKEN   Value: (your token with repo permission)    ║
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
    echo "    3. Value: (your GitHub personal access token with repo permission)"
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
echo "  (This may take 30–90 seconds)"
echo ""

curl -s -L \
    -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/zipball/main" \
    -o /tmp/jazzmax_github.zip

ZIP_SIZE=$(du -sh /tmp/jazzmax_github.zip | cut -f1)
echo "  ✓ Downloaded: $ZIP_SIZE"

# ── Step 3: Extract project files using Node.js ───────────────────────────────
echo ""
echo "▶ Step 3/4 — Extracting project files..."

# Install adm-zip (tiny package, ~1 second, always available on Replit)
cd /tmp && npm install adm-zip --save --silent 2>/dev/null; cd "$WORKSPACE"

node << 'JSEOF'
const AdmZip = require('/tmp/node_modules/adm-zip');
const fs = require('fs');
const path = require('path');

// Files that belong to the Replit platform — never overwrite these
// NOTE: .replit is NOT protected so our project workflows auto-load correctly
const PROTECTED = new Set([
  'replit.nix',
  '.replitignore',
  'pnpm-lock.yaml',
]);

// Entire directories to skip (Replit/pnpm infra)
const PROTECTED_DIRS = ['node_modules/'];

// Paths that are too large or not needed at runtime
const SKIP_CONTAINS = ['local/browsers/', 'local/.chromium', '.git/'];

const dest = '/home/runner/workspace';
const zip = new AdmZip('/tmp/jazzmax_github.zip');
const entries = zip.getEntries();

// GitHub zip has a top-level folder like "raddclub-jazzmax-app-abc123/"
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
console.log(`  ✓ Extracted ${extracted} files  (skipped ${skipped} protected/system files)`);
JSEOF

# ── Step 4: Install Python packages ──────────────────────────────────────────
echo ""
echo "▶ Step 4/4 — Installing Python packages..."

REQUIREMENTS="$WORKSPACE/requirements.txt"

if [ -f "$REQUIREMENTS" ]; then
    if command -v pip3 &>/dev/null; then
        pip3 install -r "$REQUIREMENTS" -q && echo "  ✓ Python packages installed"
    elif command -v pip &>/dev/null; then
        pip install -r "$REQUIREMENTS" -q && echo "  ✓ Python packages installed"
    else
        echo "  ⚠  pip not found — packages will be installed when workflows start"
        echo "     Or tell the Agent: \"Install python3 and pip, then restart workflows\""
    fi
else
    if command -v pip3 &>/dev/null; then
        pip3 install flask flask-cors pyjwt werkzeug requests -q
        echo "  ✓ Core Python packages installed (no requirements.txt found)"
    fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "  ✅ SETUP COMPLETE!"
echo ""
echo "  ──────────────────────────────────────────────────────────"
echo "  NEXT STEPS:"
echo "  ──────────────────────────────────────────────────────────"
echo ""
echo "  1. REFRESH your browser (F5)"
echo "     Workflows should appear automatically from the .replit file."
echo ""
echo "  2. If workflows don't appear, tell the Agent:"
echo '     "Create Radd Hub workflow: cd radd-hub && python3 radd_hub.py run --skip-setup'
echo '      (port 5000) and Watch Prototype: cd _watch_prototype && PORT=8000 python3 run.py'
echo '      (port 8000)"'
echo ""
echo "  3. Add SESSION_SECRET to Replit Secrets if not already:"
echo "     Sidebar → Secrets (🔒) → + Add Secret"
echo "     Name: SESSION_SECRET   Value: (check your notes)"
echo ""
echo "  4. Update jazzmax_config.json with this account's dev domain URL"
echo "     See HANDOFF.md Step 5 for exact instructions."
echo ""
echo "  5. Read HANDOFF.md for full details and troubleshooting."
echo ""
echo "══════════════════════════════════════════════════════════════"
echo ""
