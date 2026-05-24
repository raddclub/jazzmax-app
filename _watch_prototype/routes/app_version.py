"""JazzMAX App Version Enforcement & APK Integrity.

Endpoints:
  POST /api/app/check   — called by Flutter on EVERY cold start
                          sends: version_code, version_name, sig_hash, device_id
                          returns: force_update, reason, update_url, message

Middleware (registered in run.py):
  before_request hook — checks X-App-Version-Code header on every /api/ call
  If version < min_version → 426 Upgrade Required
  If sig_hash in blocklist → 403 Forbidden (cracked APK)

How to crack-protect:
  1. Build release APK → get signing cert SHA-256 fingerprint
  2. Admin Panel → Settings → App Version → paste fingerprint → Save
  3. Enable 'Signature Check' toggle
  4. Any re-signed (cracked) APK will fail with 403

How forced update works:
  1. Admin Panel → Settings → App Version → set min_version_code (e.g. 5)
  2. All users with version_code < 5 get force_update=true on next API call
  3. Flutter shows un-dismissable dialog: 'Update Now' → Play Store
  4. OR set force_update_at timestamp: everyone must update by that date

"""
from __future__ import annotations
import time
import logging
from flask import Blueprint, request, jsonify, g
from hub import db
from .security import check_ip_rate_limit, audit, clean

log = logging.getLogger("hub.app_version")

bp = Blueprint("app_version", __name__, url_prefix="/api/app")


# ── Settings helpers ───────────────────────────────────────────────────────────

def _setting(k: str, default: str = "") -> str:
    try:
        with db.conn() as c:
            r = c.execute("SELECT v FROM settings WHERE k=?", (k,)).fetchone()
            return r["v"] if r and r["v"] is not None else default
    except Exception:
        return default

def _setting_int(k: str, default: int = 0) -> int:
    try:
        return int(_setting(k, str(default)))
    except (ValueError, TypeError):
        return default

def _setting_bool(k: str, default: bool = False) -> bool:
    v = _setting(k, "1" if default else "0")
    return v.strip() in ("1", "true", "yes", "on")


# ── Signature check helpers ────────────────────────────────────────────────────

def _is_sig_blocked(sig_hash: str) -> bool:
    """True if this APK signature is explicitly blocked (known crack)."""
    if not sig_hash:
        return False
    try:
        with db.conn() as c:
            r = c.execute(
                "SELECT is_allowed FROM app_signatures WHERE sig_hash=?",
                (sig_hash.upper(),)
            ).fetchone()
            if r is not None:
                return r["is_allowed"] == 0   # 0 = blocked
    except Exception:
        pass
    return False

def _is_sig_allowed(sig_hash: str) -> bool:
    """True if this APK signature is in the whitelist (official build).
    If whitelist is empty, any non-blocked sig is OK.
    """
    if not sig_hash:
        return not _setting_bool("app_check_signature")
    sig_upper = sig_hash.upper()
    try:
        with db.conn() as c:
            total = c.execute(
                "SELECT COUNT(*) AS n FROM app_signatures WHERE is_allowed=1"
            ).fetchone()["n"]
            if total == 0:
                # No whitelist configured — only check blocklist
                return not _is_sig_blocked(sig_hash)
            row = c.execute(
                "SELECT id FROM app_signatures WHERE sig_hash=? AND is_allowed=1",
                (sig_upper,)
            ).fetchone()
            return row is not None
    except Exception:
        return True   # fail open if DB error — don't break legit users


# ── Version comparison ─────────────────────────────────────────────────────────

def _needs_force_update(version_code: int) -> tuple[bool, str]:
    """Returns (force_update, reason_string)."""
    min_code = _setting_int("app_min_version_code", 1)
    if version_code < min_code:
        current_name = _setting("app_current_version", "")
        msg = f"Please update JazzMAX to version {current_name} to continue." if current_name else "A required update is available. Please update to continue."
        return True, msg

    # Check deadline-based forced update
    deadline = _setting_int("app_force_update_at", 0)
    if deadline and int(time.time()) >= deadline:
        msg = "A mandatory update is required. Please update JazzMAX to the latest version."
        return True, msg

    return False, ""


# ── /api/app/check endpoint ────────────────────────────────────────────────────

@bp.route("/check", methods=["POST"])
def app_check():
    """Called by Flutter on every cold start.

    Request body (JSON):
      version_code  : int    — build number (e.g. 5)
      version_name  : str    — display name (e.g. "1.2.0")
      sig_hash      : str    — SHA-256 of APK signing cert, hex, no colons
                               (e.g. "A1B2C3D4...")
      device_id     : str    — optional, for logging
      platform      : str    — "android" | "ios"

    Response:
      ok            : bool
      force_update  : bool   — show un-dismissable update dialog
      blocked       : bool   — cracked/tampered APK detected
      message       : str    — shown in the dialog
      update_url    : str    — Play Store / App Store link
      server_time   : int    — unix timestamp (for clock sync)
      current_version: str  — latest published version name
    """
    # Light rate limit
    if check_ip_rate_limit("app_check", max_req=30, window=60):
        return jsonify({"error": "too many requests"}), 429

    data         = request.get_json(silent=True) or {}
    version_code = int(data.get("version_code") or 0)
    version_name = clean(str(data.get("version_name") or ""), 20)
    sig_hash     = clean(str(data.get("sig_hash")     or ""), 128).upper().replace(":", "").replace(" ", "")
    device_id    = clean(str(data.get("device_id")    or ""), 128)
    platform     = clean(str(data.get("platform")     or "android"), 16).lower()

    ip           = request.headers.get("X-Real-IP") or request.remote_addr or ""
    update_url   = _setting("app_update_url", "https://play.google.com/store/apps/details?id=pk.jazzmax.app")
    current_ver  = _setting("app_current_version", "")

    # ── 1. Check if APK is tampered / cracked ─────────────────────────────────
    if _setting_bool("app_block_on_tamper") and sig_hash:
        if _is_sig_blocked(sig_hash):
            log.warning("CRACKED APK blocked: sig=%.16s ip=%s device=%s", sig_hash, ip, device_id[:20])
            audit("cracked_apk", success=False,
                  detail=f"sig={sig_hash[:16]} ver={version_code} ip={ip}")
            crack_msg = _setting(
                "app_crack_message",
                "This version of JazzMAX is not authorized. Please download the official app."
            )
            return jsonify({
                "ok":           False,
                "force_update": True,
                "blocked":      True,
                "message":      crack_msg,
                "update_url":   update_url,
                "server_time":  int(time.time()),
            }), 403

        if _setting_bool("app_check_signature") and sig_hash and not _is_sig_allowed(sig_hash):
            log.warning("Unknown APK signature: sig=%.16s ip=%s ver=%d", sig_hash, ip, version_code)
            audit("unknown_sig", success=False,
                  detail=f"sig={sig_hash[:16]} ver={version_code}")
            crack_msg = _setting(
                "app_crack_message",
                "This version of JazzMAX is not authorized. Please download the official app."
            )
            return jsonify({
                "ok":           False,
                "force_update": True,
                "blocked":      True,
                "message":      crack_msg,
                "update_url":   update_url,
                "server_time":  int(time.time()),
            }), 403

    # ── 2. Check if version needs forced update ────────────────────────────────
    force_update, update_msg = _needs_force_update(version_code)

    # ── 3. Log app check (rate-throttled — only log meaningful events) ─────────
    if force_update or version_code < _setting_int("app_min_version_code", 1) + 5:
        audit("app_check",
              detail=f"ver={version_code} sig={sig_hash[:8] if sig_hash else 'none'} force={force_update}")

    return jsonify({
        "ok":              True,
        "force_update":    force_update,
        "blocked":         False,
        "message":         update_msg,
        "update_url":      update_url,
        "server_time":     int(time.time()),
        "current_version": current_ver,
        "min_version_code": _setting_int("app_min_version_code", 1),
    })


# ── Middleware: per-request version gate ──────────────────────────────────────

def version_gate_middleware():
    """before_request hook registered in run.py.

    Checks X-App-Version-Code and X-App-Sig headers on every /api/ request.
    Fails fast with 426 or 403 before any business logic runs.
    
    This is a second layer of defense — the primary check is /api/app/check
    called on startup. This catches requests made directly to the API
    (bypassing the app startup check).
    """
    path = request.path

    # Only apply to Flutter API endpoints (not admin panel)
    if not path.startswith("/api/"):
        return None
    # Skip the check endpoint itself (avoid infinite loop)
    if path == "/api/app/check":
        return None

    version_code_hdr = request.headers.get("X-App-Version-Code", "").strip()
    sig_hdr          = request.headers.get("X-App-Sig", "").strip().upper().replace(":", "")

    # ── Signature check (if enabled and sig provided) ──────────────────────────
    if sig_hdr and _setting_bool("app_block_on_tamper"):
        if _is_sig_blocked(sig_hdr):
            crack_msg = _setting("app_crack_message", "Unauthorized app version.")
            return jsonify({
                "error":       "blocked",
                "message":     crack_msg,
                "force_update": True,
                "update_url":  _setting("app_update_url", ""),
            }), 403
        if _setting_bool("app_check_signature") and sig_hdr and not _is_sig_allowed(sig_hdr):
            crack_msg = _setting("app_crack_message", "Unauthorized app version.")
            return jsonify({
                "error":       "blocked",
                "message":     crack_msg,
                "force_update": True,
                "update_url":  _setting("app_update_url", ""),
            }), 403

    # ── Version check (if version header provided) ─────────────────────────────
    if version_code_hdr:
        try:
            vc = int(version_code_hdr)
        except ValueError:
            return None   # malformed header — let it through, /check will catch
        force_update, _ = _needs_force_update(vc)
        if force_update:
            return jsonify({
                "error":           "update_required",
                "force_update":    True,
                "message":         "A required update is available. Please update JazzMAX.",
                "update_url":      _setting("app_update_url", ""),
                "current_version": _setting("app_current_version", ""),
                "code":            "FORCE_UPDATE",
            }), 426   # 426 Upgrade Required

    return None   # proceed normally
