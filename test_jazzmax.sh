#!/usr/bin/env bash
# JazzMAX emulator smoke test.
# Called by .github/workflows/emulator_test.yml via:
#   script: bash test_jazzmax.sh "${{ steps.apk.outputs.path }}"
set -euo pipefail

APK_PATH="${1:?Usage: $0 <path/to/apk>}"

echo "════════════════════════════════════"
echo "  JazzMAX Emulator Test"
echo "════════════════════════════════════"
echo "APK: $APK_PATH"

# Wait for emulator to be fully ready
echo ""
echo "⏳ Waiting for emulator..."
adb wait-for-device
adb shell input keyevent 82

# Install APK
echo ""
echo "📦 Installing APK..."
adb install -r "$APK_PATH"
echo "✅ APK installed"

# Start logcat in background
adb logcat -c
adb logcat > logs/logcat_full.txt &
LOGCAT_PID=$!

# Launch the app
echo ""
echo "🚀 Launching JazzMAX..."
adb shell am start -n com.jazzmax.app/.MainActivity
echo "✅ App launched"

# ── Screenshots ───────────────────────────────────────────────────────────────

sleep 5
echo "📸 Screenshot 1: Splash screen (5s)"
adb exec-out screencap -p > screenshots/01_splash.png
echo "✅ Splash screenshot saved"

sleep 15
echo "📸 Screenshot 2: Home screen (20s)"
adb exec-out screencap -p > screenshots/02_home.png
echo "✅ Home screenshot saved"

sleep 10
echo "📸 Screenshot 3: Catalog loaded (30s)"
adb exec-out screencap -p > screenshots/03_catalog.png
echo "✅ Catalog screenshot saved"

# Stop logcat
kill "$LOGCAT_PID" 2>/dev/null || true

# ── Crash analysis ────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════"
echo "  Crash Analysis"
echo "════════════════════════════════════"

CRASHED=false

if grep -qE "FATAL EXCEPTION|fatal error|com\.jazzmax\.app.*died" logs/logcat_full.txt; then
    echo "❌ CRASH DETECTED in logcat!"
    grep -A 20 -E "FATAL EXCEPTION|fatal error" logs/logcat_full.txt \
        | head -50 > logs/crash_report.txt || true
    cat logs/crash_report.txt
    CRASHED=true
else
    echo "✅ No crashes detected"
fi

if grep -qE "FlutterError|Another exception was thrown" logs/logcat_full.txt; then
    echo "⚠  Flutter widget errors found:"
    grep -A 5 -E "FlutterError|Another exception was thrown" logs/logcat_full.txt \
        | head -40 >> logs/crash_report.txt 2>/dev/null || true
fi

# JazzMAX-specific log filter
grep -E "JazzMAX|flutter|com\.jazzmax" logs/logcat_full.txt \
    > logs/jazzmax_logs.txt 2>/dev/null || true

# ── Network / API connectivity ────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════"
echo "  Network / API Connectivity"
echo "════════════════════════════════════"

if grep -qE "api/catalog|api/auth|jazzmax" logs/logcat_full.txt; then
    echo "✅ App made API calls — network is working"
else
    echo "⚠  No API calls detected — app may not have reached the network"
fi

# ── Final result ──────────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════"
echo "  Test Result"
echo "════════════════════════════════════"

if [ "$CRASHED" = "true" ]; then
    echo "❌ RESULT: CRASH DETECTED — check logs/crash_report.txt"
    exit 1
else
    echo "✅ RESULT: App launched and ran without crashes"
fi
