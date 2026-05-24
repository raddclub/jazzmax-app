"""Firebase Cloud Messaging push notifications.

FCM server key stored in the Radd Hub keys vault under provider name 'fcm',
or in settings table as 'fcm_server_key'.

Admin: Settings → API Keys → FCM → paste the server key from
       Firebase Console → Project Settings → Cloud Messaging → Server key
"""
from __future__ import annotations
import json
import logging
import urllib.request
import urllib.error
from hub import db

log = logging.getLogger("hub.fcm")

PLAN_LABELS = {
    "basic":    "Basic",
    "standard": "Standard",
    "premium":  "Premium",
    "free":     "Free",
}

# ── Key lookup ──────────────────────────────────────────────────────────────────

def _server_key() -> str | None:
    try:
        from hub import keys
        k = keys.get("fcm")
        if k and len(k) > 20:
            return k.strip()
    except Exception:
        pass
    try:
        with db.conn() as c:
            row = c.execute("SELECT v FROM settings WHERE k='fcm_server_key'").fetchone()
            if row and row["v"] and len(row["v"]) > 20:
                return row["v"].strip()
    except Exception:
        pass
    return None

# ── Core send ──────────────────────────────────────────────────────────────────

def send_push(token: str, title: str, body: str,
              data: dict | None = None) -> bool:
    """Send FCM push notification. Returns True on success.

    Uses FCM Legacy HTTP API (still operational as of 2026).
    Server key must be set in admin Settings → API Keys → FCM.
    """
    if not token or not token.strip():
        return False
    key = _server_key()
    if not key:
        log.info("FCM: no server key configured — skipping push")
        return False

    payload = json.dumps({
        "to": token,
        "notification": {
            "title":              title,
            "body":               body,
            "sound":              "default",
            "android_channel_id": "jazzmax_alerts",
            "click_action":       "FLUTTER_NOTIFICATION_CLICK",
        },
        "data":     data or {},
        "priority": "high",
        "android": {
            "priority": "HIGH",
            "notification": {
                "channel_id":             "jazzmax_alerts",
                "notification_priority":  "PRIORITY_HIGH",
                "default_sound":          True,
            },
        },
        "apns": {
            "payload": {
                "aps": {
                    "alert": {"title": title, "body": body},
                    "sound": "default",
                    "badge": 1,
                }
            }
        },
    }).encode()

    try:
        req = urllib.request.Request(
            "https://fcm.googleapis.com/fcm/send",
            data=payload,
            headers={
                "Authorization": f"key={key}",
                "Content-Type":  "application/json",
            },
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            result = json.loads(r.read())
        if result.get("success", 0) > 0:
            log.info("FCM sent ok: token=%.12s title=%r", token, title)
            return True
        err = result.get("results", [{}])[0].get("error", "unknown")
        log.warning("FCM send failed: token=%.12s error=%s", token, err)
        # If token invalid/unregistered → clear it from DB
        if err in ("NotRegistered", "InvalidRegistration"):
            _clear_token_by_value(token)
        return False
    except urllib.error.HTTPError as e:
        log.warning("FCM HTTP %d: %s", e.code, e.read()[:200])
        return False
    except Exception as e:
        log.warning("FCM error: %s", e)
        return False

def _clear_token_by_value(token: str):
    try:
        with db.conn() as c:
            c.execute(
                "UPDATE app_users SET fcm_token=NULL, fcm_updated_at=NULL "
                "WHERE fcm_token=?", (token,)
            )
    except Exception:
        pass

# ── User helpers ───────────────────────────────────────────────────────────────

def get_token(user_id: int) -> str | None:
    try:
        with db.conn() as c:
            row = c.execute(
                "SELECT fcm_token FROM app_users WHERE id=?", (user_id,)
            ).fetchone()
            return row["fcm_token"] if row and row["fcm_token"] else None
    except Exception:
        return None

def save_token(user_id: int, token: str):
    try:
        import time
        with db.conn() as c:
            c.execute(
                "UPDATE app_users SET fcm_token=?, fcm_updated_at=? WHERE id=?",
                (token.strip(), int(time.time()), user_id)
            )
    except Exception as e:
        log.warning("save_token: %s", e)

# ── Notification templates ─────────────────────────────────────────────────────

def notify_subscription_activated(user_id: int, plan: str):
    token = get_token(user_id)
    if not token:
        return
    label = PLAN_LABELS.get(plan, plan.title())
    send_push(
        token,
        title="Subscription Activated!",
        body=f"Your JazzMAX {label} plan is now active. Enjoy unlimited streaming!",
        data={"event": "subscription_activated", "plan": plan},
    )

def notify_subscription_rejected(user_id: int, note: str = ""):
    token = get_token(user_id)
    if not token:
        return
    body = note.strip() or "Your payment could not be verified. Please contact support on WhatsApp."
    send_push(
        token,
        title="Payment Verification Failed",
        body=body,
        data={"event": "payment_rejected"},
    )

def notify_broadcast(title: str, body: str, tokens: list[str], data: dict | None = None):
    """Send to a list of device tokens (admin broadcast feature).
    Batches into groups of 1000 (FCM limit).
    """
    key = _server_key()
    if not key:
        log.info("FCM broadcast: no key configured")
        return 0

    success = 0
    batch_size = 1000
    for i in range(0, len(tokens), batch_size):
        batch = tokens[i:i + batch_size]
        payload = json.dumps({
            "registration_ids": batch,
            "notification": {
                "title": title, "body": body,
                "sound": "default",
                "android_channel_id": "jazzmax_alerts",
            },
            "data":     data or {},
            "priority": "high",
        }).encode()
        try:
            req = urllib.request.Request(
                "https://fcm.googleapis.com/fcm/send",
                data=payload,
                headers={"Authorization": f"key={key}", "Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=30) as r:
                result = json.loads(r.read())
                success += result.get("success", 0)
        except Exception as e:
            log.warning("FCM broadcast batch %d error: %s", i, e)
    log.info("FCM broadcast sent: total=%d success=%d", len(tokens), success)
    return success
