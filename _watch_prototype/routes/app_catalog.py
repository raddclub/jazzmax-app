"""JazzMAX catalog sync API — for Flutter app offline-first database.

The Flutter app calls these endpoints to download and keep its local
encrypted SQLite database up to date.

Endpoints:
  GET /api/catalog/version        — returns current catalog version + count
  GET /api/catalog/sync           — full catalog (JSON) or delta since ?since=<version>
  GET /api/catalog/posters        — list of poster URLs for pre-caching
  GET /api/catalog/db_update      — zero-rated db_update.json for JazzDrive distribution
"""
from __future__ import annotations
import json
import time
import datetime
import logging
from flask import Blueprint, request, jsonify

# External base URL of the watch server — for building poster_jd_url in Flutter clients.
# Override in admin: Settings -> WATCH_SERVER_EXTERNAL_URL
def _get_watch_base():
    try:
        from hub import db as _db
        v = (_db.setting("WATCH_SERVER_EXTERNAL_URL") or "").strip()
        return v.rstrip("/") if v else "http://92.4.95.252"
    except Exception:
        return "http://92.4.95.252:6000"

_WATCH_BASE = _get_watch_base()
from hub import db

log = logging.getLogger("hub.app_catalog")

bp = Blueprint("app_catalog", __name__, url_prefix="/api/catalog")


def _get_catalog_version() -> int:
    with db.conn() as c:
        row = c.execute(
            "SELECT MAX(updated_at) AS v FROM titles WHERE is_published=1"
        ).fetchone()
        return int(row["v"] or 0)


def _count_published() -> int:
    with db.conn() as c:
        row = c.execute(
            "SELECT COUNT(*) AS n FROM titles WHERE is_published=1"
        ).fetchone()
        return int(row["n"] or 0)


@bp.route("/version")
def version():
    v = _get_catalog_version()
    c = _count_published()
    resp = jsonify({"version": v, "count": c})
    # Set ETag so clients can do conditional GET (If-None-Match)
    resp.set_etag(str(v))
    resp.headers["Cache-Control"] = "max-age=60"
    return resp


@bp.route("/db_update/version")
def db_update_version():
    """Lightweight version check — call BEFORE downloading full db_update.json.
    Flutter jazzdrive_db_service checks this first to avoid unnecessary downloads.
    Returns just the version number and count (< 100 bytes).
    """
    v = _get_catalog_version()
    return jsonify({"version": v, "count": _count_published()})


@bp.route("/sync")
def sync():
    """Return published catalog entries.

    ?since=<epoch>   — only return rows updated after this timestamp (delta sync)
    If omitted, return everything (full sync).
    """
    since_raw = request.args.get("since", "0")
    try:
        since = int(since_raw)
    except (ValueError, TypeError):
        since = 0

    # When since=0 (full sync), use -1 so rows with updated_at=0 are included.
    # updated_at=0 means "never updated" and must appear in a full sync.
    since_param = since if since > 0 else -1

    with db.conn() as c:
        title_rows = c.execute(
            """
            SELECT
                t.id, t.title, t.year, t.media_type, t.plot, t.overview,
                t.rating, t.genres, t.language, t.is_free, t.updated_at,
                t.poster, t.poster_share_url, t.runtime, t.season_count, t.episode_count,
                f.id AS file_id, f.share_url AS file_share_url
            FROM titles t
            LEFT JOIN files f ON f.title_id = t.id
              AND (f.season IS NULL OR f.season = 0)
            WHERE t.is_published = 1
              AND (t.updated_at IS NULL OR t.updated_at > ?)
            GROUP BY t.id
            ORDER BY t.updated_at DESC
            """,
            (since_param,)
        ).fetchall()

    titles = []
    title_ids = []
    for r in title_rows:
        title_ids.append(r["id"])
        genres = []
        try:
            genres = json.loads(r["genres"] or "[]")
            if not isinstance(genres, list):
                genres = [str(genres)]
        except Exception:
            pass

        titles.append({
            "id":            r["id"],
            "title":         r["title"] or "",
            "year":          r["year"],
            "media_type":    ("show" if (r["media_type"] or "movie") in ("tv","series") else (r["media_type"] or "movie")),  # FIX BUG-002
            "description":   r["plot"] or r["overview"] or "",
            "rating":        r["rating"],
            "genres":        genres,
            "language":      r["language"] or "",
            "is_free":       1 if r["is_free"] else 0,  # FIX BUG-001
            "runtime":       r["runtime"],
            "season_count":  r["season_count"],
            "episode_count": r["episode_count"],
            "poster_key":    f"title_{r['id']}",
            "poster_url":    r["poster"] or "",
            "poster_jd_url": (_WATCH_BASE + "/watch/poster/" + str(r["id"])) if r["id"] else "",
            "db_version":    int(r["updated_at"] or 0),
            "file_id":       r["file_id"],
            "share_url":     r["file_share_url"] or "",
        })

    episodes = []
    if title_ids:
        placeholders = ",".join("?" * len(title_ids))
        with db.conn() as c:
            ep_rows = c.execute(
                f"""
                SELECT id, title_id, filename, season, episode, share_url
                FROM files
                WHERE title_id IN ({placeholders})
                  AND season IS NOT NULL AND season > 0
                ORDER BY title_id, season, episode
                """,
                title_ids
            ).fetchall()

        for r in ep_rows:
            episodes.append({
                "id":       r["id"],
                "title_id": r["title_id"],
                "file_id":  str(r["id"]),  # files.id IS the file_id used for play links
                "season":   r["season"],
                "episode":  r["episode"],
                "label":    f"S{r['season']:02d}E{r['episode']:02d}",
                "share_url": r["share_url"] or "",  # FIX BUG-009
                "is_free":  0,  # FIX BUG-001b: int not bool
            })

    return jsonify({
        "version":  _get_catalog_version(),
        "titles":   titles,
        "episodes": episodes,
        "count":    len(titles),
    })


@bp.route("/posters")
def posters():
    """Return list of all poster URLs for pre-caching.

    Flutter app calls this once on first launch to download all posters.
    Returns TMDB URLs (fast, free) — never JazzDrive URLs.
    """
    with db.conn() as c:
        rows = c.execute(
            "SELECT id, poster FROM titles WHERE is_published=1 AND poster IS NOT NULL"
        ).fetchall()

    return jsonify({
        "posters": [
            {"key": f"title_{r['id']}", "url": r["poster"]}
            for r in rows if r["poster"]
        ]
    })


@bp.route("/db_update")
def db_update():
    """Generate db_update.json for zero-rated JazzDrive catalog distribution.

    This is the same data as /sync but formatted specifically for
    JazzdriveDbService.dart (Flutter). It uses int 0/1 for is_free (not bool).

    Admin workflow:
      1. Call this endpoint or use admin panel → "Generate DB Update"
      2. Download the JSON response
      3. Upload to JazzDrive at the configured URL
      4. All Jazz SIM users get catalog update within 12h — zero-rated

    This endpoint is intentionally public (no auth) because the file will
    be hosted on JazzDrive which is publicly accessible.
    """
    now = int(time.time())

    with db.conn() as c:
        title_rows = c.execute(
            """
            SELECT
                t.id, t.title, t.year, t.media_type, t.plot, t.overview,
                t.rating, t.genres, t.language, t.is_free, t.updated_at,
                t.poster, t.poster_share_url, t.runtime, t.season_count, t.episode_count,
                f.id AS file_id, f.share_url AS file_share_url
            FROM titles t
            LEFT JOIN files f ON f.title_id = t.id
              AND (f.season IS NULL OR f.season = 0)
            WHERE t.is_published = 1
            GROUP BY t.id
            ORDER BY t.id
            """,
        ).fetchall()

    title_ids = []
    titles_out = []
    for r in title_rows:
        title_ids.append(r["id"])
        genres = []
        try:
            genres = json.loads(r["genres"] or "[]")
            if not isinstance(genres, list):
                genres = [str(genres)]
        except Exception:
            pass

        titles_out.append({
            "id":          r["id"],
            "title":       r["title"] or "",
            "year":        r["year"],
            "media_type":  r["media_type"] or "movie",
            "description": r["plot"] or r["overview"] or "",
            "rating":      r["rating"],
            "genres":      genres,
            "language":    r["language"] or "",
            # NOTE: int 0/1, not bool — JazzdriveDbService casts to int
            "is_free":     1 if r["is_free"] else 0,
            "runtime":     r["runtime"],
            "poster_url":  r["poster"] or "",
            "db_version":  int(r["updated_at"] or 0),
            "file_id":     r["file_id"],
            "share_url":   r["file_share_url"] or "",
        })

    episodes_out = []
    if title_ids:
        placeholders = ",".join("?" * len(title_ids))
        with db.conn() as c:
            ep_rows = c.execute(
                f"""
                SELECT id, title_id, filename, season, episode, share_url
                FROM files
                WHERE title_id IN ({placeholders})
                  AND season IS NOT NULL AND season > 0
                ORDER BY title_id, season, episode
                """,
                title_ids
            ).fetchall()

        for r in ep_rows:
            episodes_out.append({
                "id":       r["id"],
                "title_id": r["title_id"],
                "file_id":  str(r["id"]),
                "season":   r["season"],
                "episode":  r["episode"],
                "label":    f"S{r['season']:02d}E{r['episode']:02d}",
                "share_url": r["share_url"] or "",
                "quality":  None,
                "is_free":  0,  # files table has no is_free; inherit from parent title
            })

    catalog_version = _get_catalog_version() or now

    payload = {
        "version":      catalog_version,
        "generated_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "titles":       titles_out,
        "episodes":     episodes_out,
    }

    response = jsonify(payload)
    # Allow direct download as a file
    response.headers["Content-Disposition"] = "attachment; filename=db_update.json"
    response.headers["Cache-Control"] = "no-cache"
    return response

  @bp.route("/share_url")
  def share_url():
      """Return the JazzDrive share_url for a single file.
      Used by Flutter player as fallback when local DB has no share_url.
      GET /api/catalog/share_url?file_id=<series/ep_idx>
      """
      file_id = request.args.get("file_id", "").strip()
      if not file_id:
          return jsonify({"error": "file_id required"}), 400

      with db.conn() as c:
          # Episodes table stores file_id as "{title_id}/{ep_index}" or similar
          row = c.execute(
              "SELECT share_url FROM episodes WHERE file_id = ?",
              (file_id,)
          ).fetchone()

      if not row:
          return jsonify({"error": "not found"}), 404

      return jsonify({"share_url": row["share_url"] or ""})
  