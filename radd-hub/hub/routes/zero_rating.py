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

_HTML = """
{% extends "base.html" %}
{% set active="zero_rating" %}
{% block title %}Zero-Rating{% endblock %}
{% block content %}
<style>
.zr-page { max-width: 900px; margin: 0 auto; }
.zr-page h2 { margin: 0 0 4px; }
.zr-sub { color: var(--muted); font-size: .85rem; margin-bottom: 24px; }
.status-grid { display: grid; grid-template-columns: repeat(4,1fr); gap: 14px; margin-bottom: 24px; }
@media(max-width:700px){ .status-grid { grid-template-columns: repeat(2,1fr); } }
.s-tile { background: var(--panel); border: 1px solid var(--border); border-radius: 12px; padding: 16px 18px; }
.s-tile .k { font-size: .75rem; text-transform: uppercase; letter-spacing: .5px; color: var(--muted); }
.s-tile .v { font-size: 1.6rem; font-weight: 700; margin-top: 4px; word-break: break-all; }
.card { background: var(--panel); border: 1px solid var(--border); border-radius: 12px; padding: 22px; margin-bottom: 18px; }
.card h3 { margin: 0 0 16px; font-size: 14px; color: var(--muted); text-transform: uppercase; letter-spacing: .5px; }
.action-row { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
.btn-prim { padding: 10px 22px; background: var(--accent); color: #fff; border: none; border-radius: 8px; font-weight: 700; font-size: 14px; cursor: pointer; text-decoration: none; display: inline-flex; align-items: center; gap: 6px; }
.btn-prim:hover { filter: brightness(1.1); color: #fff; }
.btn-sec { padding: 10px 18px; background: var(--panel2); color: var(--text); border: 1px solid var(--border); border-radius: 8px; font-size: 13px; cursor: pointer; text-decoration: none; display: inline-flex; align-items: center; gap: 6px; }
.btn-sec:hover { border-color: var(--accent); }
.btn-green { background: rgba(0,200,83,.15); color: var(--ok); border: 1px solid rgba(0,200,83,.3); border-radius: 8px; padding: 10px 18px; font-size: 13px; font-weight: 600; cursor: pointer; text-decoration: none; display: inline-flex; align-items: center; gap: 6px; }
.field { margin-bottom: 14px; }
.field label { display: block; font-size: 11px; color: var(--muted); margin-bottom: 5px; text-transform: uppercase; letter-spacing: .5px; }
.field input { width: 100%; padding: 10px 12px; background: var(--panel2); border: 1px solid var(--border); color: var(--text); border-radius: 8px; font-size: 13px; font-family: monospace; }
.field input:focus { outline: none; border-color: var(--accent); }
.flow-steps { counter-reset: step; list-style: none; padding: 0; margin: 0; }
.flow-steps li { counter-increment: step; display: flex; gap: 14px; align-items: flex-start; padding: 12px 0; border-bottom: 1px solid var(--border); }
.flow-steps li:last-child { border-bottom: none; }
.flow-steps li::before { content: counter(step); background: var(--accent); color: #fff; width: 24px; height: 24px; border-radius: 50%; display: flex; align-items: center; justify-content:: center; justify-content: center; font-size: 12px; font-weight: 700; flex-shrink: 0; }
.flow-steps .step-text { font-size: 13px; line-height: 1.5; }
.flow-steps .step-text code { background: var(--panel2); padding: 1px 6px; border-radius: 4px; font-size: 12px; color: var(--accent); }
.ok-badge { display: inline-flex; align-items: center; gap: 5px; padding: 4px 10px; border-radius: 10px; font-size: 12px; font-weight: 700; }
.ok-badge.green { background: rgba(0,200,83,.15); color: var(--ok); }
.ok-badge.red   { background: rgba(255,107,107,.1); color: var(--err); }
.ok-badge.warn  { background: rgba(255,193,7,.15); color: var(--warn); }
.success-flash { background: rgba(0,200,83,.1); border: 1px solid rgba(0,200,83,.3); border-radius: 8px; padding: 12px 16px; margin-bottom: 16px; color: var(--ok); font-size: 14px; }
</style>

<div class="zr-page">
  <h2>⚡ Zero-Rating Manager</h2>
  <p class="zr-sub">Jazz SIM users (zero-rated) get catalog updates from JazzDrive — no data bundle needed. Manage that flow here.</p>

  {% if msg %}
  <div class="success-flash">{{ msg }}</div>
  {% endif %}

  <!-- Status tiles -->
  <div class="status-grid">
    <div class="s-tile">
      <div class="k">DB Update</div>
      <div class="v" style="font-size:1.1rem">
        {% if db_update_exists %}
          <span class="ok-badge green">✓ Generated</span>
        {% else %}
          <span class="ok-badge red">✗ Missing</span>
        {% endif %}
      </div>
    </div>
    <div class="s-tile">
      <div class="k">Titles in JSON</div>
      <div class="v" style="color:var(--ok)">{{ json_titles }}</div>
    </div>
    <div class="s-tile">
      <div class="k">Generated At</div>
      <div class="v" style="font-size:.9rem;color:var(--muted)">{{ generated_at or '—' }}</div>
    </div>
    <div class="s-tile">
      <div class="k">JD URL Set</div>
      <div class="v" style="font-size:1.1rem">
        {% if jd_url %}
          <span class="ok-badge green">✓ Yes</span>
        {% else %}
          <span class="ok-badge red">✗ No</span>
        {% endif %}
      </div>
    </div>
  </div>

  <!-- Generate & Download -->
  <div class="card">
    <h3>🔄 Step 1 — Generate db_update.json</h3>
    <p style="font-size:13px;color:var(--muted);margin:0 0 16px">
      Creates a catalog JSON from all {{ published_titles }} published titles. Run this every time you add new content.
    </p>
    <div class="action-row">
      <form method="post" action="/zero-rating/generate">
        <button type="submit" class="btn-prim">⚡ Generate Now</button>
      </form>
      {% if db_update_exists %}
      <a href="/zero-rating/download" class="btn-green">⬇ Download db_update.json</a>
      <a href="/api/catalog/db_update" target="_blank" class="btn-sec">🔗 View Raw JSON</a>
      {% endif %}
    </div>
    {% if db_update_exists %}
    <div style="margin-top:14px;padding:12px;background:var(--panel2);border-radius:8px;font-size:12px;color:var(--muted);font-family:monospace">
      {{ db_update_path }}<br>
      Size: {{ file_size_kb }} KB · {{ json_titles }} titles · {{ json_episodes }} episodes
    </div>
    {% endif %}
  </div>

  <!-- JazzDrive URL -->
  <div class="card">
    <h3>🌐 Step 2 — JazzDrive URL Configuration</h3>
    <p style="font-size:13px;color:var(--muted);margin:0 0 14px">
      After uploading <code>db_update.json</code> to JazzDrive, paste the direct download URL here.
      The app will use this zero-rated URL as fallback when users have no internet bundle.
    </p>
    <div class="field">
      <label>Current JazzDrive DB Update URL</label>
      <input type="text" id="jd-url-display" value="{{ jd_url or '' }}" readonly 
             style="cursor:pointer" onclick="this.select()">
    </div>
    <form method="post" action="/zero-rating/set-url" style="display:flex;gap:10px;flex-wrap:wrap">
      <input type="url" name="url" placeholder="https://jazz.drive.url/..." 
             style="flex:1;padding:10px 12px;background:var(--panel2);border:1px solid var(--border);color:var(--text);border-radius:8px;font-size:13px;min-width:200px" required>
      <button type="submit" class="btn-prim">💾 Save URL</button>
    </form>
    <div style="margin-top:12px;font-size:12px;color:var(--muted)">
      <b>Quick option:</b> Use our own server endpoint (works without JazzDrive upload):
      <code style="margin-left:6px;background:var(--panel2);padding:2px 8px;border-radius:4px;color:var(--accent)">http://92.4.95.252/api/catalog/db_update</code>
      <form method="post" action="/zero-rating/set-url" style="display:inline;margin-left:8px">
        <input type="hidden" name="url" value="http://92.4.95.252/api/catalog/db_update">
        <button type="submit" class="btn-sec" style="padding:4px 10px;font-size:12px">Use Oracle endpoint</button>
      </form>
    </div>
  </div>

  <!-- How it works -->
  <div class="card">
    <h3>📖 How the Zero-Rating System Works</h3>
    <ul class="flow-steps">
      <li>
        <div class="step-text">
          <b>Admin adds content in Radd Hub</b> → Click ⚡ Generate Now above to create <code>db_update.json</code>
        </div>
      </li>
      <li>
        <div class="step-text">
          <b>Optional: Upload to JazzDrive</b> → Download the JSON → Upload to JazzDrive folder → Get share URL → Paste above.<br>
          <span style="color:var(--ok)">This enables true zero-rated updates for users with ₹0 balance.</span>
        </div>
      </li>
      <li>
        <div class="step-text">
          <b>App syncs automatically</b> → On startup, app tries primary API first. If no internet, it uses JazzDrive URL (zero-rated). Updates every 12 hours.
        </div>
      </li>
      <li>
        <div class="step-text">
          <b>Users see new content</b> → Within 12 hours, all app users receive catalog updates. Jazz SIM users with ₹0 balance still get updates via JazzDrive.
        </div>
      </li>
    </ul>
    <div style="margin-top:16px;padding:12px;background:var(--panel2);border-radius:8px;font-size:12px;color:var(--muted)">
      <b>Poster strategy:</b> Posters are NOT zero-rated. App uses local file cache (30-day expiry) → TMDB via server proxy (internet needed) → JazzDrive poster URL (zero-rated fallback). Jazz users with zero balance still see cached posters.
    </div>
  </div>

  <!-- Title free/paid status -->
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
</div>
{% endblock %}
"""

def _get_db_update_info():
    try:
        data = json.load(open(_DB_UPDATE_PATH))
        gen_ts = data.get("generated_at", "")
        return True, len(data.get("titles", [])), len(data.get("episodes", [])), gen_ts, os.path.getsize(_DB_UPDATE_PATH) // 1024
    except:
        return False, 0, 0, None, 0

@bp.route("/")
@login_required
def index():
    msg = request.args.get("msg")
    exists, json_titles, json_episodes, gen_at, size_kb = _get_db_update_info()

    with db.conn() as c:
        published = c.execute("SELECT COUNT(*) AS n FROM titles WHERE is_published=1").fetchone()["n"]
        jd_url_row = c.execute("SELECT v FROM settings WHERE k='jd_db_update_url'").fetchone()
        jd_url = jd_url_row["v"] if jd_url_row else None
        titles = c.execute("SELECT id, title, year, is_free FROM titles WHERE is_published=1 ORDER BY title").fetchall()

    return render_template_string(_HTML,
        msg=msg,
        db_update_exists=exists,
        json_titles=json_titles,
        json_episodes=json_episodes,
        generated_at=gen_at,
        file_size_kb=size_kb,
        db_update_path=_DB_UPDATE_PATH,
        jd_url=jd_url,
        published_titles=published,
        titles=[dict(t) for t in titles],
    )

def _infer_status(row) -> str:
    """Infer status when DB field is NULL — heuristic for regional content.
    
    Sources used in order: DB status field → is_ongoing flag → year heuristic.
    Movies are always 'released'.  Shows from the last 2 years default to
    'ongoing'; older shows default to 'completed'.
    """
    if row.get("status"):
        return row["status"]
    if row.get("is_ongoing"):
        return "ongoing"
    mt = (row.get("media_type") or "movie").lower()
    if mt == "movie":
        return "released"
    try:
        yr = int(row.get("year") or 0)
        current_year = 2026
        if yr >= current_year - 1:
            return "ongoing"
        return "completed"
    except Exception:
        return "released"


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
        except: pass
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
    return redirect(url_for("zero_rating.index", msg=f"✓ Generated db_update.json — {len(titles_out)} titles, {len(episodes_out)} episodes"))

@bp.route("/download")
@login_required
def download():
    if not os.path.exists(_DB_UPDATE_PATH):
        return "db_update.json not found — generate it first", 404
    return send_file(_DB_UPDATE_PATH, as_attachment=True, download_name="db_update.json", mimetype="application/json")

@bp.route("/set-url", methods=["POST"])
@login_required
def set_url():
    url = request.form.get("url", "").strip()
    if not url:
        return redirect(url_for("zero_rating.index"))
    with db.conn() as c:
        c.execute("INSERT OR REPLACE INTO settings(k,v) VALUES('jd_db_update_url',?)", (url,))
    log.info("Updated jd_db_update_url to: %s", url)
    return redirect(url_for("zero_rating.index", msg=f"✓ JD URL saved: {url}"))

@bp.route("/toggle-free/<int:title_id>", methods=["POST"])
@login_required
def toggle_free(title_id: int):
    with db.conn() as c:
        row = c.execute("SELECT is_free FROM titles WHERE id=?", (title_id,)).fetchone()
        if row:
            new_val = 0 if row["is_free"] else 1
            c.execute("UPDATE titles SET is_free=? WHERE id=?", (new_val, title_id))
    return redirect(url_for("zero_rating.index", msg="✓ Title updated"))
