#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║              JazzMAX — Push to Oracle Server                        ║
# ║                                                                      ║
# ║  Syncs backend code to Oracle VPS (92.4.95.252)                     ║
# ║                                                                      ║
# ║  HOW TO RUN:                                                         ║
# ║    bash push_to_oracle.sh                                            ║
# ║                                                                      ║
# ║  REQUIREMENT: Add ORACLE_SSH_KEY to Replit Secrets                  ║
# ╚══════════════════════════════════════════════════════════════════════╝

set -e

ORACLE_IP="92.4.95.252"
ORACLE_USER="ubuntu"
WORKSPACE="/home/runner/workspace"
REMOTE_DIR="/home/ubuntu/jazzmax"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║         JazzMAX → Oracle VPS Sync               ║"
echo "║         Host: $ORACLE_IP                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── Check ORACLE_SSH_KEY is set ───────────────────────────────────────────────
if [ -z "$ORACLE_SSH_KEY" ]; then
    echo "  ❌ ERROR: ORACLE_SSH_KEY secret is not set!"
    echo ""
    echo "  Fix: Replit sidebar → Secrets (🔒) → + Add Secret"
    echo "       Name:  ORACLE_SSH_KEY"
    echo "       Value: your Oracle VPS private SSH key"
    echo ""
    exit 1
fi

# Write key to temp file
KEY_FILE=$(mktemp)
echo "$ORACLE_SSH_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

SSH_OPTS="-i $KEY_FILE -o StrictHostKeyChecking=no -o ConnectTimeout=15"

echo "  → Testing connection to Oracle..."
if ! ssh $SSH_OPTS ${ORACLE_USER}@${ORACLE_IP} "echo OK" > /dev/null 2>&1; then
    echo "  ❌ Cannot connect to Oracle VPS"
    echo "     Check your ORACLE_SSH_KEY secret and that the server is running"
    rm -f "$KEY_FILE"
    exit 1
fi
echo "  ✅ Connection OK"

echo ""
echo "  → Syncing backend to Oracle..."

# Sync backend (watch prototype + radd hub) to Oracle
rsync -az --delete \
    -e "ssh $SSH_OPTS" \
    --exclude="*.pyc" \
    --exclude="__pycache__" \
    --exclude=".git" \
    --exclude="*.db" \
    --exclude="radd-hub/data/*.json" \
    --exclude="radd-hub/uploads/" \
    "$WORKSPACE/_watch_prototype/" \
    "${ORACLE_USER}@${ORACLE_IP}:${REMOTE_DIR}/_watch_prototype/"

rsync -az --delete \
    -e "ssh $SSH_OPTS" \
    --exclude="*.pyc" \
    --exclude="__pycache__" \
    --exclude=".git" \
    --exclude="data/*.db" \
    --exclude="uploads/" \
    "$WORKSPACE/radd-hub/" \
    "${ORACLE_USER}@${ORACLE_IP}:${REMOTE_DIR}/radd-hub/"

echo "  ✅ Backend synced"

echo ""
echo "  → Restarting services on Oracle..."
ssh $SSH_OPTS ${ORACLE_USER}@${ORACLE_IP} "
    cd ${REMOTE_DIR}
    # Restart watch prototype (API server)
    pkill -f '_watch_prototype/run.py' 2>/dev/null || true
    sleep 1
    nohup python3 _watch_prototype/run.py > /tmp/watch_prototype.log 2>&1 &
    echo 'Watch Prototype restarted (PID: '$!')'
    
    # Restart radd hub admin panel if it's running
    pkill -f 'radd-hub/run.py' 2>/dev/null || true
    sleep 1
    nohup python3 radd-hub/run.py > /tmp/radd_hub.log 2>&1 &
    echo 'Radd Hub restarted (PID: '$!')'
"

rm -f "$KEY_FILE"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   ✅ Oracle sync complete!                       ║"
echo "║   API: http://${ORACLE_IP}:6000              ║"
echo "║   Admin: http://${ORACLE_IP}:5000            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
