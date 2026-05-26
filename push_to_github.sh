#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║              JazzMAX — Push to GitHub                               ║
# ║                                                                      ║
# ║  Run at the end of every work session instead of create_zip.sh      ║
# ║  (or in addition to it).                                            ║
# ║                                                                      ║
# ║  HOW TO RUN:                                                         ║
# ║    bash push_to_github.sh                                            ║
# ║                                                                      ║
# ║  REQUIREMENT: Add GITHUB_TOKEN to Replit Secrets first              ║
# ║    Replit sidebar → Secrets → + Add Secret                          ║
# ║    Name: GITHUB_TOKEN                                                ║
# ║    Value: your GitHub Personal Access Token                         ║
# ╚══════════════════════════════════════════════════════════════════════╝

set -e

GITHUB_USER="raddclub"
GITHUB_REPO="raddflix-app"
WORKSPACE="/home/runner/workspace"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║         RaddFlix → GitHub Push                    ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── Check GITHUB_TOKEN is set ─────────────────────────────────────────────────
if [ -z "$GITHUB_TOKEN" ]; then
    echo "  ❌ ERROR: GITHUB_TOKEN secret is not set!"
    echo ""
    echo "  Fix: Replit sidebar → Secrets (🔒) → + Add Secret"
    echo "       Name:  GITHUB_TOKEN"
    echo "       Value: your GitHub Personal Access Token"
    echo ""
    echo "  Your token needs these permissions:"
    echo "    ✓ repo (full control)"
    echo ""
    exit 1
fi

echo "  ✓ GITHUB_TOKEN found"

# ── Step 1: Checkpoint SQLite database ───────────────────────────────────────
echo ""
echo "▶ Step 1/5 — Checkpointing database..."
python3 -c "
import sqlite3
db = sqlite3.connect('$WORKSPACE/radd-hub/data/radd_hub.db')
db.execute('PRAGMA wal_checkpoint(TRUNCATE)')
db.close()
print('  ✓ Database checkpointed')
" 2>/dev/null || echo "  ✓ Database ready"

# ── Step 2: Create GitHub repo if it doesn't exist ───────────────────────────
echo ""
echo "▶ Step 2/5 — Checking GitHub repo..."

HTTP_STATUS=$(curl -s -o /tmp/gh_repo_check.json -w "%{http_code}" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO")

if [ "$HTTP_STATUS" = "200" ]; then
    echo "  ✓ Repo already exists: github.com/$GITHUB_USER/$GITHUB_REPO"
elif [ "$HTTP_STATUS" = "404" ]; then
    echo "  → Repo not found, creating it..."
    CREATE_STATUS=$(curl -s -o /tmp/gh_create.json -w "%{http_code}" \
        -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user/repos" \
        -d "{
            \"name\": \"$GITHUB_REPO\",
            \"description\": \"JazzMAX — Flutter Android streaming app for Jazz SIM users in Pakistan\",
            \"private\": true,
            \"auto_init\": false
        }")
    if [ "$CREATE_STATUS" = "201" ]; then
        echo "  ✓ Repo created: github.com/$GITHUB_USER/$GITHUB_REPO (private)"
    else
        echo "  ❌ Failed to create repo (HTTP $CREATE_STATUS)"
        cat /tmp/gh_create.json
        exit 1
    fi
else
    echo "  ❌ GitHub API error (HTTP $HTTP_STATUS)"
    cat /tmp/gh_repo_check.json
    exit 1
fi

# ── Step 3: Set/update git remote ────────────────────────────────────────────
echo ""
echo "▶ Step 3/5 — Setting git remote..."
cd "$WORKSPACE"

REMOTE_URL="https://$GITHUB_TOKEN@github.com/$GITHUB_USER/$GITHUB_REPO.git"

if git remote get-url github 2>/dev/null; then
    git remote set-url github "$REMOTE_URL"
    echo "  ✓ Remote 'github' updated"
else
    git remote add github "$REMOTE_URL"
    echo "  ✓ Remote 'github' added"
fi

# ── Step 4: Configure git identity (needed on fresh Replit accounts) ──────────
echo ""
echo "▶ Step 4/5 — Configuring git identity..."
git config user.email "rehan@raddflix.app" 2>/dev/null || true
git config user.name "Muhammad Rehan" 2>/dev/null || true
echo "  ✓ Identity set"

# ── Step 5: Commit and push ───────────────────────────────────────────────────
echo ""
echo "▶ Step 5/5 — Committing and pushing..."

# Stage everything (gitignore handles exclusions)
git add -A

# Check if there's anything to commit
if git diff --cached --quiet; then
    echo "  ✓ Nothing new to commit — already up to date"
else
    COMMIT_MSG="RaddFlix update — $(date '+%Y-%m-%d %H:%M')"
    git commit -m "$COMMIT_MSG"
    echo "  ✓ Committed: $COMMIT_MSG"
fi

# Push to GitHub
echo "  → Pushing to github.com/$GITHUB_USER/$GITHUB_REPO ..."
git push github main --force-with-lease 2>&1 | sed "s/$GITHUB_TOKEN/[TOKEN]/g"

echo ""
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "  ✅ DONE! Code is live at:"
echo "     https://github.com/$GITHUB_USER/$GITHUB_REPO"
echo ""
echo "  HOW TO CONTINUE ON NEXT REPLIT ACCOUNT:"
echo ""
echo "  1. Create a new Repl (any type) and add GITHUB_TOKEN + SESSION_SECRET"
echo "     to Replit Secrets (sidebar → lock icon)"
echo ""
echo "  2. Open Shell and run ONE command:"
echo ""
echo '     curl -s -H "Authorization: token $GITHUB_TOKEN" \'
echo "       \"https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/main/setup_new_account.sh\" \\"
echo "       | bash"
echo ""
echo "  3. Tell the Replit Agent:"
echo '     "Set up the Radd Hub and Watch Prototype workflows"'
echo ""
echo "  4. Read JAZZMAX_MASTER.md — continue from where you left off"
echo ""
echo "══════════════════════════════════════════════════════════════"
