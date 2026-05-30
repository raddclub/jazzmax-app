"""RaddFlix catalog sync API — Flutter app offline-first database.

Migrated from _watch_prototype/routes/app_catalog.py.
Registered in app.py at /api/catalog prefix.

Endpoints:
  GET /api/catalog/version          current version + count
  GET /api/catalog/db_update/version lightweight version check
  GET /api/catalog/sync             full or delta catalog (JSON)
  GET /api/catalog/posters          poster URLs for pre-caching
  GET /api/catalog/db_update        zero-rated db_update.json
"""
from __future__ import annotations
import json
import time
import datetime
import logging
from flask import Blueprint, request, jsonify
from hub import db

log = logging.getLogger("hub.catalog_api")

bp = Blueprint("catalog_api", __name__, url_prefix="/api/catalog")


def _watch_base() -> str:
    try:
        v = (db.setting("WATCH_SERVER_EXTERNAL_URL") or "").strip()
        return v.rstrip("/") if v else "http://92.4.95.252"
    except Exception:
        return "http://92.4.95.252"


def _catalog_version() -> int:
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
    v = _catalog_version()
    resp = jsonify({"version": v, "count": _count_published()})
    resp.set_etag(str(v))
    resp.headers["Cache-Control"] = "max-age=60"
    return resp


@bp.route("/db_update/version")
def db_update_version():
    v = _catalog_version()
    return jsonify({"version": v, "count": _count_published()})


@bp.route("/sync")
def sync():
    since_raw = request.args.get("since", "0")
    try:
        since = int(since_raw)
    except (ValueError, TypeError):
        since = 0
    since_param = since if since > 0 else -1

    with db.conn() as c:
        title_rows = c.execute(
            """
            SELECT t.id, t.title, t.year, t.media_type, t.plot, t.overview,
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
            """, (since_param,)
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
            "id":           r["id"],
            "title":        r["title"] or "",
            "year":         (int(r["year"]) if r["year"] and str(r["year"]).isdigit() else None),
            "media_type":   ("show" if (r["media_type"] or "movie") in ("tv","series") else (r["media_type"] or "movie")),
            "description":  r["plot"] or r["overview"] or "",
            "rating":       r["rating"],
            "genres":       genres,
            "language":     r["language"] or "",
            "is_free":      1 if r["is_free"] else 0,
            "runtime":      r["runtime"],
            "season_count": r["season_count"],
            "episode_count":r["episode_count"],
            "poster_key":   f"title_{r['id']}",
            "poster_url":   r["poster"] or "",
            "poster_jd_url":(_watch_base() + "/watch/poster/" + str(r["id"])) if r["id"] else "",
            "db_version":   int(r["updated_at"] or 0),
            "file_id":      r["file_id"],
            "share_url":    r["file_share_url"] or "",
        })

    episodes = []
    if title_ids:
        placeholders = ",".join("?" * len(title_ids))
        with db.conn() as c:
            ep_rows = c.execute(
                f"""SELECT id, title_id, filename, season, episode, share_url
                   FROM files
                   WHERE title_id IN ({placeholders})
                     AND season IS NOT NULL AND season > 0
                   ORDER BY title_id, season, episode""",
                title_ids
            ).fetchall()
        for r in ep_rows:
            episodes.append({
                "id":        r["id"],
                "title_id":  r["title_id"],
                "file_id":   str(r["id"]),
                "season":    r["season"],
                "episode":   r["episode"],
                "label":     f"S{r['season']:02d}E{r['episode']:02d}",
                "share_url": r["share_url"] or "",
                "is_free":   0,
            })

    return jsonify({"version": _catalog_version(), "titles": titles,
                    "episodes": episodes, "count": len(titles)})


@bp.route("/posters")
def posters():
    with db.conn() as c:
        rows = c.execute(
            "SELECT id, poster FROM titles WHERE is_published=1 AND poster IS NOT NULL"
        ).fetchall()
    return jsonify({"posters": [{"key": f"title_{r['id']}", "url": r["poster"]}
                                for r in rows if r["poster"]]})


@bp.route("/db_update")
def db_update():
    now = int(time.time())
    with db.conn() as c:
        title_rows = c.execute(
            """SELECT t.id, t.title, t.year, t.media_type, t.plot, t.overview,
                      t.rating, t.genres, t.language, t.is_free, t.updated_at,
                      t.poster, t.poster_share_url, t.runtime, t.season_count, t.episode_count,
                      f.id AS file_id, f.share_url AS file_share_url
               FROM titles t
               LEFT JOIN files f ON f.title_id = t.id
                 AND (f.season IS NULL OR f.season = 0)
               WHERE t.is_published = 1
               GROUP BY t.id ORDER BY t.id"""
        ).fetchall()

    title_ids, titles_out = [], []
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
            "year":        (int(r["year"]) if r["year"] and str(r["year"]).isdigit() else None),
            "media_type":  ("show" if (r["media_type"] or "movie") in ("tv","series") else (r["media_type"] or "movie")),
            "description": r["plot"] or r["overview"] or "",
            "rating":      r["rating"],
            "genres":      genres,
            "language":    r["language"] or "",
            "is_free":     1 if r["is_free"] else 0,
            "runtime":     r["runtime"],
            "poster_url":  r["poster"] or "",
            "db_version":  int(r["updated_at"] or 0),
            "file_id":     str(r["file_id"]) if r["file_id"] is not None else None,
            "share_url":   r["file_share_url"] or "",
        })

    episodes_out = []
    if title_ids:
        placeholders = ",".join("?" * len(title_ids))
        with db.conn() as c:
            ep_rows = c.execute(
                f"""SELECT id, title_id, filename, season, episode, share_url
                   FROM files WHERE title_id IN ({placeholders})
                     AND season IS NOT NULL AND season > 0
                   ORDER BY title_id, season, episode""", title_ids
            ).fetchall()
        for r in ep_rows:
            episodes_out.append({
                "id": r["id"], "title_id": r["title_id"], "file_id": str(r["id"]),
                "season": r["season"], "episode": r["episode"],
                "label": f"S{r['season']:02d}E{r['episode']:02d}",
                "share_url": r["share_url"] or "", "quality": None, "is_free": 0,
            })

    catalog_version = _catalog_version() or now
    response = jsonify({
        "version":      catalog_version,
        "generated_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "titles":       titles_out,
        "episodes":     episodes_out,
    })
    response.headers["Content-Disposition"] = "attachment; filename=db_update.json"
    response.headers["Cache-Control"] = "no-cache"
    return response
