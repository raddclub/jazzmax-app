#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  JazzMAX Oracle Emulator Test Script
#  Run from oracle_setup.sh or GitHub Actions after APK build.
#
#  Usage (on Oracle server):
#    bash /opt/jazzmax/scripts/emulator_test.sh /path/to/app.apk
#
# ═══════════════════════════════════════════════════════════════

APK_PATH="${1:-/tmp/jazzmax-latest.apk}"
SCREENSHOTS_DIR="/tmp/jazzmax_screenshots"
SDK="$HOME/android-sdk"
EMULATOR="$SDK/emulator/emulator"
ADB="$SDK/platform-tools/adb"
AVD_NAME="jazzmax_test"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p "$SCREENSHOTS_DIR"

# ── Check emulator is installed ───────────────────────────────────────────────
if [ ! -f "$EMULATOR" ]; then
  echo -e "${RED}✗ Android emulator not found at $EMULATOR${NC}"
  echo "  Run: bash /opt/jazzmax/oracle_android_emulator.sh"
  exit 1
fi

if [ ! -e /dev/kvm ]; then
  echo -e "${YELLOW}⚠ KVM not available — emulator will be slow (software rendering)${NC}"
  echo "  Enable in Oracle console: Instance → Edit → Nested Virtualization"
fi

# ── Start emulator if not running ────────────────────────────────────────────
echo -e "${GREEN}[1/5] Checking emulator status...${NC}"
EMULATOR_RUNNING=$("$ADB" devices 2>/dev/null | grep emulator | grep -v offline | wc -l)

if [ "$EMULATOR_RUNNING" -eq 0 ]; then
  echo "  → Emulator not running. Starting..."
  nohup "$EMULATOR" -avd "$AVD_NAME" \
    -no-window -no-audio -no-boot-anim \
    -memory 2048 -cores 2 \
    > /tmp/emulator.log 2>&1 &
  EMULATOR_PID=$!
  echo "  → Emulator starting (PID $EMULATOR_PID) — waiting up to 120s for boot..."

  # Wait for emulator to boot
  BOOT_WAIT=0
  until "$ADB" shell getprop sys.boot_completed 2>/dev/null | grep -q "^1$"; do
    sleep 5
    BOOT_WAIT=$((BOOT_WAIT + 5))
    echo "  → Boot wait: ${BOOT_WAIT}s..."
    if [ $BOOT_WAIT -ge 120 ]; then
      echo -e "${RED}✗ Emulator boot timeout after 120s${NC}"
      echo "  Check: tail -20 /tmp/emulator.log"
      exit 1
    fi
  done
  echo -e "${GREEN}  ✓ Emulator booted!${NC}"
else
  echo -e "${GREEN}  ✓ Emulator already running${NC}"
fi

# ── Wait for package manager ──────────────────────────────────────────────────
echo -e "${GREEN}[2/5] Waiting for Android package manager...${NC}"
sleep 5
"$ADB" wait-for-device

# ── Install APK ───────────────────────────────────────────────────────────────
echo -e "${GREEN}[3/5] Installing JazzMAX APK...${NC}"
"$ADB" install -r "$APK_PATH"
echo -e "  ${GREEN}✓ APK installed: $APK_PATH${NC}"

# ── Launch app ────────────────────────────────────────────────────────────────
echo -e "${GREEN}[4/5] Launching JazzMAX...${NC}"
"$ADB" shell am start -n com.jazzmax.app/.MainActivity
sleep 8  # Wait for splash + onboarding

# ── Take screenshots ──────────────────────────────────────────────────────────
echo -e "${GREEN}[5/5] Capturing screenshots...${NC}"
TS=$(date +%Y%m%d_%H%M%S)

# Screenshot 1: Initial launch (splash / onboarding)
"$ADB" exec-out screencap -p > "$SCREENSHOTS_DIR/${TS}_01_launch.png"
echo "  → Saved: 01_launch.png"

sleep 5

# Screenshot 2: After splash (should be login or home)
"$ADB" exec-out screencap -p > "$SCREENSHOTS_DIR/${TS}_02_after_splash.png"
echo "  → Saved: 02_after_splash.png"

# Capture logcat (last 200 lines, filter JazzMAX + Flutter)
"$ADB" logcat -d -t 200 \
  | grep -E "(JazzMAX|flutter|FATAL|AndroidRuntime|Exception)" \
  > "$SCREENSHOTS_DIR/${TS}_logcat.txt" 2>/dev/null || true
echo "  → Saved: logcat.txt"

# Check for crashes
if grep -q "FATAL\|AndroidRuntime\|Force closing" "$SCREENSHOTS_DIR/${TS}_logcat.txt" 2>/dev/null; then
  echo -e "${RED}⚠ CRASH DETECTED in logcat — check ${TS}_logcat.txt${NC}"
else
  echo -e "${GREEN}  ✓ No crashes detected in logcat${NC}"
fi

echo ""
echo "══════════════════════════════════════════"
echo " Screenshots saved to: $SCREENSHOTS_DIR"
echo " Logcat saved to: $SCREENSHOTS_DIR/${TS}_logcat.txt"
echo " GitHub Actions will upload these as artifacts."
echo "══════════════════════════════════════════"
