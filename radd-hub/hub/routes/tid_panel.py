"""TID Payment Verification Panel — admin UI in Radd Hub.

Routes:
  GET  /tid/              — list pending + recent TID payments
  POST /tid/<id>/approve  — approve payment, activate subscription
  POST /tid/<id>/reject   — reject payment with optional note
"""
from __future__ import annotations
import time
import logging
from flask import Blueprint, render_template_string, request, redirect, url_for, jsonify
from hub import db
from hub.auth import login_required

log = logging.getLogger("hub.tid_panel")

bp = Blueprint("tid_panel", __name__, url_prefix="/tid")

PLAN_DURATIONS = {
    "basic":    30,
    "standard": 30,
    "premium":  30,
}

_HTML = """
{% extends "base.html" %}
{% block title %}TID Payments{% endblock %}
{% block content %}
<style>
.tid-page { max-width: 960px; margin: 0 auto; padding: 24px 16px; }
.tid-page h1 { font-size: 1.4rem; margin-bottom: 4px; color: #e7eaf2; }
.tid-page .sub { color: #7e859b; font-size: .85rem; margin-bottom: 24px; }
.tabs { display: flex; gap: 8px; margin-bottom: 20px; }
.tab-btn {
  padding: 6px 16px; border-radius: 8px; border: 1px solid #252d3d;
  background: #12151e; color: #7e859b; cursor: pointer; font-size: .85rem;
  text-decoration: none;
}
.tab-btn.active { background: #E8002D; color: #fff; border-color: #E8002D; }
.card {
  background: #12151e; border: 1px solid #252d3d; border-radius: 12px;
  padding: 16px 20px; margin-bottom: 12px;
}
.card-top { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
.badge {
  padding: 3px 10px; border-radius: 20px; font-size: .75rem; font-weight: 600;
}
.badge-pending  { background: rgba(255,193,7,.15);  color: #ffc107; }
.badge-approved { background: rgba(0,230,118,.15);  color: #00e676; }
.badge-rejected { background: rgba(255,107,107,.15); color: #ff6b6b; }
.plan-tag {
  padding: 3px 10px; border-radius: 20px; font-size: .75rem; font-weight: 700;
  background: rgba(232,0,45,.15); color: #E8002D;
}
.card-meta { font-size: .82rem; color: #7e859b; margin-top: 8px; }
.card-meta span { margin-right: 18px; }
.tid-val { font-family: monospace; font-size: .95rem; color: #e7eaf2; font-weight: 600; }
.actions { display: flex; gap: 8px; margin-top: 12px; }
.btn-approve {
  padding: 7px 18px; background: #00e676; color: #000; border: none;
  border-radius: 8px; font-weight: 700; cursor: pointer; font-size: .85rem;
}
.btn-reject {
  padding: 7px 18px; background: transparent; color: #ff6b6b;
  border: 1px solid #ff6b6b; border-radius: 8px; cursor: pointer; font-size: .85rem;
}
.note-input {
  margin-top: 8px; width: 100%; padding: 8px 10px;
  background: #181d28; border: 1px solid #252d3d; color: #e7eaf2;
  border-radius: 8px; font-size: .85rem;
}
.empty { text-align: center; color: #7e859b; padding: 40px; font-size: .9rem; }
.amount { font-size: 1.1rem; font-weight: 700; color: #00e676; }
</style>

<div class="tid-page">
  <h1>💳 TID Payment Verification</h1>
  <p class="sub">Manually verify JazzCash / Easypaisa Transaction IDs and activate subscriptions.</p>

  <div class="tabs">
    <a href="?tab=pending"  class="tab-btn {% if tab=='pending' %}active{% endif %}">
      Pending {% if pending_count %}<span style="background:#E8002D;border-radius:10px;padding:1px 7px;font-size:.75rem;margin-left:4px">{{ pending_count }}</span>{% endif %}
    </a>
    <a href="?tab=approved" class="tab-btn {% if tab=='approved' %}active{% endif %}">Approved</a>
    <a href="?tab=rejected" class="tab-btn {% if tab=='rejected' %}active{% endif %}">Rejected</a>
    <a href="?tab=all"      class="tab-btn {% if tab=='all' %}active{% endif %}">All</a>
  </div>

  {% if not payments %}
    <div class="empty">No {{ tab }} payments found.</div>
  {% endif %}

  {% for p in payments %}
  <div class="card">
    <div class="card-top">
      <span class="badge badge-{{ p.status }}">{{ p.status.upper() }}</span>
      <span class="plan-tag">{{ p.plan.upper() }}</span>
      <span class="amount">PKR {{ p.amount_pkr }}</span>
      <span style="color:#e7eaf2;font-size:.9rem">📱 {{ p.phone }}</span>
      {% if p.user_id %}<span style="color:#7e859b;font-size:.8rem">UID: {{ p.user_id }}</span>{% endif %}
    </div>
    <div class="card-meta">
      <span>TID: <span class="tid-val">{{ p.tid }}</span></span>
      <span>via {{ p.payment_method | upper }}</span>
      <span>submitted {{ p.submitted_human }}</span>
      {% if p.reviewed_at %}<span>reviewed {{ p.reviewed_human }}</span>{% endif %}
      {% if p.admin_note %}<span style="color:#ffc107">Note: {{ p.admin_note }}</span>{% endif %}
    </div>

    {% if p.status == 'pending' %}
    <div class="actions">
      <form method="post" action="/tid/{{ p.id }}/approve" style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">
        <button class="btn-approve" type="submit">✓ Approve & Activate</button>
        <input class="note-input" name="note" placeholder="Optional note for records..." style="width:240px">
      </form>
      <form method="post" action="/tid/{{ p.id }}/reject" style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">
        <input class="note-input" name="note" placeholder="Reason for rejection..." style="width:200px">
        <button class="btn-reject" type="submit">✗ Reject</button>
      </form>
    </div>
    {% endif %}
  </div>
  {% endfor %}
</div>
{% endblock %}
"""

def _fmt_time(ts):
    if not ts:
        return "—"
    import datetime
    return datetime.datetime.fromtimestamp(int(ts)).strftime("%d %b %Y, %H:%M")


@bp.route("/")
@login_required
def index():
    tab = request.args.get("tab", "pending")
    status_filter = {
        "pending":  "pending",
        "approved": "approved",
        "rejected": "rejected",
        "all":      None,
    }.get(tab, "pending")

    with db.conn() as c:
        pending_count = c.execute(
            "SELECT COUNT(*) AS n FROM tid_payments WHERE status='pending'"
        ).fetchone()["n"]

        if status_filter:
            rows = c.execute(
                "SELECT * FROM tid_payments WHERE status=? ORDER BY submitted_at DESC LIMIT 100",
                (status_filter,)
            ).fetchall()
        else:
            rows = c.execute(
                "SELECT * FROM tid_payments ORDER BY submitted_at DESC LIMIT 100"
            ).fetchall()

    payments = []
    for r in rows:
        d = dict(r)
        d["submitted_human"] = _fmt_time(r["submitted_at"])
        d["reviewed_human"]  = _fmt_time(r["reviewed_at"])
        payments.append(d)

    return render_template_string(_HTML, payments=payments, tab=tab, pending_count=pending_count)


@bp.route("/<int:payment_id>/approve", methods=["POST"])
@login_required
def approve(payment_id: int):
    note = (request.form.get("note") or "").strip()
    now  = int(time.time())

    with db.conn() as c:
        payment = c.execute(
            "SELECT * FROM tid_payments WHERE id=?", (payment_id,)
        ).fetchone()

    if not payment:
        return "Payment not found", 404

    if payment["status"] != "pending":
        return redirect(url_for("tid_panel.index", tab="all"))

    plan          = payment["plan"]
    user_id       = payment["user_id"]
    duration_days = PLAN_DURATIONS.get(plan, 30)
    started_at    = now
    expires_at    = now + duration_days * 86400

    with db.conn() as c:
        c.execute(
            "UPDATE tid_payments SET status='approved', admin_note=?, reviewed_at=? WHERE id=?",
            (note or None, now, payment_id)
        )
        if user_id:
            c.execute(
                "UPDATE app_subscriptions SET is_active=0 WHERE user_id=?", (user_id,)
            )
            c.execute(
                """INSERT INTO app_subscriptions
                   (user_id, plan, started_at, expires_at, is_active, created_at)
                   VALUES (?,?,?,?,1,?)""",
                (user_id, plan, started_at, expires_at, now)
            )

    log.info("TID %s approved: user=%s plan=%s expires=%s", payment["tid"], user_id, plan, expires_at)
    return redirect(url_for("tid_panel.index", tab="pending"))


@bp.route("/<int:payment_id>/reject", methods=["POST"])
@login_required
def reject(payment_id: int):
    note = (request.form.get("note") or "").strip()
    now  = int(time.time())

    with db.conn() as c:
        c.execute(
            "UPDATE tid_payments SET status='rejected', admin_note=?, reviewed_at=? WHERE id=?",
            (note or None, now, payment_id)
        )

    return redirect(url_for("tid_panel.index", tab="pending"))
