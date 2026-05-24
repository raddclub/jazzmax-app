"""SMS Payment Gateway — receives parsed payment SMS from admin's phone.

Routes:
  POST /api/subscription/sms-payment   — receive parsed SMS from admin app
  GET  /api/subscription/sms-payments  — list received SMS (admin key required)
"""
from __future__ import annotations
import time, re, logging, os
from flask import Blueprint, request, jsonify
from hub import db

log = logging.getLogger("hub.sms_gateway")

sms_bp = Blueprint("sms_gateway", __name__, url_prefix="/api/subscription")

# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #

def _get_gateway_key() -> str:
    """Return the SMS gateway secret key, creating one if not set."""
    with db.conn() as c:
        row = c.execute("SELECT v FROM settings WHERE k='sms_gateway_key'").fetchone()
        if row:
            return row["v"]
        # Generate and store a new key
        import secrets
        key = secrets.token_hex(24)
        c.execute("INSERT OR REPLACE INTO settings(k,v) VALUES('sms_gateway_key',?)", (key,))
        log.info("Generated new SMS gateway key")
        return key



def _get_sms_watch_numbers() -> list[str]:
    """Return list of SMS sender numbers to watch for payments.
    Configurable via admin Settings -> sms_watch_numbers.
    Defaults include Jazz and Easypaisa gateway numbers.
    """
    import json as _json
    default = ["8558", "3737", "786", "JAZZCASH", "EASYPAISA", "NAYAPAY", "SADAPAY"]
    try:
        with db.conn() as c:
            row = c.execute("SELECT v FROM settings WHERE k='sms_watch_numbers'").fetchone()
            if row and row["v"]:
                parsed = _json.loads(row["v"])
                if isinstance(parsed, list) and parsed:
                    return [str(n).strip() for n in parsed if n]
    except Exception:
        pass
    return default

def _get_tolerance() -> float:
    """Return the configured amount tolerance in PKR."""
    try:
        with db.conn() as c:
            row = c.execute("SELECT v FROM settings WHERE k='sms_amount_tolerance_pkr'").fetchone()
            return float(row['v']) if row else 10.0
    except Exception:
        return 10.0


def _get_plan_price(plan: str) -> float | None:
    """Return the expected price for a plan from the plans table."""
    try:
        with db.conn() as c:
            row = c.execute(
                "SELECT price_pkr FROM plans WHERE LOWER(name)=LOWER(?) AND is_active=1",
                (plan,)
            ).fetchone()
            return float(row['price_pkr']) if row else None
    except Exception:
        return None


def _auto_approve(tid: str, sms_id: int) -> dict | None:
    """Check if a pending tid_payment matches this SMS TID and auto-approve it.
    
    Validates that the SMS amount matches the plan price (within tolerance)
    before approving. Mismatches are logged and flagged for manual review.
    """
    # Check if auto-approve is enabled
    try:
        with db.conn() as c:
            aa_row = c.execute("SELECT v FROM settings WHERE k='sms_auto_approve_enabled'").fetchone()
            if aa_row and aa_row['v'] == '0':
                log.info('SMS auto-approve disabled globally, skipping TID=%s', tid)
                return None
    except Exception:
        pass

    now = int(time.time())
    
    # Get the SMS record to check amount
    with db.conn() as c:
        sms_row = c.execute("SELECT amount_pkr FROM received_sms_payments WHERE id=?", (sms_id,)).fetchone()
        sms_amount = float(sms_row['amount_pkr']) if sms_row and sms_row['amount_pkr'] else None

    with db.conn() as c:
        payment = c.execute(
            "SELECT * FROM tid_payments WHERE tid=? AND status='pending'", (tid,)
        ).fetchone()
        if not payment:
            return None

        plan          = payment['plan']
        user_id       = payment['user_id']
        phone         = payment['phone']
        payment_id    = payment['id']
        expected_amount = float(payment['amount_pkr']) if payment['amount_pkr'] else None

        # ── AMOUNT VALIDATION ─────────────────────────────────────────────────
        tolerance = _get_tolerance()
        plan_price = _get_plan_price(plan)
        
        # Check 1: SMS amount vs plan price
        if sms_amount is not None and plan_price is not None:
            diff = abs(sms_amount - plan_price)
            if diff > tolerance:
                log.warning(
                    'SMS amount mismatch: TID=%s SMS=%.0f plan_price=%.0f diff=%.0f tolerance=%.0f — flagged for manual review',
                    tid, sms_amount, plan_price, diff, tolerance
                )
                # Mark as amount_mismatch so admin can see it
                c.execute(
                    "UPDATE tid_payments SET admin_note=?, status='pending' WHERE id=?",
                    (f'AMOUNT MISMATCH: received ₨{sms_amount:.0f}, expected ₨{plan_price:.0f} (diff ₨{diff:.0f})', payment_id)
                )
                c.execute(
                    "UPDATE received_sms_payments SET matched_payment_id=? WHERE id=?",
                    (payment_id, sms_id)
                )
                return None  # Do NOT auto-approve — requires manual review
        
        # Check 2: SMS amount vs user-submitted amount
        if sms_amount is not None and expected_amount is not None:
            diff2 = abs(sms_amount - expected_amount)
            if diff2 > tolerance:
                log.warning(
                    'SMS/TID amount mismatch: TID=%s SMS=%.0f submitted=%.0f diff=%.0f — flagged',
                    tid, sms_amount, expected_amount, diff2
                )
                c.execute(
                    "UPDATE tid_payments SET admin_note=? WHERE id=?",
                    (f'AMOUNT MISMATCH: SMS received ₨{sms_amount:.0f}, user submitted ₨{expected_amount:.0f}', payment_id)
                )
                c.execute(
                    "UPDATE received_sms_payments SET matched_payment_id=? WHERE id=?",
                    (payment_id, sms_id)
                )
                return None
        # ─────────────────────────────────────────────────────────────────────

        PLAN_DAYS = {'basic': 30, 'standard': 30, 'premium': 30}
        duration = PLAN_DAYS.get(plan, 30)
        # Use actual plan duration if available
        if plan_price is not None:
            try:
                with db.conn() as c2:
                    prow = c2.execute("SELECT duration_days FROM plans WHERE LOWER(name)=LOWER(?)", (plan,)).fetchone()
                    if prow:
                        duration = prow['duration_days']
            except Exception:
                pass
        expires = now + duration * 86400

        # If no user_id, try to find by phone
        if not user_id and phone:
            row = c.execute('SELECT id FROM app_users WHERE phone=?', (phone,)).fetchone()
            if row:
                user_id = row['id']
                c.execute('UPDATE tid_payments SET user_id=? WHERE id=?', (user_id, payment_id))

        # Approve the payment
        c.execute(
            "UPDATE tid_payments SET status='approved', admin_note='Auto-approved via SMS gateway', reviewed_at=? WHERE id=?",
            (now, payment_id)
        )

        if user_id:
            c.execute('UPDATE app_subscriptions SET is_active=0 WHERE user_id=?', (user_id,))
            c.execute(
                'INSERT INTO app_subscriptions(user_id,plan,started_at,expires_at,is_active,created_at) VALUES(?,?,?,?,1,?)',
                (user_id, plan, now, expires, now)
            )
            log.info('SMS auto-approved TID=%s user=%s plan=%s amount=%.0f expires=%s',
                     tid, user_id, plan, sms_amount or 0, expires)
        else:
            log.warning('SMS auto-approved TID=%s but no user found for phone=%s', tid, phone)

        # Link SMS record to this payment
        c.execute(
            'UPDATE received_sms_payments SET matched_payment_id=? WHERE id=?',
            (payment_id, sms_id)
        )

        return {
            'payment_id': payment_id,
            'user_id':    user_id,
            'plan':       plan,
            'expires_at': expires,
        }

@sms_bp.route("/sms-payment", methods=["POST"])
def receive_sms():
    """Admin's phone POSTs here when a JazzCash/EasyPaisa SMS arrives."""
    key = request.headers.get("X-Gateway-Key", "")
    if key != _get_gateway_key():
        return jsonify({"error": "unauthorized"}), 401

    data   = request.get_json(silent=True) or {}
    source = str(data.get("source", "")).lower()
    tid    = str(data.get("tid", "")).strip().upper()
    amount = data.get("amount_pkr")
    sender = str(data.get("sender_phone", "")).strip()
    raw    = str(data.get("raw_sms", "")).strip()

    if source not in ("jazzcash", "easypaisa"):
        return jsonify({"error": "source must be jazzcash or easypaisa"}), 400
    if not tid:
        return jsonify({"error": "tid required"}), 400

    now = int(time.time())

    # Idempotent — ignore duplicate TIDs
    with db.conn() as c:
        existing = c.execute(
            "SELECT id, matched_payment_id FROM received_sms_payments WHERE tid=?", (tid,)
        ).fetchone()

    if existing:
        return jsonify({
            "ok":      True,
            "message": "already received",
            "tid":     tid,
            "already_approved": existing["matched_payment_id"] is not None,
        })

    # Store the SMS
    with db.conn() as c:
        cur = c.execute(
            """INSERT INTO received_sms_payments(source,tid,amount_pkr,sender_phone,raw_sms,received_at)
               VALUES(?,?,?,?,?,?)""",
            (source, tid, amount, sender, raw, now)
        )
        sms_id = cur.lastrowid

    log.info("Received SMS payment: source=%s tid=%s amount=%s", source, tid, amount)

    # Try immediate auto-approve
    result = _auto_approve(tid, sms_id)
    if result:
        return jsonify({
            "ok":           True,
            "tid":          tid,
            "auto_approved": True,
            "plan":         result["plan"],
            "user_id":      result["user_id"],
        })

    return jsonify({
        "ok":           True,
        "tid":          tid,
        "auto_approved": False,
        "message":      "stored, will auto-approve when user submits this TID",
    }), 201


@sms_bp.route("/sms-payments")
def list_sms():
    """Admin endpoint to see received SMS payments."""
    key = request.headers.get("X-Gateway-Key", "")
    if key != _get_gateway_key():
        return jsonify({"error": "unauthorized"}), 401

    with db.conn() as c:
        rows = c.execute(
            "SELECT * FROM received_sms_payments ORDER BY received_at DESC LIMIT 100"
        ).fetchall()

    return jsonify({"payments": [dict(r) for r in rows]})




@sms_bp.route("/sms-watch-numbers", methods=["GET", "POST"])
def sms_watch_numbers():
    """GET/POST the list of SMS sender numbers to watch for payments.
    GET: returns current numbers.
    POST (admin key required): updates numbers.
    Body: {"numbers": ["8558", "3737", "JAZZCASH"]}
    """
    if request.method == "GET":
        return jsonify({"numbers": _get_sms_watch_numbers()})

    key = request.headers.get("X-Gateway-Key", "")
    if key != _get_gateway_key():
        return jsonify({"error": "unauthorized"}), 401

    data = request.get_json(silent=True) or {}
    numbers = data.get("numbers")
    if not isinstance(numbers, list):
        return jsonify({"error": "numbers must be a JSON array"}), 400

    import json as _json
    with db.conn() as c:
        c.execute("INSERT OR REPLACE INTO settings(k,v) VALUES(?,?)",
                  ("sms_watch_numbers", _json.dumps(numbers)))
    log.info("Updated sms_watch_numbers: %s", numbers)
    return jsonify({"ok": True, "numbers": numbers})

@sms_bp.route("/gateway-key")
def gateway_key_info():
    """Returns the gateway key (admin session required)."""
    from hub.auth import is_logged_in
    # Simple admin check via session
    from flask import session
    if not session.get("logged_in"):
        return jsonify({"error": "admin login required"}), 401
    return jsonify({"key": _get_gateway_key()})

