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

if [ -z "$ORACLE_SSH_KEY" ]; then
    echo "  ❌ ERROR: ORACLE_SSH_KEY secret is not set!"
    exit 1
fi

# ── Reconstruct SSH key (stored as one-liner in Replit secret) ───────────────
KEY_FILE=$(mktemp /tmp/oracle_key_XXXXXX.pem)
python3 - <<PYEOF
import os, sys
raw = os.environ.get('ORACLE_SSH_KEY', '').strip()
raw = raw.replace('-----BEGIN OPENSSH PRIVATE KEY-----', '')
raw = raw.replace('-----END OPENSSH PRIVATE KEY-----', '')
b64 = ''.join(raw.split())
wrapped = '\n'.join(b64[i:i+70] for i in range(0, len(b64), 70))
key = '-----BEGIN OPENSSH PRIVATE KEY-----\n' + wrapped + '\n-----END OPENSSH PRIVATE KEY-----\n'
with open('${KEY_FILE}', 'w') as f:
    f.write(key)
PYEOF
chmod 600 "$KEY_FILE"

SSH="ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o ConnectTimeout=15"
SCP="scp -i $KEY_FILE -o StrictHostKeyChecking=no -o ConnectTimeout=15"

echo "  → Testing connection to Oracle..."
if ! $SSH ${ORACLE_USER}@${ORACLE_IP} "echo OK" > /dev/null 2>&1; then
    echo "  ❌ Cannot connect to Oracle VPS"
    rm -f "$KEY_FILE"
    exit 1
fi
echo "  ✅ Connection OK"

echo ""
echo "▶ Syncing backend files..."

# Create remote directories
$SSH ${ORACLE_USER}@${ORACLE_IP} "
    mkdir -p $REMOTE_DIR/_watch_prototype/routes
    mkdir -p $REMOTE_DIR/_watch_prototype/templates
    mkdir -p $REMOTE_DIR/radd-hub/hub
    mkdir -p $REMOTE_DIR/radd-hub/data
    mkdir -p $REMOTE_DIR/jazzmax_flutter/lib/services
    mkdir -p $REMOTE_DIR/jazzmax_flutter/lib/core/db
    mkdir -p $REMOTE_DIR/jazzmax_flutter/lib/screens
    mkdir -p $REMOTE_DIR/jazzmax_flutter/lib/widgets
    mkdir -p $REMOTE_DIR/jazzmax_flutter/lib/providers
    mkdir -p $REMOTE_DIR/jazzmax_flutter/lib/models
"

# Sync Watch Prototype routes
for f in $(find "$WORKSPACE/_watch_prototype" -name "*.py" | grep -v __pycache__ | grep -v .pyc); do
    rel="${f#$WORKSPACE/}"
    $SCP -q "$f" "${ORACLE_USER}@${ORACLE_IP}:${REMOTE_DIR}/${rel}" 2>/dev/null && echo "  ✅ $rel" || echo "  ❌ $rel"
done

# Sync radd-hub python files (not DB)
for f in $(find "$WORKSPACE/radd-hub" -name "*.py" | grep -v __pycache__ | grep -v .pyc); do
    rel="${f#$WORKSPACE/}"
    $SCP -q "$f" "${ORACLE_USER}@${ORACLE_IP}:${REMOTE_DIR}/${rel}" 2>/dev/null
done
echo "  ✅ radd-hub/*.py"

# Sync flutter dart files
for f in $(find "$WORKSPACE/jazzmax_flutter/lib" -name "*.dart"); do
    rel="${f#$WORKSPACE/}"
    $SCP -q "$f" "${ORACLE_USER}@${ORACLE_IP}:${REMOTE_DIR}/${rel}" 2>/dev/null
done
echo "  ✅ jazzmax_flutter/lib/*.dart"

# Sync root files
for f in JAZZMAX_MASTER.md HANDOFF.md requirements.txt push_to_github.sh push_to_oracle.sh; do
    $SCP -q "$WORKSPACE/$f" "${ORACLE_USER}@${ORACLE_IP}:${REMOTE_DIR}/$f" 2>/dev/null && echo "  ✅ $f"
done

# Add TMDB keys to Oracle DB (plaintext, no encryption)
echo ""
echo "▶ Updating TMDB keys on Oracle..."
$SSH ${ORACLE_USER}@${ORACLE_IP} "python3 -c \"
import sqlite3, time
DB = '$REMOTE_DIR/radd-hub/data/radd_hub.db'
try:
    conn = sqlite3.connect(DB)
    conn.execute(\\\"DELETE FROM keys WHERE provider='tmdb'\\\")
    now = int(time.time())
    conn.execute(\\\"INSERT INTO keys(provider,label,value_enc,is_active,created_at,updated_at) VALUES('tmdb','tmdb-key-1','69dc400803546646ccfa74add11d424b',1,?,?)\\\", (now,now))
    conn.execute(\\\"INSERT INTO keys(provider,label,value_enc,is_active,created_at,updated_at) VALUES('tmdb','tmdb-key-2','d078f97b2b7992a234ee6198021a0e14',1,?,?)\\\", (now,now))
    conn.commit(); conn.close()
    print('  ✅ TMDB keys added to Oracle DB')
except Exception as e:
    print(f'  ⚠️ DB update: {e}')
\"" 2>/dev/null || echo "  ⚠️ DB not yet initialized (will init on first run)"

echo ""
echo "▶ Restarting services on Oracle..."
$SSH ${ORACLE_USER}@${ORACLE_IP} "
    pkill -f '_watch_prototype/run.py' 2>/dev/null || true
    pkill -f 'radd_hub.py' 2>/dev/null || true
    sleep 1
    cd $REMOTE_DIR
    pip3 install -r requirements.txt -q --break-system-packages 2>/dev/null | tail -1 || true
    nohup python3 _watch_prototype/run.py > /tmp/watch.log 2>&1 &
    echo '  ✅ Watch Prototype started (PID: '\$!')'
    sleep 2
    nohup bash -c 'cd radd-hub && python3 radd_hub.py run --skip-setup' > /tmp/hub.log 2>&1 &
    echo '  ✅ Radd Hub started (PID: '\$!')'
"

rm -f "$KEY_FILE"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   ✅ Oracle sync complete!                       ║"
echo "║   API:   http://$ORACLE_IP:6000          ║"
echo "║   Admin: http://$ORACLE_IP:5000          ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
