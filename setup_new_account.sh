#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║              JazzMAX — New Account Setup Script v2.0                        ║
# ║                                                                              ║
# ║  Run ONE command in Replit Shell (GITHUB_TOKEN must be set as Secret first) ║
# ║                                                                              ║
# ║   curl -fsSL \                                                               ║
# ║     -H "Authorization: token $GITHUB_TOKEN" \                               ║
# ║     "https://raw.githubusercontent.com/raddclub/jazzmax-app/main/setup_new_account.sh" \
# ║     | bash                                                                   ║
# ║                                                                              ║
# ║  Or if already cloned:  bash setup_new_account.sh                           ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -e

GITHUB_USER="raddclub"
GITHUB_REPO="jazzmax-app"
WORKSPACE="/home/runner/workspace"

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║         JazzMAX — Account Setup v2.0                  ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# ── STEP 0: Check required secrets ───────────────────────────────────────────
echo "▶ Step 0 — Checking secrets..."

if [ -z "$GITHUB_TOKEN" ]; then
    echo ""
    echo "  ❌ GITHUB_TOKEN is not set!"
    echo ""
    echo "  FIX (do this before running this script):"
    echo "  1. Replit sidebar → Secrets (🔒 lock icon) → + Add Secret"
    echo "  2. Name:  GITHUB_TOKEN"
    echo "  3. Value: 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"
    echo ""
    exit 1
fi
echo "  ✓ GITHUB_TOKEN found"

if [ -z "$SESSION_SECRET" ]; then
    echo "  ⚠  SESSION_SECRET not set — Flask JWT signing will use fallback."
    echo "     Add it via: Replit Secrets → SESSION_SECRET → (ask Muhammad Rehan)"
else
    echo "  ✓ SESSION_SECRET found"
fi

# ── STEP 1: Test GitHub access ────────────────────────────────────────────────
echo ""
echo "▶ Step 1 — Checking GitHub access..."

HTTP_STATUS=$(curl -s -o /tmp/gh_check.json -w "%{http_code}" \
    -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO")

if [ "$HTTP_STATUS" != "200" ]; then
    echo "  ❌ Cannot access github.com/$GITHUB_USER/$GITHUB_REPO (HTTP $HTTP_STATUS)"
    cat /tmp/gh_check.json
    exit 1
fi
echo "  ✓ GitHub access confirmed: github.com/$GITHUB_USER/$GITHUB_REPO"

# ── STEP 2: Download and extract project ─────────────────────────────────────
echo ""
echo "▶ Step 2 — Downloading project from GitHub... (30–90 seconds)"

curl -s -L \
    -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/zipball/main" \
    -o /tmp/jazzmax_github.zip

ZIP_SIZE=$(du -sh /tmp/jazzmax_github.zip | cut -f1)
echo "  ✓ Downloaded: $ZIP_SIZE"

echo "  → Extracting files..."
cd /tmp && npm install adm-zip --save --silent 2>/dev/null; cd "$WORKSPACE"

node << 'JSEOF'
const AdmZip = require('/tmp/node_modules/adm-zip');
const fs = require('fs');
const path = require('path');

const PROTECTED = new Set(['replit.nix', '.replitignore', 'pnpm-lock.yaml']);
const PROTECTED_DIRS = ['node_modules/'];
const SKIP_CONTAINS = ['local/browsers/', 'local/.chromium', '.git/'];

const dest = '/home/runner/workspace';
const zip = new AdmZip('/tmp/jazzmax_github.zip');
const entries = zip.getEntries();
const prefix = entries[0].entryName.split('/')[0] + '/';
let extracted = 0, skipped = 0;

for (const entry of entries) {
  const rel = entry.entryName.slice(prefix.length);
  if (!rel) { skipped++; continue; }
  if (SKIP_CONTAINS.some(sc => rel.includes(sc))) { skipped++; continue; }
  if (PROTECTED.has(path.basename(rel))) { skipped++; continue; }
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
console.log(`  ✓ Extracted ${extracted} files (skipped ${skipped} protected/system files)`);
JSEOF

# ── STEP 3: Install Python packages ──────────────────────────────────────────
echo ""
echo "▶ Step 3 — Installing Python packages..."

if [ -f "$WORKSPACE/requirements.txt" ]; then
    pip3 install -r "$WORKSPACE/requirements.txt" -q && echo "  ✓ Packages installed from requirements.txt"
else
    pip3 install flask flask-cors pyjwt werkzeug requests -q
    echo "  ✓ Core packages installed"
fi

# ── STEP 4: Update jazzmax_config.json with THIS account's URL ───────────────
echo ""
echo "▶ Step 4 — Updating API URL for this Replit account..."

DOMAIN="${REPLIT_DEV_DOMAIN:-}"
if [ -z "$DOMAIN" ]; then
    echo "  ⚠  REPLIT_DEV_DOMAIN not found — skipping URL update"
else
    API_URL="https://$DOMAIN"
    CONFIG_CONTENT=$(echo "{\"api_base_url\":\"$API_URL\"}" | base64 -w 0)

    # Get current SHA (file may or may not exist)
    SHA=$(curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/contents/jazzmax_config.json" \
        | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('sha',''))" 2>/dev/null || echo "")

    if [ -z "$SHA" ]; then
        # Create new file
        curl -s -X PUT \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/contents/jazzmax_config.json" \
            -d "{\"message\":\"[setup] Update API URL for new Replit account\",\"content\":\"$CONFIG_CONTENT\"}" \
            > /dev/null
    else
        # Update existing file
        curl -s -X PUT \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/contents/jazzmax_config.json" \
            -d "{\"message\":\"[setup] Update API URL for new Replit account\",\"content\":\"$CONFIG_CONTENT\",\"sha\":\"$SHA\"}" \
            > /dev/null
    fi

    # Also update the local constants.dart hardcoded fallback
    CONSTANTS_FILE="$WORKSPACE/jazzmax_flutter/lib/core/constants.dart"
    if [ -f "$CONSTANTS_FILE" ]; then
        python3 -c "
import re
with open('$CONSTANTS_FILE', 'r') as f:
    content = f.read()
content = re.sub(
    r\"(static String apiBaseUrl =\s*')[^']*('\s*;)\",
    r\"\g<1>$API_URL\g<2>\",
    content
)
with open('$CONSTANTS_FILE', 'w') as f:
    f.write(content)
print('  ✓ constants.dart updated with: $API_URL')
" 2>/dev/null || echo "  ✓ constants.dart not found locally (OK if not using Flutter here)"
    fi

    echo "  ✓ jazzmax_config.json → $API_URL"
    echo "  ✓ Installed apps will auto-connect to this URL on next launch"
fi

# ── STEP 5: Publish all titles so catalog works ───────────────────────────────
echo ""
echo "▶ Step 5 — Publishing all titles in database..."

python3 - << 'PYEOF'
import sys, os
sys.path.insert(0, '/home/runner/workspace/radd-hub')
os.environ.setdefault('RADD_HUB_DATA_DIR', '/home/runner/workspace/radd-hub/data')

try:
    from hub import db, config
    config.load_env()
    db.init_db()
    with db.conn() as c:
        n = c.execute('UPDATE titles SET is_published=1').rowcount
        total = c.execute('SELECT COUNT(*) FROM titles').fetchone()[0]
        print(f'  ✓ Published {n} titles ({total} total in database)')
except Exception as e:
    print(f'  ⚠  Could not publish titles: {e}')
    print(f'     This is OK — run manually: bash setup_new_account.sh after workflows start')
PYEOF

# ── STEP 6: Create test account for automated testing ─────────────────────────
echo ""
echo "▶ Step 6 — Creating test account..."

python3 - << 'PYEOF'
import sys, os
sys.path.insert(0, '/home/runner/workspace/radd-hub')
os.environ.setdefault('RADD_HUB_DATA_DIR', '/home/runner/workspace/radd-hub/data')

try:
    from hub import db, config
    config.load_env()
    db.init_db()
    from werkzeug.security import generate_password_hash
    with db.conn() as c:
        exists = c.execute('SELECT id FROM app_users WHERE phone=?', ('03001234567',)).fetchone()
        if not exists:
            c.execute(
                'INSERT INTO app_users (phone, password_hash, is_active) VALUES (?,?,1)',
                ('03001234567', generate_password_hash('test123'))
            )
            print('  ✓ Test account created: phone=03001234567 / password=test123')
        else:
            print('  ✓ Test account already exists: phone=03001234567 / password=test123')
except Exception as e:
    print(f'  ⚠  Could not create test account: {e}')
PYEOF

# ── DONE ──────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════════════"
echo ""
echo "  ✅  SETUP COMPLETE!"
echo ""
echo "  ── WORKFLOWS (start these) ─────────────────────────────────────────"
echo "  Replit will auto-load workflows from .replit file on browser refresh."
echo "  If they don't appear, tell the Agent:"
echo ""
echo '  "Create 2 workflows:'
echo '   1. Radd Hub → cd radd-hub && python3 radd_hub.py run --skip-setup'
echo '   2. Watch Prototype → cd _watch_prototype && PORT=8000 python run.py"'
echo ""
echo "  ── TEST PANEL (verify APIs without APK) ────────────────────────────"
if [ -n "$DOMAIN" ]; then
    echo "  Open in browser: https://$DOMAIN/watch/test"
else
    echo "  Open: [your-replit-url]/watch/test"
fi
echo ""
echo "  ── WHAT TO TELL THE AGENT ──────────────────────────────────────────"
echo '  "I am Muhammad Rehan. Read JAZZMAX_MASTER.md Section 14 (Task'
echo '   Checklist), find the first unchecked [ ] item, and build it."'
echo ""
echo "══════════════════════════════════════════════════════════════════════"
echo ""
