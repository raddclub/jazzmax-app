"""JazzMAX subscription & TID payment API.

Endpoints:
  GET  /api/subscription/plans       — list available plans + prices
  GET  /api/subscription/status      — current user's plan + expiry (auth required)
  POST /api/subscription/tid/submit  — user submits a TID payment request
  GET  /api/subscription/tid/status  — check if a TID payment was approved (auth required)
"""
from __future__ import annotations
import time
import logging
from flask import Blueprint, request, jsonify
from hub import db
from .app_auth import require_app_auth

log = logging.getLogger("hub.app_subscription")

bp = Blueprint("app_subscription", __name__, url_prefix="/api/subscription")

PLANS = [
    {
        "id":           "free",
        "name":         "Free",
        "price_pkr":    0,
        "duration_days": None,
        "quality":      "480p",
        "downloads":    False,
        "description":  "Watch free titles only",
    },
    {
        "id":            "basic",
        "name":          "Basic",
        "price_pkr":     149,
        "duration_days": 30,
        "quality":       "720p",
        "downloads":     True,
        "downloads_per_day": 5,
        "description":   "All movies & shows, 720p, 5 downloads/day",
    },
    {
        "id":            "standard",
        "name":          "Standard",
        "price_pkr":     299,
        "duration_days": 30,
        "quality":       "1080p",
        "downloads":     True,
        "downloads_per_day": 15,
        "description":   "All content, Full HD, 15 downloads/day",
    },
    {
        "id":            "premium",
        "name":          "Premium",
        "price_pkr":     499,
        "duration_days": 30,
        "quality":       "1080p",
        "downloads":     True,
        "downloads_per_day": None,  # unlimited
        "description":   "All content, Full HD, unlimited downloads",
    },
]

PLAN_IDS = {p["id"] for p in PLANS if p["id"] != "free"}

PAYMENT_NUMBER = {
    "jazzcash":   "03286839827",   # Muhammad Rehan
    "easypaisa":  "03286839827",   # Muhammad Rehan
}


@bp.route("/plans")
def plans():
    return jsonify({"plans": PLANS, "payment": PAYMENT_NUMBER})


@bp.route("/status")
@require_app_auth
def status():
    from flask import g
    user_id = g.app_user_id
    if getattr(g, "is_guest", False) or user_id == 0:
        return jsonify({"plan": "free", "is_active": True, "expires_at": None})
    now     = int(time.time())

    with db.conn() as c:
        sub = c.execute(
            "SELECT plan, started_at, expires_at, is_active FROM app_subscriptions "
            "WHERE user_id=? ORDER BY id DESC LIMIT 1",
            (user_id,)
        ).fetchone()

    if not sub:
        return jsonify({"plan": "free", "is_active": True, "expires_at": None})

    plan       = sub["plan"]
    expires_at = sub["expires_at"]
    is_active  = bool(sub["is_active"]) and (not expires_at or expires_at > now)

    if not is_active and plan != "free":
        plan = "free"

    return jsonify({
        "plan":       plan,
        "is_active":  is_active,
        "started_at": sub["started_at"],
        "expires_at": expires_at,
    })


@bp.route("/tid/submit", methods=["POST"])
def tid_submit():
    """User submits a TID payment. They must be registered (user_id optional for guest)."""
    data   = request.get_json(silent=True) or {}
    phone  = str(data.get("phone", "")).strip()
    tid    = str(data.get("tid", "")).strip().upper()
    plan   = str(data.get("plan", "")).strip().lower()
    method = str(data.get("payment_method", "jazzcash")).strip().lower()

    if not phone:
        return jsonify({"error": "phone number is required"}), 400
    if not tid:
        return jsonify({"error": "transaction ID (TID) is required"}), 400
    if plan not in PLAN_IDS:
        return jsonify({"error": f"invalid plan. Choose from: {', '.join(PLAN_IDS)}"}), 400
    if method not in PAYMENT_NUMBER:
        return jsonify({"error": "payment_method must be 'jazzcash' or 'easypaisa'"}), 400

    plan_info  = next(p for p in PLANS if p["id"] == plan)
    amount_pkr = plan_info["price_pkr"]

    # Look up user_id from phone (optional — payment can be submitted before login)
    user_id = None
    with db.conn() as c:
        user_row = c.execute("SELECT id FROM app_users WHERE phone=?", (phone,)).fetchone()
        if user_row:
            user_id = user_row["id"]

    # Check for duplicate TID
    with db.conn() as c:
        existing = c.execute(
            "SELECT id, status FROM tid_payments WHERE tid=?", (tid,)
        ).fetchone()

    if existing:
        if existing["status"] == "approved":
            return jsonify({"error": "this transaction ID has already been used"}), 409
        if existing["status"] == "pending":
            return jsonify({
                "ok": True,
                "message": "your payment is already submitted and being reviewed",
                "status": "pending",
            })

    now = int(time.time())
    with db.conn() as c:
        cur = c.execute(
            """INSERT INTO tid_payments
               (user_id, phone, amount_pkr, tid, payment_method, plan, status, submitted_at)
               VALUES (?,?,?,?,?,?,?,?)""",
            (user_id, phone, amount_pkr, tid, method, plan, "pending", now)
        )
        new_payment_id = cur.lastrowid


    # ── Auto-approve if SMS already received ────────────────────────────────
    with db.conn() as c:
        sms_row = c.execute(
            "SELECT id FROM received_sms_payments WHERE tid=? AND matched_payment_id IS NULL",
            (tid,)
        ).fetchone()

    if sms_row:
        # SMS is on file — auto-approve immediately
        _sms_auto_approve(tid, sms_row["id"], plan, user_id, phone, new_payment_id)
        return jsonify({
            "ok":     True,
            "status": "approved",
            "message": "payment verified! your subscription is now active.",
            "plan":   plan,
        }), 200
    # ────────────────────────────────────────────────────────────────────────

    return jsonify({
        "ok": True,
        "message": "payment submitted! your subscription will be activated within a few hours.",
        "status": "pending",
        "plan":   plan,
    }), 201


@bp.route("/tid/status")
@require_app_auth
def tid_status():
    """Check if user's TID payment was approved."""
    from flask import g
    user_id = g.app_user_id
    if getattr(g, 'is_guest', False) or user_id == 0:
        return jsonify({"payments": []})

    with db.conn() as c:
        rows = c.execute(
            "SELECT tid, plan, status, amount_pkr, payment_method, submitted_at, reviewed_at "
            "FROM tid_payments WHERE user_id=? ORDER BY submitted_at DESC LIMIT 5",
            (user_id,)
        ).fetchall()

    payments = [dict(r) for r in rows]
    return jsonify({"payments": payments})



@bp.route("/tid/check_by_phone")
def tid_check_by_phone():
    """Guest-accessible TID status check by phone — no auth required.
    Used by Flutter guests who submitted TID and poll for approval.
    Also auto-links subscription when the user later registers with same phone.
    """
    phone = request.args.get("phone", "").strip()
    if not phone:
        return jsonify({"error": "phone parameter required"}), 400

    with db.conn() as c:
        rows = c.execute(
            "SELECT tid, plan, status, amount_pkr, payment_method, submitted_at, reviewed_at "
            "FROM tid_payments WHERE phone=? ORDER BY submitted_at DESC LIMIT 5",
            (phone,)
        ).fetchall()

    payments = [dict(r) for r in rows]
    approved = next((p for p in payments if p["status"] == "approved"), None)

    # If approved TID exists but user just registered, link subscription now
    if approved:
        with db.conn() as c:
            user_row = c.execute(
                "SELECT id FROM app_users WHERE phone=?", (phone,)
            ).fetchone()
            if user_row:
                user_id = user_row["id"]
                existing = c.execute(
                    "SELECT id FROM app_subscriptions WHERE user_id=? AND is_active=1",
                    (user_id,)
                ).fetchone()
                if not existing:
                    plan = approved["plan"]
                    now = int(time.time())
                    expires = now + {"basic": 30, "standard": 30, "premium": 30}.get(plan, 30) * 86400
                    c.execute(
                        "INSERT INTO app_subscriptions"
                        "(user_id,plan,started_at,expires_at,is_active,created_at) "
                        "VALUES(?,?,?,?,1,?)",
                        (user_id, plan, now, expires, now)
                    )
                    log.info("Auto-linked pre-approved TID: phone=%s plan=%s uid=%s", phone, plan, user_id)

    return jsonify({
        "phone": phone,
        "payments": payments,
        "has_approved": approved is not None,
        "approved_plan": approved["plan"] if approved else None,
    })


def _sms_auto_approve(tid: str, sms_id: int, plan: str, user_id, phone: str, payment_id: int):
    """Immediately approve a TID that was verified by SMS gateway."""
    import time as _time
    now = int(_time.time())
    PLAN_DAYS = {"basic": 30, "standard": 30, "premium": 30}
    duration  = PLAN_DAYS.get(plan, 30)
    expires   = now + duration * 86400

    if not user_id and phone:
        with db.conn() as c:
            row = c.execute("SELECT id FROM app_users WHERE phone=?", (phone,)).fetchone()
            if row:
                user_id = row["id"]
                c.execute("UPDATE tid_payments SET user_id=? WHERE id=?", (user_id, payment_id))

    with db.conn() as c:
        c.execute(
            "UPDATE tid_payments SET status='approved', admin_note='Auto-approved via SMS gateway', reviewed_at=? WHERE id=?",
            (now, payment_id)
        )
        if user_id:
            c.execute("UPDATE app_subscriptions SET is_active=0 WHERE user_id=?", (user_id,))
            c.execute(
                "INSERT INTO app_subscriptions(user_id,plan,started_at,expires_at,is_active,created_at) VALUES(?,?,?,?,1,?)",
                (user_id, plan, now, expires, now)
            )
        c.execute(
            "UPDATE received_sms_payments SET matched_payment_id=? WHERE id=?",
            (payment_id, sms_id)
        )
    log.info("SMS auto-approved TID=%s user=%s plan=%s", tid, user_id, plan)

