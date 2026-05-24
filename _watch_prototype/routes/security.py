"""JazzMAX Security Middleware — rate limiting, lockout, headers, sanitization.

All imports are standard-library only (no extra deps needed).
"""
from __future__ import annotations
import re
import time
import threading
import logging
from flask import request, jsonify

log = logging.getLogger("hub.security")

# ── IP-based rate limiter (in-memory, thread-safe) ─────────────────────────────
_ip_store: dict[str, list[float]] = {}
_ip_lock  = threading.Lock()

def _trim(ts_list: list[float], window: int) -> list[float]:
    cutoff = time.time() - window
    return [t for t in ts_list if t > cutoff]

def check_ip_rate_limit(action: str, max_req: int = 10, window: int = 900) -> bool:
    """Return True (blocked) if IP exceeded max_req in window seconds.
    action: short label, e.g. 'login', 'register', 'refresh'.
    """
    ip  = (request.headers.get("X-Real-IP") or request.remote_addr or "unknown")[:45]
    key = f"{action}:{ip}"
    with _ip_lock:
        ts = _trim(_ip_store.get(key, []), window)
        if len(ts) >= max_req:
            _ip_store[key] = ts
            log.warning("IP rate-limit: action=%s ip=%s count=%d", action, ip, len(ts))
            return True
        ts.append(time.time())
        _ip_store[key] = ts
    return False


# ── Account-level lockout (in-memory; also persisted to DB) ────────────────────
_acct_fail: dict[str, list[float]] = {}
_acct_lock = threading.Lock()

MAX_FAILURES    = 5
FAIL_WINDOW     = 15 * 60   # track failures within 15 min
LOCKOUT_SECONDS = 15 * 60   # lockout for 15 min after MAX_FAILURES

def record_login_failure(phone: str):
    """Increment in-memory failure counter and persist to DB."""
    _inc_memory(phone)
    try:
        from hub import db
        now = int(time.time())
        with db.conn() as c:
            c.execute(
                "INSERT INTO login_lockouts(phone,fail_count,last_fail) VALUES(?,1,?) "
                "ON CONFLICT(phone) DO UPDATE SET "
                "  fail_count=fail_count+1, last_fail=? "
                "WHERE locked_until IS NULL OR locked_until < ?",
                (phone, now, now, now)
            )
            row = c.execute(
                "SELECT fail_count FROM login_lockouts WHERE phone=?", (phone,)
            ).fetchone()
            if row and row["fail_count"] >= MAX_FAILURES:
                c.execute(
                    "UPDATE login_lockouts SET locked_until=? WHERE phone=?",
                    (now + LOCKOUT_SECONDS, phone)
                )
    except Exception as _e:
        log.debug("record_login_failure db: %s", _e)

def _inc_memory(phone: str):
    with _acct_lock:
        ts = _trim(_acct_fail.get(phone, []), FAIL_WINDOW)
        ts.append(time.time())
        _acct_fail[phone] = ts

def clear_login_failures(phone: str):
    """Clear failures on successful login."""
    with _acct_lock:
        _acct_fail.pop(phone, None)
    try:
        from hub import db
        with db.conn() as c:
            c.execute("DELETE FROM login_lockouts WHERE phone=?", (phone,))
    except Exception:
        pass

def is_account_locked(phone: str) -> tuple[bool, int]:
    """Returns (is_locked, seconds_remaining_until_unlock)."""
    # Check DB first (survives restarts)
    try:
        from hub import db
        now = int(time.time())
        with db.conn() as c:
            row = c.execute(
                "SELECT locked_until FROM login_lockouts WHERE phone=?", (phone,)
            ).fetchone()
        if row and row["locked_until"] and row["locked_until"] > now:
            return True, row["locked_until"] - now
        if row and row["locked_until"] and row["locked_until"] <= now:
            # Expired — clear
            with db.conn() as c:
                c.execute("DELETE FROM login_lockouts WHERE phone=?", (phone,))
            return False, 0
    except Exception as _e:
        log.debug("is_account_locked db: %s", _e)
    # Fall back to memory check
    with _acct_lock:
        ts = _trim(_acct_fail.get(phone, []), FAIL_WINDOW)
        _acct_fail[phone] = ts
        if len(ts) >= MAX_FAILURES:
            oldest = min(ts)
            unlock = oldest + LOCKOUT_SECONDS
            remaining = max(0, int(unlock - time.time()))
            if remaining > 0:
                return True, remaining
            else:
                _acct_fail.pop(phone, None)
    return False, 0


# ── Audit logger ───────────────────────────────────────────────────────────────

def audit(action: str, phone: str = None, user_id: int = None,
          success: bool = False, detail: str = None):
    """Write an auth event to auth_audit_log."""
    try:
        from hub import db
        ip = (request.headers.get("X-Real-IP") or request.remote_addr or "")[:45]
        with db.conn() as c:
            c.execute(
                "INSERT INTO auth_audit_log(action,phone,user_id,ip,success,detail) "
                "VALUES(?,?,?,?,?,?)",
                (action, phone, user_id, ip, 1 if success else 0, detail)
            )
    except Exception as _e:
        log.debug("audit log failed: %s", _e)


# ── Security response headers ───────────────────────────────────────────────────

SECURITY_HEADERS = {
    "X-Frame-Options":           "DENY",
    "X-Content-Type-Options":    "nosniff",
    "X-XSS-Protection":          "1; mode=block",
    "Referrer-Policy":           "strict-origin-when-cross-origin",
    "Permissions-Policy":        "camera=(), microphone=(), geolocation=()",
    "Cache-Control":             "no-store",  # for auth endpoints
}

def add_security_headers(response):
    for k, v in SECURITY_HEADERS.items():
        response.headers.setdefault(k, v)
    response.headers.pop("Server", None)
    return response


# ── Input sanitization ──────────────────────────────────────────────────────────

def clean(s, max_len=512):
    """Strip null bytes and truncate."""
    if not isinstance(s, str):
        s = str(s)
    return s.replace("\x00", "").strip()[:max_len]

PHONE_RE = re.compile(r'^(03\d{9}|\+923\d{9})$')

def is_safe_phone(phone: str) -> bool:
    return bool(PHONE_RE.match(phone))
