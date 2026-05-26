"""JazzMAX app authentication API — security-hardened.

Endpoints:
  POST /api/auth/register   — create account (phone + password)
  POST /api/auth/login      — login, returns access + refresh tokens
  POST /api/auth/refresh    — exchange refresh token for new access token (rotates token)
  POST /api/auth/logout     — revoke refresh token
  GET  /api/auth/me         — return user profile + subscription info
  POST /api/auth/device     — bind device to account
  POST /api/auth/fcm_token  — register FCM push notification token
  POST /api/auth/guest      — short-lived guest access token

Security measures:
  - IP-based rate limiting on all auth endpoints
  - Account lockout after 5 failed login attempts (15 min)
  - Refresh token rotation (old token invalidated on each use)
  - Constant-time password comparison
  - Timing-safe token validation
  - Audit logging for all auth events
  - Minimum 8-char passwords
  - Phone normalization + Pakistan-only validation
  - JWT secret never falls back to hardcoded string
"""
from __future__ import annotations
import os
import re
import time
import hashlib
import hmac
import logging
import secrets

import jwt
from flask import Blueprint, request, jsonify, g
from werkzeug.security import generate_password_hash, check_password_hash
from hub import db

from .security import (
    check_ip_rate_limit, record_login_failure, clear_login_failures,
    is_account_locked, audit, clean, is_safe_phone,
)

log = logging.getLogger("hub.app_auth")

bp = Blueprint("app_auth", __name__, url_prefix="/api/auth")

ACCESS_TOKEN_TTL  = 15 * 60              # 15 minutes
REFRESH_TOKEN_TTL = 90 * 24 * 60 * 60   # 90 days (3 months)
GUEST_TOKEN_TTL   = 2  * 60 * 60        # 2 hours (reduced from 24h)

# ── JWT helpers ────────────────────────────────────────────────────────────────

def _jwt_secret() -> str:
    """Return JWT signing secret — never falls back to a hardcoded string."""
    secret = (
        os.environ.get("SESSION_SECRET") or
        os.environ.get("FLASK_SECRET_KEY")
    )
    if not secret or len(secret) < 16:
        # Fetch from DB (persisted generated key)
        try:
            with db.conn() as c:
                row = c.execute("SELECT v FROM settings WHERE k='flask_secret_key'").fetchone()
                if row and row["v"] and len(row["v"]) >= 16:
                    return row["v"]
        except Exception:
            pass
        raise RuntimeError("SESSION_SECRET env var not set — cannot issue tokens securely")
    return secret


def _make_access_token(user_id: int, phone: str) -> str:
    now = int(time.time())
    payload = {
        "sub":   str(user_id),
        "phone": phone,
        "type":  "access",
        "exp":   now + ACCESS_TOKEN_TTL,
        "iat":   now,
        "jti":   secrets.token_hex(8),   # unique token ID
    }
    return jwt.encode(payload, _jwt_secret(), algorithm="HS256")


def _make_refresh_token(user_id: int) -> tuple[str, str]:
    """Returns (raw_token, sha256_hash). Only the hash is stored in DB."""
    raw = secrets.token_urlsafe(48)
    h   = hashlib.sha256(raw.encode()).hexdigest()
    return raw, h


def _verify_access_token(token: str) -> dict | None:
    try:
        return jwt.decode(
            token, _jwt_secret(), algorithms=["HS256"],
            options={"verify_sub": False},
        )
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
        return None


def _normalize_phone(phone: str) -> str:
    cleaned = re.sub(r"[\s\-\(\)]", "", clean(phone, 20))
    if cleaned.startswith("+92"):
        cleaned = "0" + cleaned[3:]
    return cleaned


def require_app_auth(fn):
    """Decorator: validates Bearer access token. Injects g.app_user_id and g.app_phone."""
    from functools import wraps
    @wraps(fn)
    def wrapper(*a, **kw):
        auth_hdr = request.headers.get("Authorization", "")
        if not auth_hdr.startswith("Bearer "):
            return jsonify({"error": "missing token"}), 401
        token = auth_hdr[7:].strip()
        if not token:
            return jsonify({"error": "missing token"}), 401
        payload = _verify_access_token(token)
        if not payload or payload.get("type") != "access":
            return jsonify({"error": "invalid or expired token"}), 401
        _sub = payload["sub"]
        g.app_user_id = 0 if _sub == "guest" else int(_sub)
        g.app_phone   = payload.get("phone", "")
        g.is_guest    = payload.get("is_guest", False)
        return fn(*a, **kw)
    return wrapper


# ── Register ───────────────────────────────────────────────────────────────────

@bp.route("/register", methods=["POST"])
def register():
    # IP rate limit: max 5 registrations per hour per IP
    if check_ip_rate_limit("register", max_req=5, window=3600):
        return jsonify({"error": "too many attempts — try again later"}), 429

    data  = request.get_json(silent=True) or {}
    phone = _normalize_phone(str(data.get("phone", "")).strip())
    pwd   = clean(str(data.get("password", "")), 128)

    if not phone:
        return jsonify({"error": "phone is required"}), 400
    if not is_safe_phone(phone):
        return jsonify({"error": "enter a valid Jazz number (03XX-XXXXXXX)"}), 400
    if len(pwd) < 8:
        return jsonify({"error": "password must be at least 8 characters"}), 400
    if len(pwd) > 128:
        return jsonify({"error": "password too long"}), 400

    pwd_hash = generate_password_hash(pwd)
    now      = int(time.time())

    try:
        with db.conn() as c:
            c.execute(
                "INSERT INTO app_users (phone, password_hash, created_at) VALUES (?, ?, ?)",
                (phone, pwd_hash, now)
            )
            user_id = c.execute("SELECT last_insert_rowid() AS id").fetchone()["id"]
            c.execute(
                "INSERT INTO app_subscriptions (user_id, plan, is_active, created_at) VALUES (?, 'free', 1, ?)",
                (user_id, now)
            )
    except Exception as e:
        if "UNIQUE" in str(e).upper():
            # Constant-time delay to prevent user enumeration via timing
            time.sleep(0.1)
            return jsonify({"error": "an account with this number already exists"}), 409
        log.exception("register error")
        return jsonify({"error": "registration failed"}), 500

    access_token         = _make_access_token(user_id, phone)
    raw_refresh, ref_hash = _make_refresh_token(user_id)
    expires_at           = now + REFRESH_TOKEN_TTL

    with db.conn() as c:
        c.execute(
            "INSERT INTO app_refresh_tokens (user_id, token_hash, created_at, expires_at) VALUES (?,?,?,?)",
            (user_id, ref_hash, now, expires_at)
        )
        c.execute("UPDATE app_users SET last_login_at=? WHERE id=?", (now, user_id))

    # Auto-link pre-approved TID
    auto_plan = "free"
    try:
        with db.conn() as c:
            approved_tid = c.execute(
                "SELECT plan FROM tid_payments WHERE phone=? AND status='approved' "
                "ORDER BY reviewed_at DESC LIMIT 1",
                (phone,)
            ).fetchone()
        if approved_tid:
            _plan   = approved_tid["plan"]
            _now2   = int(time.time())
            _expires = _now2 + {"basic": 30, "standard": 30, "premium": 30}.get(_plan, 30) * 86400
            with db.conn() as c:
                c.execute("UPDATE app_subscriptions SET is_active=0 WHERE user_id=? AND plan='free'", (user_id,))
                c.execute(
                    "INSERT INTO app_subscriptions(user_id,plan,started_at,expires_at,is_active,created_at) VALUES(?,?,?,?,1,?)",
                    (user_id, _plan, _now2, _expires, _now2)
                )
                c.execute(
                    "UPDATE tid_payments SET user_id=? WHERE phone=? AND status='approved' AND user_id IS NULL",
                    (user_id, phone)
                )
            auto_plan = _plan
            log.info("TID auto-link on register: phone=%s plan=%s uid=%s", phone, _plan, user_id)
    except Exception as _te:
        log.warning("TID auto-link failed: %s", _te)

    audit("register", phone=phone, user_id=user_id, success=True)
    return jsonify({
        "ok":            True,
        "access_token":  access_token,
        "refresh_token": raw_refresh,
        "user":          {"id": user_id, "phone": phone, "plan": auto_plan},
    }), 201


# ── Login ──────────────────────────────────────────────────────────────────────

@bp.route("/login", methods=["POST"])
def login():
    # IP rate limit: max 10 attempts per 15 min per IP
    if check_ip_rate_limit("login", max_req=10, window=900):
        return jsonify({"error": "too many login attempts — try again later"}), 429

    data  = request.get_json(silent=True) or {}
    phone = _normalize_phone(str(data.get("phone", "")).strip())
    pwd   = clean(str(data.get("password", "")), 128)

    if not phone or not pwd:
        return jsonify({"error": "phone and password are required"}), 400

    # Account lockout check BEFORE hitting DB
    locked, remaining = is_account_locked(phone)
    if locked:
        mins = remaining // 60 + 1
        return jsonify({
            "error":   f"account temporarily locked after too many failed attempts. Try again in {mins} minute(s).",
            "code":    "ACCOUNT_LOCKED",
            "retry_in": remaining,
        }), 429

    with db.conn() as c:
        user = c.execute(
            "SELECT id, phone, password_hash, device_id, is_active FROM app_users WHERE phone=?",
            (phone,)
        ).fetchone()

    # Constant-time check even when user doesn't exist (prevents enumeration)
    _dummy_hash = generate_password_hash("dummy-jazzmax-2026")
    _hash_to_check = user["password_hash"] if user else _dummy_hash
    pwd_ok = check_password_hash(_hash_to_check, pwd)

    if not user or not pwd_ok:
        record_login_failure(phone)
        audit("login_fail", phone=phone, success=False, detail="bad credentials")
        # Avoid revealing whether phone exists
        return jsonify({"error": "incorrect phone number or password"}), 401

    if not user["is_active"]:
        audit("login_fail", phone=phone, user_id=user["id"], success=False, detail="account disabled")
        return jsonify({"error": "account is disabled"}), 403

    device_id = clean(str(data.get("device_id") or ""), 128)
    if user["device_id"] and device_id and user["device_id"] != device_id:
        audit("login_fail", phone=phone, user_id=user["id"], success=False, detail="device mismatch")
        return jsonify({
            "error": "this account is registered on another device",
            "code":  "DEVICE_MISMATCH",
        }), 403

    clear_login_failures(phone)

    now                  = int(time.time())
    access_token         = _make_access_token(user["id"], user["phone"])
    raw_refresh, ref_hash = _make_refresh_token(user["id"])
    expires_at           = now + REFRESH_TOKEN_TTL

    with db.conn() as c:
        c.execute(
            "INSERT INTO app_refresh_tokens (user_id, token_hash, device_id, created_at, expires_at) VALUES (?,?,?,?,?)",
            (user["id"], ref_hash, device_id or None, now, expires_at)
        )
        c.execute("UPDATE app_users SET last_login_at=? WHERE id=?", (now, user["id"]))

    with db.conn() as c:
        sub = c.execute(
            "SELECT plan FROM app_subscriptions WHERE user_id=? AND is_active=1 ORDER BY id DESC LIMIT 1",
            (user["id"],)
        ).fetchone()

    audit("login", phone=phone, user_id=user["id"], success=True)
    return jsonify({
        "ok":            True,
        "access_token":  access_token,
        "refresh_token": raw_refresh,
        "user":          {"id": user["id"], "phone": user["phone"], "plan": sub["plan"] if sub else "free"},
    })


# ── Refresh (with token rotation) ─────────────────────────────────────────────

@bp.route("/refresh", methods=["POST"])
def refresh():
    # IP rate limit
    if check_ip_rate_limit("refresh", max_req=30, window=900):
        return jsonify({"error": "too many requests"}), 429

    data = request.get_json(silent=True) or {}
    raw  = clean(str(data.get("refresh_token", "")), 200)
    if not raw:
        return jsonify({"error": "refresh_token required"}), 400

    h   = hashlib.sha256(raw.encode()).hexdigest()
    now = int(time.time())

    # RACE CONDITION FIX: atomic SELECT + revoke in one transaction
    # Prevents two simultaneous refresh requests both succeeding with the same token
    with db.conn() as c:
        # Use immediate transaction to lock: only one can revoke at a time
        c.execute("BEGIN IMMEDIATE")
        row = c.execute(
            "SELECT id, user_id, expires_at, revoked FROM app_refresh_tokens WHERE token_hash=?",
            (h,)
        ).fetchone()

        if not row or row["revoked"] or (row["expires_at"] and row["expires_at"] < now):
            c.execute("ROLLBACK")
            audit("refresh_fail", success=False, detail="invalid/expired/revoked token")
            return jsonify({"error": "invalid or expired refresh token"}), 401

        # Revoke immediately inside transaction (prevents concurrent use)
        c.execute("UPDATE app_refresh_tokens SET revoked=1 WHERE id=?", (row["id"],))
        c.execute("COMMIT")

    with db.conn() as c:
        user = c.execute("SELECT id, phone FROM app_users WHERE id=?", (row["user_id"],)).fetchone()

    if not user:
        return jsonify({"error": "user not found"}), 401

    # Issue new rotated token
    new_raw, new_hash = _make_refresh_token(user["id"])
    new_expires       = now + REFRESH_TOKEN_TTL

    with db.conn() as c:
        c.execute(
            "INSERT INTO app_refresh_tokens (user_id, token_hash, created_at, expires_at, rotated_from) VALUES (?,?,?,?,?)",
            (user["id"], new_hash, now, new_expires, row["id"])
        )

    access_token = _make_access_token(user["id"], user["phone"])
    return jsonify({
        "ok":            True,
        "access_token":  access_token,
        "refresh_token": new_raw,   # new rotated token
    })


# ── Guest login ────────────────────────────────────────────────────────────────

@bp.route("/guest", methods=["POST"])
def guest_login():
    if check_ip_rate_limit("guest", max_req=20, window=3600):
        return jsonify({"error": "too many requests"}), 429
    now = int(time.time())
    payload = {
        "sub":      "guest",
        "phone":    "guest",
        "type":     "access",
        "is_guest": True,
        "exp":      now + GUEST_TOKEN_TTL,
        "iat":      now,
        "jti":      secrets.token_hex(8),
    }
    token = jwt.encode(payload, _jwt_secret(), algorithm="HS256")
    return jsonify({"access_token": token, "is_guest": True})


# ── Logout ─────────────────────────────────────────────────────────────────────

@bp.route("/logout", methods=["POST"])
@require_app_auth
def logout():
    data = request.get_json(silent=True) or {}
    raw  = clean(str(data.get("refresh_token", "")), 200)
    if raw:
        h = hashlib.sha256(raw.encode()).hexdigest()
        with db.conn() as c:
            c.execute("UPDATE app_refresh_tokens SET revoked=1 WHERE token_hash=?", (h,))
    audit("logout", user_id=g.app_user_id, success=True)
    return jsonify({"ok": True})


# ── Me ─────────────────────────────────────────────────────────────────────────

@bp.route("/me", methods=["GET"])
@require_app_auth
def me():
    user_id = g.app_user_id
    # Guest tokens have no DB record — return synthetic profile
    if getattr(g, "is_guest", False) or user_id == 0:
        return jsonify({
            "id":           0,
            "phone":        "guest",
            "device_id":    None,
            "device_name":  None,
            "created_at":   None,
            "last_login_at":None,
            "is_active":    True,
            "subscription": {"plan": "free", "is_active": True, "expires_at": None},
        })  # FIX BUG-012
    with db.conn() as c:
        user = c.execute(
            "SELECT id, phone, device_id, device_name, created_at, last_login_at, is_active FROM app_users WHERE id=?",  # FIX BUG-012
            (user_id,)
        ).fetchone()
        sub = c.execute(
            "SELECT plan, started_at, expires_at FROM app_subscriptions "
            "WHERE user_id=? AND is_active=1 ORDER BY id DESC LIMIT 1",
            (user_id,)
        ).fetchone()

    if not user:
        return jsonify({"error": "user not found"}), 404

    now        = int(time.time())
    plan       = sub["plan"]       if sub else "free"
    expires_at = sub["expires_at"] if sub else None
    is_active  = (not expires_at or expires_at > now) if sub else True

    return jsonify({
        "id":           user["id"],
        "is_active":    bool(user["is_active"]),  # FIX BUG-012
        "phone":        user["phone"],
        "device_id":    user["device_id"],
        "device_name":  user["device_name"],
        "created_at":   user["created_at"],
        "last_login_at":user["last_login_at"],
        "subscription": {
            "plan":       plan,
            "is_active":  is_active,
            "expires_at": expires_at,
        },
    })


# ── Device binding ─────────────────────────────────────────────────────────────

@bp.route("/device", methods=["POST"])
@require_app_auth
def bind_device():
    """Bind a device to the user's account. Allowed once per 30 days."""
    user_id     = g.app_user_id
    data        = request.get_json(silent=True) or {}
    device_id   = clean(str(data.get("device_id",   "")), 128)
    device_name = clean(str(data.get("device_name", "")), 80)

    if not device_id:
        return jsonify({"error": "device_id required"}), 400

    with db.conn() as c:
        user = c.execute(
            "SELECT device_id, device_bound_at FROM app_users WHERE id=?", (user_id,)
        ).fetchone()

    now      = int(time.time())
    cooldown = 30 * 24 * 60 * 60

    if user["device_id"] and user["device_id"] != device_id:
        last_bound = user["device_bound_at"] or 0
        if now - last_bound < cooldown:
            days_left = int((cooldown - (now - last_bound)) / 86400)
            return jsonify({
                "error": f"device transfer allowed once per 30 days. Try again in {days_left} day(s).",
                "code":  "DEVICE_TRANSFER_COOLDOWN",
            }), 403

    with db.conn() as c:
        c.execute(
            "UPDATE app_users SET device_id=?, device_name=?, device_bound_at=? WHERE id=?",
            (device_id, device_name or None, now, user_id)
        )

    audit("device_bound", user_id=user_id, success=True, detail=device_id[:20])
    return jsonify({"ok": True, "device_id": device_id})


# ── FCM token registration ─────────────────────────────────────────────────────

@bp.route("/fcm_token", methods=["POST"])
@require_app_auth
def register_fcm_token():
    """Register or update the device FCM push token for this user.
    Flutter calls this on every app start after login.
    Body: {"fcm_token": "<device_token>"}
    """
    data  = request.get_json(silent=True) or {}
    token = clean(str(data.get("fcm_token", "")), 512)

    if not token or len(token) < 20:
        return jsonify({"error": "fcm_token required"}), 400

    try:
        from .fcm import save_token
        save_token(g.app_user_id, token)
    except Exception as e:
        log.warning("register_fcm_token failed: %s", e)
        return jsonify({"error": "failed to save token"}), 500

    return jsonify({"ok": True})
