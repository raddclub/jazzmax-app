"""
Logs into JazzDrive web app, performs a file move, and prints the raw
SAPI request (URL + method + POST body) so we can implement move_video().

Run:
    python3 radd-hub/scripts/capture_move_api.py [OTP]
"""
import sys, json, time
from playwright.sync_api import sync_playwright

PHONE  = "03029688227"
BASE   = "https://cloud.jazzdrive.com.pk"
OTP    = sys.argv[1] if len(sys.argv) > 1 else None

captured = []

def on_request(req):
    if "sapi" in req.url:
        try:
            body = req.post_data or ""
        except Exception:
            body = ""
        captured.append({
            "method": req.method,
            "url":    req.url,
            "body":   body,
        })

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    ctx     = browser.new_context(viewport={"width":1280,"height":800})
    page    = ctx.new_page()
    page.on("request", on_request)

    # ── 1. Load site ──────────────────────────────────────────────────────────
    print(">> Navigating to JazzDrive…")
    page.goto(BASE, wait_until="networkidle", timeout=30000)
    page.screenshot(path="/tmp/jd_step1.png")
    print("   title:", page.title())

    # ── 2. Find phone input ───────────────────────────────────────────────────
    # Try common selectors for the login form
    phone_sel = None
    for sel in ['input[type="tel"]', 'input[name="username"]',
                'input[name="phone"]', 'input[placeholder*="number" i]',
                'input[placeholder*="phone" i]', 'input[placeholder*="mobile" i]',
                'input[type="text"]']:
        if page.locator(sel).count() > 0:
            phone_sel = sel
            break

    if not phone_sel:
        print("ERR: Could not find phone input")
        print("HTML snippet:", page.content()[:3000])
        browser.close()
        sys.exit(1)

    print(f"   Found phone input: {phone_sel}")
    page.fill(phone_sel, PHONE)

    # Submit (look for a button)
    for btn_sel in ['button[type="submit"]', 'button:has-text("Login")',
                    'button:has-text("Send")', 'button:has-text("Next")',
                    'button:has-text("Continue")', 'input[type="submit"]']:
        if page.locator(btn_sel).count() > 0:
            page.click(btn_sel)
            break

    page.wait_for_timeout(3000)
    page.screenshot(path="/tmp/jd_step2.png")
    print("   After phone submit — title:", page.title())

    # ── 3. OTP step ───────────────────────────────────────────────────────────
    otp_sel = None
    for sel in ['input[name="otp"]', 'input[placeholder*="otp" i]',
                'input[placeholder*="code" i]', 'input[type="number"]',
                'input[maxlength="6"]', 'input[maxlength="4"]']:
        if page.locator(sel).count() > 0:
            otp_sel = sel
            break

    if otp_sel:
        if not OTP:
            print("OTP_REQUIRED")   # sentinel read by the wrapper
            browser.close()
            sys.exit(2)
        print(f"   Entering OTP into {otp_sel}…")
        page.fill(otp_sel, OTP)
        for btn_sel in ['button[type="submit"]','button:has-text("Verify")',
                        'button:has-text("Login")', 'input[type="submit"]']:
            if page.locator(btn_sel).count() > 0:
                page.click(btn_sel)
                break
        page.wait_for_timeout(3000)
        page.screenshot(path="/tmp/jd_step3.png")
        print("   After OTP — title:", page.title())

    # ── 4. Wait for file list to load ─────────────────────────────────────────
    print(">> Waiting for file manager to load…")
    page.wait_for_timeout(5000)
    page.screenshot(path="/tmp/jd_step4.png")
    print("   title:", page.title())
    print("   url:  ", page.url)

    # Print all SAPI calls seen so far (login calls)
    print("\n=== SAPI calls captured during login ===")
    for c in captured:
        print(f"  {c['method']} {c['url']}")
        if c['body']:
            print(f"    body: {c['body'][:300]}")
    print("========================================\n")

    # ── 5. Try to find files and drag one to a folder ─────────────────────────
    # Reset capture for the move operation
    captured.clear()

    # Look for draggable file items
    file_items = []
    for sel in ['.file-item', '.media-item', '[draggable="true"]',
                '.list-item', '.grid-item', 'tr.file', '.file-row']:
        cnt = page.locator(sel).count()
        if cnt >= 2:
            file_items = sel
            print(f"   Found {cnt} file items with selector: {sel}")
            break

    if file_items:
        # Drag first file onto second item (hoping it's a folder)
        src  = page.locator(file_items).nth(0)
        dest = page.locator(file_items).nth(1)
        src.drag_to(dest)
        page.wait_for_timeout(3000)
        page.screenshot(path="/tmp/jd_step5.png")
    else:
        print("   Could not find draggable file items — dumping page HTML for analysis")
        with open("/tmp/jd_page.html", "w") as f:
            f.write(page.content())
        print("   HTML saved to /tmp/jd_page.html")

    # ── 6. Print captured SAPI calls ─────────────────────────────────────────
    print("\n=== SAPI calls captured after move attempt ===")
    for c in captured:
        print(f"  {c['method']} {c['url']}")
        if c['body']:
            print(f"    body: {c['body'][:500]}")
    print("==============================================")

    browser.close()
