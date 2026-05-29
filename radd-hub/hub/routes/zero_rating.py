"""Zero-Rating / JazzDrive DB Update admin panel."""
from __future__ import annotations
import os, json, time, datetime, logging
from flask import Blueprint, render_template_string, request, redirect, url_for, jsonify, send_file
from hub import db
from hub.config import DATA_DIR as _DATA_DIR
from hub.auth import login_required

log = logging.getLogger("hub.zero_rating")
bp = Blueprint("zero_rating", __name__, url_prefix="/zero-rating")

_DB_UPDATE_PATH = str(_DATA_DIR / "db_update.json")
_DELTA_PATH     = str(_DATA_DIR / "delta.json")

# ─────────────────────────────────────────────────────────────────────────────
# Delta JSON helpers
# ─────────────────────────────────────────────────────────────────────────────

def generate_delta_payload() -> dict:
    """Build a metadata-only delta dict — NO file_id, NO share_url, NO folder_share_url.

    This is the version that gets uploaded to JazzDrive (publicly accessible, zero-rated).
    Sensitive streaming identifiers MUST stay on the Oracle server only.
    """
    with db.conn() as c:
        rows = c.execute("""
            SELECT id, title, year, media_type, plot, overview,
                   rating, genres, language, is_free, updated_at,
                   poster, status, is_ongoing, runtime, season_count, episode_count
            FROM titles WHERE is_published = 1
            ORDER BY id
        """).fetchall()

    titles_out = []
    for r in rows:
        genres = []
        try:
            genres = json.loads(r["genres"] or "[]")
            if not isinstance(genres, list):
                genres = [str(genres)]
        except Exception:
            pass

        # Infer status when NULL
        status = r["status"] or _infer_status(r)

        titles_out.append({
            "id":          r["id"],
            "title":       r["title"] or "",
            "year":        r["year"],
            "media_type":  r["media_type"] or "movie",
            "description": r["plot"] or r["overview"] or "",
            "rating":      float(r["rating"] or 0),
            "genres":      genres,
            "language":    r["language"] or "",
            "is_free":     1 if r["is_free"] else 0,
            "poster_url":  r["poster"] or "",
            "status":      status,
            "is_ongoing":  1 if (r["is_ongoing"] or status == "ongoing") else 0,
            "runtime":     r["runtime"],
            "season_count":  r["season_count"],
            "episode_count": r["episode_count"],
            "db_version":  int(r["updated_at"] or 0),
            # NO file_id, NO share_url, NO poster_share_url, NO folder_share_url
        })

    now = int(time.time())
    return {
        "version":      now,
        "format":       "delta_v1",
        "generated_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "titles":       titles_out,
    }


def _get_delta_info():
    try:
        data  = json.load(open(_DELTA_PATH))
        gen   = data.get("generated_at", "")
        count = len(data.get("titles", []))
        size  = os.path.getsize(_DELTA_PATH) // 1024
        return True, count, gen, size
    except Exception:
        return False, 0, None, 0


def _get_db_update_info():
    try:
        data = json.load(open(_DB_UPDATE_PATH))
        gen_ts = data.get("generated_at", "")
        return True, len(data.get("titles", [])), len(data.get("episodes", [])), gen_ts, os.path.getsize(_DB_UPDATE_PATH) // 1024
    except Exception:
        return False, 0, 0, None, 0


# ─────────────────────────────────────────────────────────────────────────────
# HTML template
# ─────────────────────────────────────────────────────────────────────────────

_HTML = """
{% extends "base.html" %}
{% set active="zero_rating" %}
{% block title %}Zero-Rating{% endblock %}
{% block content %}
<style>
.zr-page { max-width: 960px; margin: 0 auto; }
.zr-page h2 { margin: 0 0 4px; }
.zr-sub { color: var(--muted); font-size: .85rem; margin-bottom: 24px; }
.status-grid { display: grid; grid-template-columns: repeat(4,1fr); gap: 14px; margin-bottom: 24px; }
@media(max-width:700px){ .status-grid { grid-template-columns: repeat(2,1fr); } }
.s-tile { background: var(--panel); border: 1px solid var(--border); border-radius: 12px; padding: 16px 18px; }
.s-tile .k { font-size: .75rem; text-transform: uppercase; letter-spacing: .5px; color: var(--muted); }
.s-tile .v { font-size: 1.6rem; font-weight: 700; margin-top: 4px; word-break: break-all; }
.card { background: var(--panel); border: 1px solid var(--border); border-radius: 12px; padding: 22px; margin-bottom: 18px; }
.card h3 { margin: 0 0 16px; font-size: 14px; color: var(--muted); text-transform: uppercase; letter-spacing: .5px; }
.card-accent { border-color: var(--accent); }
.action-row { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
.btn-prim  { padding: 10px 22px; background: var(--accent); color: #fff; border: none; border-radius: 8px; font-weight: 700; font-size: 14px; cursor: pointer; text-decoration: none; display: inline-flex; align-items: center; gap: 6px; }
.btn-prim:hover { filter: brightness(1.1); color: #fff; }
.btn-sec   { padding: 10px 18px; background: var(--panel2); color: var(--text); border: 1px solid var(--border); border-radius: 8px; font-size: 13px; cursor: pointer; text-decoration: none; display: inline-flex; align-items: center; gap: 6px; }
.btn-sec:hover { border-color: var(--accent); }
.btn-green { background: rgba(0,200,83,.15); color: var(--ok); border: 1px solid rgba(0,200,83,.3); border-radius: 8px; padding: 10px 18px; font-size: 13px; font-weight: 600; cursor: pointer; text-decoration: none; display: inline-flex; align-items: center; gap: 6px; }
.btn-orange { background: rgba(255,152,0,.15); color: #ff9800; border: 1px solid rgba(255,152,0,.3); border-radius: 8px; padding: 10px 18px; font-size: 13px; font-weight: 600; cursor: pointer; text-decoration: none; display: inline-flex; align-items: center; gap: 6px; }
.btn-orange:hover { background: rgba(255,152,0,.25); }
.btn-danger { background: rgba(255,107,107,.1); color: var(--err); border: 1px solid rgba(255,107,107,.3); border-radius: 8px; padding: 8px 14px; font-size: 12px; font-weight: 600; cursor: pointer; text-decoration: none; display: inline-flex; align-items: center; gap: 5px; }
.field { margin-bottom: 14px; }
.field label { display: block; font-size: 11px; color: var(--muted); margin-bottom: 5px; text-transform: uppercase; letter-spacing: .5px; }
.field input { width: 100%; padding: 10px 12px; background: var(--panel2); border: 1px solid var(--border); color: var(--text); border-radius: 8px; font-size: 13px; font-family: monospace; }
.field input:focus { outline: none; border-color: var(--accent); }
.flow-steps { counter-reset: step; list-style: none; padding: 0; margin: 0; }
.flow-steps li { counter-increment: step; display: flex; gap: 14px; align-items: flex-start; padding: 12px 0; border-bottom: 1px solid var(--border); }
.flow-steps li:last-child { border-bottom: none; }
.flow-steps li::before { content: counter(step); background: var(--accent); color: #fff; width: 24px; height: 24px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 700; flex-shrink: 0; }
.flow-steps .step-text { font-size: 13px; line-height: 1.5; }
.flow-steps .step-text code { background: var(--panel2); padding: 1px 6px; border-radius: 4px; font-size: 12px; color: var(--accent); }
.ok-badge  { display: inline-flex; align-items: center; gap: 5px; padding: 4px 10px; border-radius: 10px; font-size: 12px; font-weight: 700; }
.ok-badge.green  { background: rgba(0,200,83,.15); color: var(--ok); }
.ok-badge.red    { background: rgba(255,107,107,.1); color: var(--err); }
.ok-badge.warn   { background: rgba(255,193,7,.15); color: var(--warn); }
.ok-badge.orange { background: rgba(255,152,0,.15); color: #ff9800; }
.flash-ok  { background: rgba(0,200,83,.1); border: 1px solid rgba(0,200,83,.3); border-radius: 8px; padding: 12px 16px; margin-bottom: 16px; color: var(--ok); font-size: 14px; }
.flash-err { background: rgba(255,107,107,.08); border: 1px solid rgba(255,107,107,.3); border-radius: 8px; padding: 12px 16px; margin-bottom: 16px; color: var(--err); font-size: 14px; }
.section-tag { font-size: 10px; text-transform: uppercase; letter-spacing: .8px; padding: 2px 7px; border-radius: 4px; font-weight: 700; margin-left: 8px; vertical-align: middle; }
.tag-security { background: rgba(255,107,107,.15); color: var(--err); }
.tag-primary  { background: rgba(98,100,167,.2); color: var(--accent); }
</style>

<div class="zr-page">
  <h2>⚡ Zero-Rating Manager</h2>
  <p class="zr-sub">Jazz SIM users (zero-rated) get catalog metadata from JazzDrive — no data bundle needed. Manage that flow here.</p>

  {% if msg %}
  <div class="flash-ok">{{ msg }}</div>
  {% endif %}
  {% if err %}
  <div class="flash-err">{{ err }}</div>
  {% endif %}

  <!-- ── DELTA STATUS TILES ─────────────────────────────────────────────── -->
  <div class="status-grid">
    <div class="s-tile">
      <div class="k">Delta JSON</div>
      <div class="v" style="font-size:1.1rem">
        {% if delta_exists %}
          <span class="ok-badge green">✓ Ready</span>
        {% else %}
          <span class="ok-badge red">✗ Missing</span>
        {% endif %}
      </div>
    </div>
    <div class="s-tile">
      <div class="k">Titles in Delta</div>
      <div class="v" style="color:var(--ok)">{{ delta_titles }}</div>
    </div>
    <div class="s-tile">
      <div class="k">Delta Generated</div>
      <div class="v" style="font-size:.85rem;color:var(--muted)">{{ delta_at or '—' }}</div>
    </div>
    <div class="s-tile">
      <div class="k">JD Delta URL</div>
      <div class="v" style="font-size:1.1rem">
        {% if jd_delta_url %}
          <span class="ok-badge green">✓ Set</span>
        {% else %}
          <span class="ok-badge red">✗ Not Set</span>
        {% endif %}
      </div>
    </div>
  </div>

  <!-- ── STEP 1: GENERATE DELTA ─────────────────────────────────────────── -->
  <div class="card card-accent">
    <h3>🔒 Step 1 — Generate delta.json <span class="section-tag tag-primary">JazzDrive Safe</span></h3>
    <p style="font-size:13px;color:var(--muted);margin:0 0 14px">
      Creates a <b>metadata-only</b> JSON — no file IDs, no share URLs, no streaming secrets.
      This is safe to upload to JazzDrive (publicly readable).
      Auto-regenerated every 24h by the scheduler.
    </p>
    <div class="action-row">
      <form method="post" action="/zero-rating/generate-delta">
        <button type="submit" class="btn-prim">⚡ Generate Delta Now</button>
      </form>
      {% if delta_exists %}
      <a href="/zero-rating/download-delta" class="btn-green">⬇ Download delta.json</a>
      {% endif %}
      {% if delta_exists %}
      <form method="post" action="/zero-rating/upload-delta">
        <button type="submit" class="btn-orange">☁ Generate + Upload to JazzDrive</button>
      </form>
      {% endif %}
    </div>
    {% if delta_exists %}
    <div style="margin-top:14px;padding:12px;background:var(--panel2);border-radius:8px;font-size:12px;color:var(--muted);font-family:monospace">
      delta.json · {{ delta_size_kb }} KB · {{ delta_titles }} titles
      · Format: delta_v1 (metadata only — <b style="color:var(--ok)">safe for JazzDrive</b>)
    </div>
    {% endif %}
  </div>

  <!-- ── STEP 2: JAZZDRIVE DELTA URL ───────────────────────────────────── -->
  <div class="card">
    <h3>🌐 Step 2 — JazzDrive Delta URL</h3>
    <p style="font-size:13px;color:var(--muted);margin:0 0 14px">
      After uploading <code>delta.json</code> to JazzDrive, paste the direct download URL here.
      The app uses this zero-rated URL to get catalog metadata when users have no internet bundle.
    </p>
    <div class="field">
      <label>Current JazzDrive Delta URL</label>
      <input type="text" value="{{ jd_delta_url or '' }}" readonly
             style="cursor:pointer" onclick="this.select()">
    </div>
    <form method="post" action="/zero-rating/set-delta-url" style="display:flex;gap:10px;flex-wrap:wrap">
      <input type="url" name="url" placeholder="https://cloud.jazzdrive.com.pk/..."
             style="flex:1;padding:10px 12px;background:var(--panel2);border:1px solid var(--border);color:var(--text);border-radius:8px;font-size:13px;min-width:200px" required>
      <button type="submit" class="btn-prim">💾 Save URL</button>
    </form>
    <div style="margin-top:10px;font-size:12px;color:var(--muted)">
      <b>Quick option:</b> Use Oracle server endpoint (internet required, not zero-rated):
      <code style="margin-left:6px;background:var(--panel2);padding:2px 8px;border-radius:4px;color:var(--accent)">http://92.4.95.252/api/catalog/delta</code>
      <form method="post" action="/zero-rating/set-delta-url" style="display:inline;margin-left:8px">
        <input type="hidden" name="url" value="http://92.4.95.252/api/catalog/delta">
        <button type="submit" class="btn-sec" style="padding:4px 10px;font-size:12px">Use Oracle endpoint</button>
      </form>
    </div>
  </div>

  <!-- ── SECURITY: REMOVE FULL CATALOG ─────────────────────────────────── -->
  <div class="card">
    <h3>🛡 Security — Full Catalog <span class="section-tag tag-security">SECURITY RISK</span></h3>
    <p style="font-size:13px;color:var(--muted);margin:0 0 14px">
      The <b>full db_update.json</b> contains <code>file_id</code>, <code>share_url</code>, and
      <code>folder_share_url</code> — streaming credentials that let anyone bypass the paywall.
      <b>This file must NEVER be on JazzDrive.</b>
      Remove the old JazzDrive URL for it if one was set.
    </p>
    <div class="action-row">
      {% if jd_db_update_url %}
      <form method="post" action="/zero-rating/clear-db-update-url">
        <button type="submit" class="btn-danger">🗑 Clear Old Full-Catalog JD URL</button>
      </form>
      {% endif %}
    </div>
    {% if jd_db_update_url %}
    <div style="margin-top:10px;padding:10px 12px;background:rgba(255,107,107,.06);border:1px solid rgba(255,107,107,.2);border-radius:8px;font-size:12px;font-family:monospace;color:var(--err)">
      ⚠ Old URL still set: {{ jd_db_update_url[:80] }}{{ '…' if jd_db_update_url|length > 80 else '' }}
    </div>
    {% else %}
    <div style="margin-top:10px;padding:10px 12px;background:rgba(0,200,83,.06);border:1px solid rgba(0,200,83,.2);border-radius:8px;font-size:12px;color:var(--ok)">
      ✓ No JazzDrive URL set for the full catalog — safe.
    </div>
    {% endif %}

    <!-- Still allow generating full db_update.json (Oracle-only, no JazzDrive) -->
    <details style="margin-top:16px">
      <summary style="font-size:12px;color:var(--muted);cursor:pointer">▸ Full db_update.json (Oracle server only — never upload to JazzDrive)</summary>
      <div style="padding-top:12px">
        <div style="margin-bottom:10px;font-size:12px;color:var(--muted)">
          {{ 'Generated: ' + db_update_generated_at if db_update_exists else 'Not generated yet' }}
          {{ ' · ' + db_update_size_kb|string + ' KB · ' + json_titles|string + ' titles · ' + json_episodes|string + ' episodes' if db_update_exists else '' }}
        </div>
        <div class="action-row">
          <form method="post" action="/zero-rating/generate">
            <button type="submit" class="btn-sec" style="font-size:12px;padding:7px 14px">⚡ Generate db_update.json</button>
          </form>
          {% if db_update_exists %}
          <a href="/zero-rating/download" class="btn-sec" style="font-size:12px;padding:7px 14px">⬇ Download</a>
          {% endif %}
        </div>
      </div>
    </details>
  </div>

  <!-- ── FREE/PAID TITLES ───────────────────────────────────────────────── -->
  <div class="card">
    <h3>🔓 Free vs Paid Titles ({{ published_titles }} published)</h3>
    <p style="font-size:13px;color:var(--muted);margin:0 0 14px">
      Free titles are visible to guest users. Mark at least 2-3 as free so new users see something.
    </p>
    <div style="overflow-x:auto">
    <table style="width:100%;border-collapse:collapse">
      <thead><tr>
        <th style="text-align:left;padding:8px 12px;font-size:11px;color:var(--muted);border-bottom:1px solid var(--border)">Title</th>
        <th style="text-align:center;padding:8px 12px;font-size:11px;color:var(--muted);border-bottom:1px solid var(--border)">Free?</th>
        <th style="padding:8px 12px;font-size:11px;color:var(--muted);border-bottom:1px solid var(--border)">Toggle</th>
      </tr></thead>
      <tbody>
      {% for t in titles %}
      <tr>
        <td style="padding:8px 12px;font-size:13px">{{ t.title }} <span style="color:var(--muted);font-size:11px">({{ t.year }})</span></td>
        <td style="text-align:center;padding:8px 12px">
          {% if t.is_free %}
            <span style="padding:2px 10px;border-radius:10px;font-size:12px;font-weight:700;background:rgba(0,200,83,.15);color:var(--ok)">FREE</span>
          {% else %}
            <span style="padding:2px 10px;border-radius:10px;font-size:12px;font-weight:700;background:rgba(126,133,155,.15);color:var(--muted)">PAID</span>
          {% endif %}
        </td>
        <td style="padding:8px 12px">
          <form method="post" action="/zero-rating/toggle-free/{{ t.id }}" style="display:inline">
            <button type="submit" style="padding:3px 12px;font-size:12px;border-radius:6px;border:1px solid var(--border);background:var(--panel2);color:var(--text);cursor:pointer">
              {% if t.is_free %}Make Paid{% else %}Make Free{% endif %}
            </button>
          </form>
        </td>
      </tr>
      {% endfor %}
      </tbody>
    </table>
    </div>
  </div>

  <!-- ── HOW IT WORKS ──────────────────────────────────────────────────── -->
  <div class="card">
    <h3>📖 How the Zero-Rating System Works</h3>
    <ul class="flow-steps">
      <li>
        <div class="step-text">
          <b>Admin adds content in Radd Hub</b> → Click ⚡ Generate Delta Now above to create <code>delta.json</code> (metadata only — no streaming secrets)
        </div>
      </li>
      <li>
        <div class="step-text">
          <b>Click ☁ Generate + Upload to JazzDrive</b> → Uploads delta.json automatically, saves the URL. The scheduler regenerates and re-uploads every 24h.
        </div>
      </li>
      <li>
        <div class="step-text">
          <b>App syncs automatically on startup</b> → Tries Oracle server first (full sync with streaming links). If no internet bundle, uses JazzDrive Delta URL (metadata only, zero-rated). Updates every 12 hours.
        </div>
      </li>
      <li>
        <div class="step-text">
          <b>Users see new catalog</b> → Jazz SIM users with ₹0 balance can browse new titles via JazzDrive. Streaming still needs an internet bundle or Jazz subscription.
        </div>
      </li>
    </ul>
  </div>
</div>
{% endblock %}
"""


# ─────────────────────────────────────────────────────────────────────────────
# Status helpers
# ─────────────────────────────────────────────────────────────────────────────

def _infer_status(row) -> str:
    if row.get("status"):
        return row["status"]
    if row.get("is_ongoing"):
        return "ongoing"
    mt = (row.get("media_type") or "movie").lower()
    if mt == "movie":
        return "released"
    try:
        yr = int(row.get("year") or 0)
        if yr >= 2025:
            return "ongoing"
        return "completed"
    except Exception:
        return "released"


def _render_index(msg=None, err=None):
    delta_exists, delta_titles, delta_at, delta_size_kb = _get_delta_info()
    db_exists, json_titles, json_episodes, db_gen_at, db_size = _get_db_update_info()

    with db.conn() as c:
        published = c.execute("SELECT COUNT(*) AS n FROM titles WHERE is_published=1").fetchone()["n"]
        jd_delta_row = c.execute("SELECT v FROM settings WHERE k='jd_delta_url'").fetchone()
        jd_delta_url = jd_delta_row["v"] if jd_delta_row else None
        jd_db_update_row = c.execute("SELECT v FROM settings WHERE k='jd_db_update_url'").fetchone()
        jd_db_update_url = jd_db_update_row["v"] if jd_db_update_row else None
        titles = c.execute("SELECT id, title, year, is_free FROM titles WHERE is_published=1 ORDER BY title").fetchall()

    return render_template_string(_HTML,
        msg=msg, err=err,
        delta_exists=delta_exists,
        delta_titles=delta_titles,
        delta_at=delta_at,
        delta_size_kb=delta_size_kb,
        jd_delta_url=jd_delta_url,
        jd_db_update_url=jd_db_update_url,
        db_update_exists=db_exists,
        json_titles=json_titles,
        json_episodes=json_episodes,
        db_update_generated_at=db_gen_at,
        db_update_size_kb=db_size,
        published_titles=published,
        titles=[dict(t) for t in titles],
    )


# ─────────────────────────────────────────────────────────────────────────────
# Routes
# ─────────────────────────────────────────────────────────────────────────────

@bp.route("/")
@login_required
def index():
    msg = request.args.get("msg")
    return _render_index(msg=msg)


@bp.route("/generate-delta", methods=["POST"])
@login_required
def generate_delta():
    """Generate delta.json — metadata only, safe for JazzDrive."""
    payload = generate_delta_payload()
    with open(_DELTA_PATH, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    log.info("Generated delta.json: %d titles (metadata-only)", len(payload["titles"]))
    return _render_index(msg=f"✓ Generated delta.json — {len(payload['titles'])} titles (metadata only, safe for JazzDrive)")


@bp.route("/upload-delta", methods=["POST"])
@login_required
def upload_delta():
    """Generate delta.json and upload to JazzDrive, saving the share URL."""
    # 1. Generate fresh delta
    payload = generate_delta_payload()
    with open(_DELTA_PATH, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    log.info("Generated delta.json for upload: %d titles", len(payload["titles"]))

    # 2. Upload to JazzDrive
    try:
        from hub import jazzdrive as jd
        result = jd.upload_file_to_jazzdrive(_DELTA_PATH)
        if not result.get("ok"):
            err_msg = result.get("error", "Unknown upload error")
            log.error("JazzDrive delta upload failed: %s", err_msg)
            return _render_index(err=f"✗ Upload failed: {err_msg} — Download delta.json and upload manually.")

        share_url = result.get("share_url") or result.get("url") or ""
        if share_url:
            with db.conn() as c:
                c.execute("INSERT OR REPLACE INTO settings(k,v) VALUES('jd_delta_url',?)", (share_url,))
            log.info("JazzDrive delta URL saved: %s", share_url)
            return _render_index(msg=f"✓ Uploaded & saved JazzDrive delta URL: {share_url}")
        else:
            return _render_index(err="✗ Upload succeeded but no share URL returned. Check jazzdrive.py upload_file_to_jazzdrive return value.")

    except Exception as e:
        log.exception("upload_delta error")
        return _render_index(err=f"✗ JazzDrive upload error: {e} — Download delta.json and upload manually.")


@bp.route("/download-delta")
@login_required
def download_delta():
    if not os.path.exists(_DELTA_PATH):
        return "delta.json not found — generate it first", 404
    return send_file(_DELTA_PATH, as_attachment=True, download_name="delta.json", mimetype="application/json")


@bp.route("/set-delta-url", methods=["POST"])
@login_required
def set_delta_url():
    url = request.form.get("url", "").strip()
    if not url:
        return redirect(url_for("zero_rating.index"))
    with db.conn() as c:
        c.execute("INSERT OR REPLACE INTO settings(k,v) VALUES('jd_delta_url',?)", (url,))
    log.info("Updated jd_delta_url: %s", url)
    return _render_index(msg=f"✓ JD Delta URL saved: {url}")


@bp.route("/clear-db-update-url", methods=["POST"])
@login_required
def clear_db_update_url():
    with db.conn() as c:
        c.execute("DELETE FROM settings WHERE k='jd_db_update_url'")
    log.info("Cleared jd_db_update_url (full catalog URL removed for security)")
    return _render_index(msg="✓ Old full-catalog JazzDrive URL cleared. Only the delta URL is now active.")


# ─────────────────────────────────────────────────────────────────────────────
# Legacy routes (kept for backward compat — full db_update.json, Oracle only)
# ─────────────────────────────────────────────────────────────────────────────

@bp.route("/generate", methods=["POST"])
@login_required
def generate():
    with db.conn() as c:
        title_rows = c.execute("""
            SELECT t.id, t.title, t.year, t.media_type, t.plot, t.overview,
                   t.rating, t.genres, t.language, t.is_free, t.updated_at,
                   t.poster, t.poster_share_url, t.runtime, t.season_count, t.episode_count,
                   t.status, t.is_ongoing,
                   f.id AS file_id
            FROM titles t
            LEFT JOIN files f ON f.title_id = t.id
              AND (f.season IS NULL OR f.season = 0)
            WHERE t.is_published = 1
            GROUP BY t.id ORDER BY t.id
        """).fetchall()

    title_ids = [r["id"] for r in title_rows]
    titles_out = []
    for r in title_rows:
        genres = []
        try:
            genres = json.loads(r["genres"] or "[]")
            if not isinstance(genres, list): genres = [str(genres)]
        except Exception:
            pass
        titles_out.append({
            "id": r["id"], "title": r["title"] or "",
            "year": r["year"], "media_type": r["media_type"] or "movie",
            "description": r["plot"] or r["overview"] or "",
            "rating": float(r["rating"] or 0), "genres": genres,
            "language": r["language"] or "",
            "is_free": 1 if r["is_free"] else 0,
            "runtime": r["runtime"],
            "season_count": r["season_count"],
            "episode_count": r["episode_count"],
            "poster_url": r["poster"] or "",
            "poster_share_url": r["poster_share_url"] or "",
            "db_version": int(r["updated_at"] or 0),
            "file_id": str(r["file_id"]) if r["file_id"] else None,
            "status": r["status"] or _infer_status(r),
            "is_ongoing": 1 if (r["is_ongoing"] or (r["status"] or "").lower() == "ongoing") else 0,
        })

    episodes_out = []
    if title_ids:
        ph = ",".join("?" * len(title_ids))
        with db.conn() as c:
            ep_rows = c.execute(f"""
                SELECT id, title_id, season, episode
                FROM files
                WHERE title_id IN ({ph})
                  AND season IS NOT NULL AND season > 0
                ORDER BY title_id, season, episode
            """, title_ids).fetchall()
        for r in ep_rows:
            episodes_out.append({
                "id": r["id"], "title_id": r["title_id"],
                "file_id": str(r["id"]),
                "season": r["season"], "episode": r["episode"],
                "label": f"S{r['season']:02d}E{r['episode']:02d}",
                "quality": None, "is_free": 0,
            })

    now = int(time.time())
    payload = {
        "version": now,
        "generated_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "titles": titles_out, "episodes": episodes_out,
    }
    with open(_DB_UPDATE_PATH, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    log.info("Generated db_update.json: %d titles, %d episodes", len(titles_out), len(episodes_out))
    return _render_index(msg=f"✓ Generated db_update.json — {len(titles_out)} titles, {len(episodes_out)} episodes (Oracle-only, do NOT upload to JazzDrive)")


@bp.route("/download")
@login_required
def download():
    if not os.path.exists(_DB_UPDATE_PATH):
        return "db_update.json not found — generate it first", 404
    return send_file(_DB_UPDATE_PATH, as_attachment=True, download_name="db_update.json", mimetype="application/json")


@bp.route("/set-url", methods=["POST"])
@login_required
def set_url():
    """Legacy: set the full-catalog JazzDrive URL (deprecated — use set-delta-url instead)."""
    url = request.form.get("url", "").strip()
    if not url:
        return redirect(url_for("zero_rating.index"))
    with db.conn() as c:
        c.execute("INSERT OR REPLACE INTO settings(k,v) VALUES('jd_db_update_url',?)", (url,))
    log.warning("jd_db_update_url set to %s — WARNING: full catalog on JazzDrive is a security risk", url)
    return _render_index(msg=f"✓ (Legacy) JD full-catalog URL saved: {url}")


@bp.route("/toggle-free/<int:title_id>", methods=["POST"])
@login_required
def toggle_free(title_id: int):
    with db.conn() as c:
        row = c.execute("SELECT is_free FROM titles WHERE id=?", (title_id,)).fetchone()
        if row:
            new_val = 0 if row["is_free"] else 1
            c.execute("UPDATE titles SET is_free=? WHERE id=?", (new_val, title_id))
    return _render_index(msg="✓ Title updated")
