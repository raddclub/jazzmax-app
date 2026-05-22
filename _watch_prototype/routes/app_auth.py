"""JazzMAX app authentication API.

Endpoints:
  POST /api/auth/register   — create account (phone + password)
  POST /api/auth/login      — login, returns access + refresh tokens
  POST /api/auth/refresh    — exchange refresh token for new access token
  POST /api/auth/logout     — revoke refresh token
  GET  /api/auth/me         — return user profile + subscription info
  POST /api/auth/device     — bind device to account (called after first login)
"""
from __future__ import annotations
import os
import re
import time
import hashlib
import logging
import secrets

import jwt
from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from hub import db

log = logging.getLogger("hub.app_auth")

bp = Blueprint("app_auth", __name__, url_prefix="/api/auth")

ACCESS_TOKEN_TTL  = 15 * 60          # 15 minutes
REFRESH_TOKEN_TTL = 30 * 24 * 60 * 60  # 30 days

def _jwt_secret() -> str:
    return os.environ.get("SESSION_SECRET") or os.environ.get("FLASK_SECRET_KEY") or "jazzmax-dev-secret"

def _make_access_token(user_id: int, phone: str) -> str:
    payload = {
        "sub": str(user_id),   # PyJWT v2 requires sub to be a string
        "phone": phone,
        "type": "access",
        "exp": int(time.time()) + ACCESS_TOKEN_TTL,
        "iat": int(time.time()),
    }
    return jwt.encode(payload, _jwt_secret(), algorithm="HS256")

def _make_refresh_token(user_id: int) -> tuple[str, str]:
    """Returns (raw_token, token_hash). Store only the hash."""
    raw = secrets.token_urlsafe(48)
    h   = hashlib.sha256(raw.encode()).hexdigest()
    return raw, h

def _verify_access_token(token: str) -> dict | None:
    try:
        payload = jwt.decode(
            token, _jwt_secret(), algorithms=["HS256"],
            options={"verify_sub": False},  # sub is a string-encoded int
        )
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

def _phone_valid(phone: str) -> bool:
    cleaned = re.sub(r"[\s\-]", "", phone)
    return bool(re.match(r"^(03\d{9}|\+923\d{9})$", cleaned))

def _normalize_phone(phone: str) -> str:
    cleaned = re.sub(r"[\s\-]", "", phone)
    if cleaned.startswith("+92"):
        cleaned = "0" + cleaned[3:]
    return cleaned


def require_app_auth(fn):
    """Decorator: validates Bearer access token and injects g.app_user_id."""
    from functools import wraps
    from flask import g
    @wraps(fn)
    def wrapper(*a, **kw):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "missing token"}), 401
        token = auth_header[7:]
        payload = _verify_access_token(token)
        if not payload or payload.get("type") != "access":
            return jsonify({"error": "invalid or expired token"}), 401
        g.app_user_id = int(payload["sub"])
        g.app_phone   = payload.get("phone", "")
        return fn(*a, **kw)
    return wrapper


@bp.route("/register", methods=["POST"])
def register():
    data  = request.get_json(silent=True) or {}
    phone = _normalize_phone(str(data.get("phone", "")).strip())
    pwd   = str(data.get("password", "")).strip()

    if not phone:
        return jsonify({"error": "phone is required"}), 400
    if not _phone_valid(phone):
        return jsonify({"error": "enter a valid Jazz number (03XX-XXXXXXX)"}), 400
    if len(pwd) < 6:
        return jsonify({"error": "password must be at least 6 characters"}), 400

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

    return jsonify({
        "ok": True,
        "access_token":  access_token,
        "refresh_token": raw_refresh,
        "user": {"id": user_id, "phone": phone, "plan": "free"},
    }), 201


@bp.route("/login", methods=["POST"])
def login():
    data  = request.get_json(silent=True) or {}
    phone = _normalize_phone(str(data.get("phone", "")).strip())
    pwd   = str(data.get("password", "")).strip()

    if not phone or not pwd:
        return jsonify({"error": "phone and password are required"}), 400

    with db.conn() as c:
        user = c.execute(
            "SELECT id, phone, password_hash, device_id, is_active FROM app_users WHERE phone=?",
            (phone,)
        ).fetchone()

    if not user or not check_password_hash(user["password_hash"], pwd):
        return jsonify({"error": "incorrect phone number or password"}), 401

    if not user["is_active"]:
        return jsonify({"error": "account is disabled"}), 403

    device_id = str(data.get("device_id") or "").strip()
    if user["device_id"] and device_id and user["device_id"] != device_id:
        return jsonify({
            "error": "this account is registered on another device",
            "code": "DEVICE_MISMATCH"
        }), 403

    now                   = int(time.time())
    access_token          = _make_access_token(user["id"], user["phone"])
    raw_refresh, ref_hash = _make_refresh_token(user["id"])
    expires_at            = now + REFRESH_TOKEN_TTL

    with db.conn() as c:
        c.execute(
            "INSERT INTO app_refresh_tokens (user_id, token_hash, device_id, created_at, expires_at) VALUES (?,?,?,?,?)",
            (user["id"], ref_hash, device_id or None, now, expires_at)
        )
        c.execute("UPDATE app_users SET last_login_at=? WHERE id=?", (now, user["id"]))

    with db.conn() as c:
        sub = c.execute(
            "SELECT plan, expires_at FROM app_subscriptions WHERE user_id=? AND is_active=1 ORDER BY id DESC LIMIT 1",
            (user["id"],)
        ).fetchone()

    plan = sub["plan"] if sub else "free"

    return jsonify({
        "ok": True,
        "access_token":  access_token,
        "refresh_token": raw_refresh,
        "user": {"id": user["id"], "phone": user["phone"], "plan": plan},
    })


@bp.route("/refresh", methods=["POST"])
def refresh():
    data  = request.get_json(silent=True) or {}
    raw   = str(data.get("refresh_token", "")).strip()
    if not raw:
        return jsonify({"error": "refresh_token required"}), 400

    h   = hashlib.sha256(raw.encode()).hexdigest()
    now = int(time.time())

    with db.conn() as c:
        row = c.execute(
            "SELECT id, user_id, expires_at, revoked FROM app_refresh_tokens WHERE token_hash=?",
            (h,)
        ).fetchone()

    if not row or row["revoked"] or (row["expires_at"] and row["expires_at"] < now):
        return jsonify({"error": "invalid or expired refresh token"}), 401

    with db.conn() as c:
        user = c.execute("SELECT id, phone FROM app_users WHERE id=?", (row["user_id"],)).fetchone()

    if not user:
        return jsonify({"error": "user not found"}), 401

    access_token = _make_access_token(user["id"], user["phone"])
    return jsonify({"ok": True, "access_token": access_token})


@bp.route("/logout", methods=["POST"])
@require_app_auth
def logout():
    data = request.get_json(silent=True) or {}
    raw  = str(data.get("refresh_token", "")).strip()
    if raw:
        h = hashlib.sha256(raw.encode()).hexdigest()
        with db.conn() as c:
            c.execute("UPDATE app_refresh_tokens SET revoked=1 WHERE token_hash=?", (h,))
    return jsonify({"ok": True})


@bp.route("/me", methods=["GET"])
@require_app_auth
def me():
    from flask import g
    user_id = g.app_user_id

    with db.conn() as c:
        user = c.execute(
            "SELECT id, phone, device_id, device_name, created_at, last_login_at FROM app_users WHERE id=?",
            (user_id,)
        ).fetchone()
        sub = c.execute(
            "SELECT plan, started_at, expires_at FROM app_subscriptions "
            "WHERE user_id=? AND is_active=1 ORDER BY id DESC LIMIT 1",
            (user_id,)
        ).fetchone()

    if not user:
        return jsonify({"error": "user not found"}), 404

    now = int(time.time())
    plan        = sub["plan"]       if sub else "free"
    expires_at  = sub["expires_at"] if sub else None
    is_active   = (not expires_at or expires_at > now) if sub else True  # free plan never expires

    return jsonify({
        "id":           user["id"],
        "phone":        user["phone"],
        "device_id":    user["device_id"],
        "device_name":  user["device_name"],
        "created_at":   user["created_at"],
        "last_login_at":user["last_login_at"],
        "subscription": {
            "plan":       plan,
            "is_active":  is_active,
            "expires_at": expires_at,
        }
    })


@bp.route("/device", methods=["POST"])
@require_app_auth
def bind_device():
    """Bind a device to the user's account.  Can only be done once per 30 days."""
    from flask import g
    user_id   = g.app_user_id
    data      = request.get_json(silent=True) or {}
    device_id = str(data.get("device_id", "")).strip()
    device_name = str(data.get("device_name", "")).strip()[:80]

    if not device_id:
        return jsonify({"error": "device_id required"}), 400

    with db.conn() as c:
        user = c.execute(
            "SELECT device_id, device_bound_at FROM app_users WHERE id=?", (user_id,)
        ).fetchone()

    now = int(time.time())
    cooldown = 30 * 24 * 60 * 60  # 30 days

    if user["device_id"] and user["device_id"] != device_id:
        last_bound = user["device_bound_at"] or 0
        if now - last_bound < cooldown:
            days_left = int((cooldown - (now - last_bound)) / 86400)
            return jsonify({
                "error": f"device transfer allowed once per 30 days. Try again in {days_left} day(s).",
                "code": "DEVICE_TRANSFER_COOLDOWN",
            }), 403

    with db.conn() as c:
        c.execute(
            "UPDATE app_users SET device_id=?, device_name=?, device_bound_at=? WHERE id=?",
            (device_id, device_name or None, now, user_id)
        )

    return jsonify({"ok": True, "device_id": device_id})
