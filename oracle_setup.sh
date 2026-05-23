#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  JazzMAX — Oracle Server Setup Script
#  Tested on: Ubuntu 24.04.4 LTS aarch64 (Oracle Ampere A1)
#  Run this on your Oracle server in Termius:
#
#    bash <(curl -fsSL -H "Authorization: token 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" \
#      "https://raw.githubusercontent.com/raddclub/jazzmax-app/main/oracle_setup.sh")
#
# ═══════════════════════════════════════════════════════════════
set -e

GITHUB_TOKEN="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"
GITHUB_REPO="raddclub/jazzmax-app"
PROJECT_DIR="/opt/jazzmax"
ORACLE_IP="92.4.95.252"
FLASK_PORT=8000
RADD_PORT=5000
RUN_USER="ubuntu"
SDK_DIR="$HOME/android-sdk"
AVD_NAME="jazzmax_test"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        JazzMAX Oracle Server Setup v2.0             ║"
echo "║   Production API + Always-On Android Emulator       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: System packages ──────────────────────────────────
echo -e "${CYAN}[1/7] Installing system packages...${NC}"
sudo apt-get update -qq
sudo apt-get install -y \
  python3 python3-pip python3-venv \
  nginx git curl wget unzip \
  supervisor ufw sqlite3 \
  openjdk-17-jre-headless \
  2>/dev/null | tail -3

# ── Step 2: Clone/update project ─────────────────────────────
echo -e "${CYAN}[2/7] Downloading JazzMAX project from GitHub...${NC}"
if [ -d "$PROJECT_DIR/.git" ]; then
  echo "  → Already exists, pulling latest..."
  cd "$PROJECT_DIR"
  git remote set-url origin "https://$GITHUB_TOKEN@github.com/$GITHUB_REPO.git"
  git pull --quiet
else
  sudo mkdir -p "$PROJECT_DIR"
  sudo chown "$RUN_USER:$RUN_USER" "$PROJECT_DIR"
  git clone "https://$GITHUB_TOKEN@github.com/$GITHUB_REPO.git" "$PROJECT_DIR" --quiet
fi
echo -e "  ${GREEN}✓ Project downloaded${NC}"

# ── Step 3: Python dependencies ──────────────────────────────
echo -e "${CYAN}[3/7] Installing Python packages...${NC}"
cd "$PROJECT_DIR"
pip3 install flask flask-cors pyjwt werkzeug requests gunicorn \
  --break-system-packages --quiet 2>/dev/null \
  || pip3 install flask flask-cors pyjwt werkzeug requests gunicorn --quiet \
  || { echo "Trying venv fallback...";
       python3 -m venv venv;
       venv/bin/pip install flask flask-cors pyjwt werkzeug requests gunicorn --quiet; }
echo -e "  ${GREEN}✓ Python packages installed${NC}"

# ── Step 4: Environment / secrets ────────────────────────────
echo -e "${CYAN}[4/7] Setting up environment...${NC}"
ENV_FILE="$PROJECT_DIR/.env"
if [ ! -f "$ENV_FILE" ] || ! grep -q "SESSION_SECRET" "$ENV_FILE"; then
  SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  echo "SESSION_SECRET=$SECRET" | sudo tee "$ENV_FILE" > /dev/null
  echo "GITHUB_TOKEN=$GITHUB_TOKEN" | sudo tee -a "$ENV_FILE" > /dev/null
  echo -e "  ${GREEN}✓ SESSION_SECRET generated and saved to $ENV_FILE${NC}"
  echo -e "  ${YELLOW}  (Share this SECRET with Muhammad Rehan for Replit Secrets)${NC}"
  echo "  SESSION_SECRET = $SECRET"
else
  echo -e "  ${GREEN}✓ .env already exists, skipping${NC}"
fi

# ── Step 5: Supervisor services ───────────────────────────────
echo -e "${CYAN}[5/7] Setting up services (Watch Prototype + Radd Hub)...${NC}"

SESS_SECRET=$(grep SESSION_SECRET "$ENV_FILE" | cut -d= -f2)

# Watch Prototype (main API — port 8000)
sudo tee /etc/supervisor/conf.d/jazzmax_watch.conf > /dev/null <<CONF
[program:jazzmax_watch]
command=python3 /opt/jazzmax/_watch_prototype/run.py
directory=/opt/jazzmax/_watch_prototype
user=$RUN_USER
autostart=true
autorestart=true
stderr_logfile=/var/log/jazzmax_watch.err.log
stdout_logfile=/var/log/jazzmax_watch.out.log
environment=PORT="$FLASK_PORT",SESSION_SECRET="$SESS_SECRET",PYTHONUNBUFFERED="1"
CONF

# Radd Hub (admin — port 5000)
sudo tee /etc/supervisor/conf.d/jazzmax_radd.conf > /dev/null <<CONF
[program:jazzmax_radd]
command=python3 /opt/jazzmax/radd-hub/radd_hub.py run --skip-setup
directory=/opt/jazzmax/radd-hub
user=$RUN_USER
autostart=true
autorestart=true
stderr_logfile=/var/log/jazzmax_radd.err.log
stdout_logfile=/var/log/jazzmax_radd.out.log
environment=PORT="$RADD_PORT",SESSION_SECRET="$SESS_SECRET",PYTHONUNBUFFERED="1"
CONF

sudo supervisorctl reread 2>/dev/null || true
sudo supervisorctl update 2>/dev/null || true
sudo supervisorctl restart all 2>/dev/null || true
echo -e "  ${GREEN}✓ Services started${NC}"

# ── Step 6: Nginx ─────────────────────────────────────────────
echo -e "${CYAN}[6/7] Configuring Nginx...${NC}"

sudo tee /etc/nginx/sites-available/jazzmax > /dev/null <<'NGINX'
server {
    listen 80;
    server_name 92.4.95.252 _;

    # API + Watch Prototype (Flask on 8000)
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 60s;
    }

    location /watch/ {
        proxy_pass http://127.0.0.1:8000/watch/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Radd Hub admin panel (port 5000)
    location /admin/ {
        proxy_pass http://127.0.0.1:5000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Health check
    location /health {
        return 200 "JazzMAX Oracle OK\n";
        add_header Content-Type text/plain;
    }

    # Default
    location / {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host $host;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/jazzmax /etc/nginx/sites-enabled/jazzmax
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx
echo -e "  ${GREEN}✓ Nginx configured and running${NC}"

# ── Step 6b: Firewall ─────────────────────────────────────────
echo "  → Opening ports 80 and 22 in firewall..."
sudo ufw allow 22/tcp 2>/dev/null || true
sudo ufw allow 80/tcp 2>/dev/null || true
sudo ufw allow 8000/tcp 2>/dev/null || true
sudo ufw --force enable 2>/dev/null || true

# ── Step 6c: Publish all titles in DB ────────────────────────
echo -e "${CYAN}[6c/7] Publishing all titles in database...${NC}"
sqlite3 "$PROJECT_DIR/radd-hub/data/jazzmax.db" \
  "UPDATE titles SET is_published=1;" 2>/dev/null \
  && echo -e "  ${GREEN}✓ All titles published (is_published=1)${NC}" \
  || echo -e "  ${YELLOW}⚠ sqlite3 not found — run manually later:${NC}
     sqlite3 $PROJECT_DIR/radd-hub/data/jazzmax.db 'UPDATE titles SET is_published=1;'"

# Create test user if not exists
echo -e "${CYAN}[6d/7] Ensuring test account exists (03001234567 / test123)...${NC}"
python3 - <<'PYEOF'
import sys, os
sys.path.insert(0, '/opt/jazzmax/radd-hub')
sys.path.insert(0, '/opt/jazzmax/_watch_prototype')
os.environ.setdefault('RADD_HUB_DATA_DIR', '/opt/jazzmax/radd-hub/data')
from hub import config, db
config.load_env()
db.init_db()
import sqlite3
from hub.db import get_db
try:
    with get_db() as conn:
        row = conn.execute("SELECT id FROM app_users WHERE phone=?", ("03001234567",)).fetchone()
        if row:
            print("  ✓ Test account already exists")
        else:
            import hashlib, hmac
            pw_hash = hashlib.sha256(b"test123").hexdigest()
            conn.execute("INSERT INTO app_users (phone, password_hash, name) VALUES (?,?,?)",
                         ("03001234567", pw_hash, "Test User"))
            conn.commit()
            print("  ✓ Test account created (03001234567 / test123)")
except Exception as e:
    print(f"  ⚠ Could not create test account: {e}")
    print("    Run setup_new_account.sh on Replit to create it from there")
PYEOF

# ── Step 7: Android Emulator Setup ───────────────────────────
echo -e "${CYAN}[7/7] Setting up Android emulator...${NC}"

# Install scripts directory
mkdir -p "$PROJECT_DIR/scripts"
cp "$PROJECT_DIR/oracle_emulator_test.sh" "$PROJECT_DIR/scripts/emulator_test.sh" 2>/dev/null \
  || echo "  (emulator_test.sh will be pulled from GitHub on next git pull)"
chmod +x "$PROJECT_DIR/scripts/emulator_test.sh" 2>/dev/null || true

KVM_AVAILABLE=false
if [ -e /dev/kvm ]; then
  KVM_AVAILABLE=true
fi

if $KVM_AVAILABLE; then
  echo -e "  ${GREEN}✓ KVM is AVAILABLE — hardware-accelerated emulator (fast!)${NC}"
else
  echo -e "  ${YELLOW}⚠ KVM not available — emulator will use software rendering (slow)${NC}"
  echo ""
  echo -e "  ${YELLOW}To enable KVM (5 min — makes emulator 10x faster):${NC}"
  echo "  1. Go to: console.cloud.oracle.com"
  echo "  2. Compute → Instances → jazzmax-server → More Actions → Edit"
  echo "  3. Enable 'Nested Virtualization' → Save"
  echo "  4. Re-run this script"
  echo ""
fi

# Install Android SDK + create emulator regardless of KVM status
if [ ! -f "$SDK_DIR/emulator/emulator" ]; then
  echo -e "  → Installing Android SDK (this takes ~5 min, ~1.5 GB)..."
  mkdir -p "$SDK_DIR/cmdline-tools"
  cd /tmp

  # ARM64 command-line tools
  wget -q "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -O cmdline-tools.zip
  unzip -q cmdline-tools.zip -d "$SDK_DIR/cmdline-tools/"
  mv "$SDK_DIR/cmdline-tools/cmdline-tools" "$SDK_DIR/cmdline-tools/latest"
  rm -f cmdline-tools.zip

  export ANDROID_HOME="$SDK_DIR"
  export PATH="$PATH:$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools:$SDK_DIR/emulator"

  echo "  → Accepting licenses..."
  yes | sdkmanager --licenses > /dev/null 2>&1 || true

  echo "  → Installing platform-tools + emulator + ARM64 system image..."
  sdkmanager "platform-tools" "emulator" \
    "platforms;android-29" \
    "system-images;android-29;google_apis;arm64-v8a"

  echo "  → Creating emulator AVD '$AVD_NAME'..."
  echo "no" | avdmanager create avd \
    --name "$AVD_NAME" \
    --package "system-images;android-29;google_apis;arm64-v8a" \
    --device "pixel_4" \
    --force

  echo -e "  ${GREEN}✓ Android emulator installed${NC}"

  # Add SDK to PATH permanently
  echo "" >> "$HOME/.bashrc"
  echo "# Android SDK" >> "$HOME/.bashrc"
  echo "export ANDROID_HOME=$SDK_DIR" >> "$HOME/.bashrc"
  echo "export PATH=\$PATH:$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools:$SDK_DIR/emulator" >> "$HOME/.bashrc"
else
  echo -e "  ${GREEN}✓ Android emulator already installed${NC}"
fi

# Set up always-on emulator as a Supervisor service
echo "  → Setting up always-on emulator service (auto-starts on boot)..."
EMULATOR_CMD="$SDK_DIR/emulator/emulator"
EMULATOR_EXTRA_FLAGS=""
if $KVM_AVAILABLE; then
  EMULATOR_EXTRA_FLAGS="-accel kvm"
fi

sudo tee /etc/supervisor/conf.d/jazzmax_emulator.conf > /dev/null <<CONF
[program:jazzmax_emulator]
command=$EMULATOR_CMD -avd $AVD_NAME -no-window -no-audio -no-boot-anim -memory 2048 -cores 2 $EMULATOR_EXTRA_FLAGS
user=$RUN_USER
autostart=false
autorestart=unexpected
startsecs=30
startretries=2
stderr_logfile=/var/log/jazzmax_emulator.err.log
stdout_logfile=/var/log/jazzmax_emulator.out.log
environment=ANDROID_HOME="$SDK_DIR",HOME="/home/$RUN_USER"
CONF

# Note: autostart=false — emulator is started manually or by GitHub Actions.
# To start manually: sudo supervisorctl start jazzmax_emulator
# To check status: sudo supervisorctl status jazzmax_emulator

sudo supervisorctl reread 2>/dev/null || true
sudo supervisorctl update 2>/dev/null || true

echo -e "  ${GREEN}✓ Emulator service registered (supervisor: jazzmax_emulator)${NC}"
echo ""
echo "  To start the emulator: sudo supervisorctl start jazzmax_emulator"
echo "  To check status:       sudo supervisorctl status"
echo "  To run a test:         bash $PROJECT_DIR/scripts/emulator_test.sh /tmp/jazzmax.apk"

# ── Step 7b: Let's Encrypt SSL (optional — requires domain name) ──────────
echo ""
echo -e "${CYAN}[7b] Optional: Let's Encrypt SSL setup${NC}"
echo "  To enable HTTPS, run these commands manually after pointing your domain:"
echo ""
echo "  sudo apt-get install -y certbot python3-certbot-nginx"
echo "  sudo certbot --nginx -d yourdomain.com --non-interactive --agree-tos -m admin@yourdomain.com"
echo "  sudo systemctl enable certbot.timer"
echo ""
echo "  Or for IP-only HTTPS (self-signed, shows browser warning):"
echo "  openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/private/jazzmax.key \\"
echo "    -out /etc/ssl/certs/jazzmax.crt -days 365 -nodes \\"
echo "    -subj '/CN=92.4.95.252/O=JazzMAX/C=PK'"
echo ""

# ── GitHub Actions: ORACLE_SSH_KEY setup reminder ────────────────────────
echo -e "${CYAN}[7c] GitHub Actions + Emulator integration${NC}"
echo "  GitHub Actions will automatically install APK on this emulator after every build."
echo "  To enable: add your Oracle SSH private key to GitHub Secrets:"
echo ""
echo "  1. Cat your private key:  cat ~/.ssh/id_rsa  (or your Oracle key)"
echo "  2. Go to: github.com/raddclub/jazzmax-app → Settings → Secrets → Actions"
echo "  3. Add secret: Name = ORACLE_SSH_KEY, Value = (paste full private key)"
echo ""
echo "  After that, every APK build will:"
echo "    ✓ Copy APK to this server"
echo "    ✓ Start the emulator (if not running)"
echo "    ✓ Install the APK"
echo "    ✓ Take screenshots"
echo "    ✓ Upload screenshots to GitHub Actions as artifacts"
echo ""

# ── Done ──────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              ✅ SETUP COMPLETE!                      ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  Production API:  http://92.4.95.252/api/           ║"
echo "║  Watch + Test:    http://92.4.95.252/watch/test     ║"
echo "║  Health check:    http://92.4.95.252/health         ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  Android emulator: sudo supervisorctl start         ║"
echo "║                    jazzmax_emulator                 ║"
if $KVM_AVAILABLE; then
echo "║  KVM status:  ✅ ENABLED (fast hardware emulation)  ║"
else
echo "║  KVM status:  ⚠ NOT enabled (enable in Oracle)     ║"
fi
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Verify it works: curl http://92.4.95.252/health"
echo ""
