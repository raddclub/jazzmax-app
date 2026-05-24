"""Flutter API — Plans & Payment Methods public endpoints."""
from __future__ import annotations
import json, logging
from flask import Blueprint, jsonify
from hub import db

log = logging.getLogger("hub.app_plans")
bp = Blueprint("app_plans", __name__, url_prefix="/api")


@bp.route("/plans")
def get_plans():
    """Return all active subscription plans for the Flutter app."""
    with db.conn() as c:
        rows = c.execute(
            "SELECT id, name, price_pkr, duration_days, max_devices, monthly_limit_gb, "
            "description, badge, color, features_json, is_active "
            "FROM plans WHERE is_active=1 ORDER BY price_pkr ASC"
        ).fetchall()
    result = []
    for p in rows:
        d = dict(p)
        try:
            d["features"] = json.loads(p["features_json"] or "[]")
        except Exception:
            d["features"] = []
        d.pop("features_json", None)
        d["price_display"] = f"₨{int(p['price_pkr']):,}"
        d["duration_display"] = f"{p['duration_days']} days"
        result.append(d)
    return jsonify({"ok": True, "plans": result})


@bp.route("/payment-methods")
def get_payment_methods():
    """Return enabled payment methods with account details for Flutter app."""
    with db.conn() as c:
        rows = c.execute(
            "SELECT code, name, account_number, account_name, instructions, icon, min_amount_pkr "
            "FROM payment_methods WHERE is_enabled=1 ORDER BY sort_order ASC"
        ).fetchall()
    return jsonify({"ok": True, "methods": [dict(r) for r in rows]})


@bp.route("/subscription/status/<int:user_id>")
def subscription_status(user_id: int):
    """Return current subscription status for a user."""
    import time
    now = int(time.time())
    with db.conn() as c:
        sub = c.execute(
            "SELECT s.plan, s.expires_at, s.is_active, p.name, p.max_devices, p.color "
            "FROM app_subscriptions s "
            "LEFT JOIN plans p ON LOWER(p.name)=s.plan "
            "WHERE s.user_id=? AND s.is_active=1 AND s.expires_at>? "
            "ORDER BY s.id DESC LIMIT 1",
            (user_id, now)
        ).fetchone()
        if not sub:
            return jsonify({"ok": True, "active": False, "plan": None})
        days_left = max(0, int((sub["expires_at"] - now) / 86400))
        return jsonify({
            "ok": True, "active": True,
            "plan": sub["plan"],
            "plan_name": sub["name"] or sub["plan"],
            "plan_color": sub["color"] or "#7c5cff",
            "max_devices": sub["max_devices"] or 1,
            "expires_at": sub["expires_at"],
            "days_left": days_left,
            "expires_display": f"{days_left} days remaining",
        })
