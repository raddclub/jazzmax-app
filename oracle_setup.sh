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

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        JazzMAX Oracle Server Setup v1.0             ║"
echo "║   Production API + Optional Android Emulator        ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: System packages ──────────────────────────────────
echo -e "${CYAN}[1/7] Installing system packages...${NC}"
sudo apt-get update -qq
sudo apt-get install -y \
  python3 python3-pip python3-venv \
  nginx git curl wget unzip \
  supervisor ufw \
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
pip3 install flask flask-cors pyjwt werkzeug requests gunicorn --quiet
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

# Load env vars for supervisor
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

# ── Step 7: Android Emulator (optional — checks KVM first) ───
echo -e "${CYAN}[7/7] Checking Android emulator support...${NC}"
if [ -e /dev/kvm ]; then
  echo -e "  ${GREEN}✓ KVM is available — Android emulator CAN run on this server!${NC}"
  echo ""
  echo -e "  ${YELLOW}To install the Android emulator, run:${NC}"
  echo "    bash $PROJECT_DIR/oracle_android_emulator.sh"
  echo ""
  # Create the emulator setup as a separate script
  cat > "$PROJECT_DIR/oracle_android_emulator.sh" <<'EMULATOR'
#!/bin/bash
# Android ARM64 Emulator Setup for Oracle aarch64 server
# Run AFTER oracle_setup.sh completes

set -e
SDK_DIR="$HOME/android-sdk"
AVD_NAME="jazzmax_test"

echo "[1/5] Downloading Android command-line tools..."
mkdir -p "$SDK_DIR/cmdline-tools"
cd /tmp
wget -q "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -O cmdline-tools.zip
unzip -q cmdline-tools.zip -d "$SDK_DIR/cmdline-tools/"
mv "$SDK_DIR/cmdline-tools/cmdline-tools" "$SDK_DIR/cmdline-tools/latest"
rm cmdline-tools.zip

export ANDROID_HOME="$SDK_DIR"
export PATH="$PATH:$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools:$SDK_DIR/emulator"

echo "[2/5] Accepting licenses..."
yes | sdkmanager --licenses > /dev/null 2>&1 || true

echo "[3/5] Installing emulator + ARM64 system image..."
sdkmanager "platform-tools" "emulator" "platforms;android-29" "system-images;android-29;google_apis;arm64-v8a"

echo "[4/5] Creating AVD..."
echo "no" | avdmanager create avd \
  --name "$AVD_NAME" \
  --package "system-images;android-29;google_apis;arm64-v8a" \
  --device "pixel_4" \
  --force

echo "[5/5] Test launch (headless — will print 'emulator started' then exit)..."
$SDK_DIR/emulator/emulator -avd "$AVD_NAME" -no-window -no-audio -no-boot-anim -quit-after-boot 120 &
EMULATOR_PID=$!
sleep 10
if kill -0 $EMULATOR_PID 2>/dev/null; then
  echo "✓ Emulator process is running (PID $EMULATOR_PID)"
  kill $EMULATOR_PID
else
  echo "✗ Emulator exited early — check KVM permissions: sudo usermod -aG kvm $USER"
fi

echo ""
echo "══════════════════════════════════════════"
echo " Android emulator setup complete!"
echo " Start with: emulator -avd jazzmax_test -no-window -no-audio"
echo " Screenshot: adb exec-out screencap -p > screen.png"
echo "══════════════════════════════════════════"
EMULATOR
  chmod +x "$PROJECT_DIR/oracle_android_emulator.sh"
else
  echo -e "  ${YELLOW}⚠ KVM not available — Android emulator will be slow (software mode)${NC}"
  echo "  Check Oracle console: Instance → Edit → enable 'Nested Virtualization'"
fi

# ── Done ──────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              ✅ SETUP COMPLETE!                      ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  Production API:  http://92.4.95.252/api/           ║"
echo "║  Watch + Test:    http://92.4.95.252/watch/test     ║"
echo "║  Health check:    http://92.4.95.252/health         ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  JazzMAX APKs now connect to this server            ║"
echo "║  URL never changes — no more jazzmax_config.json    ║"
echo "║  updates when switching Replit accounts!            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Verify it works: curl http://92.4.95.252/health"
echo ""
