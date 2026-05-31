"""RaddFlix catalog sync API — Flutter app offline-first database.

Registered in app.py at /api/catalog prefix.

Endpoints:
  GET  /api/catalog/version              current version + count
  GET  /api/catalog/db_update/version    lightweight version check
  GET  /api/catalog/sync                 full or delta catalog (JSON)
  GET  /api/catalog/posters              poster URLs for pre-caching
  GET  /api/catalog/db_update            zero-rated db_update.json
  GET  /api/catalog/delta                Oracle fallback for JazzDrive delta sync
  GET  /api/catalog/share_url            single-file share URL lookup
  POST /api/catalog/share_url/batch      batch share URL lookup (up to 50 file_ids)
  GET  /api/catalog/share_url/batch      same via ?ids=1,2,3 query param
  GET  /api/catalog/play                 generate/return cached direct streaming URL
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
            "media_type":   ("show" if (r["media_type"] or "movie") in ("tv", "series") else (r["media_type"] or "movie")),
            "description":  r["plot"] or r["overview"] or "",
            "rating":       r["rating"],
            "genres":       genres,
            "language":     r["language"] or "",
            "is_free":      1 if r["is_free"] else 0,
            "runtime":      r["runtime"],
            "season_count": r["season_count"],
            "episode_count": r["episode_count"],
            "poster_key":   "title_" + str(r["id"]),
            "poster_url":   r["poster"] or "",
            "poster_jd_url": (_watch_base() + "/api/poster/" + str(r["id"])) if r["id"] else "",
            "db_version":   int(r["updated_at"] or 0),
            "file_id":      r["file_id"],
            "share_url":    r["file_share_url"] or "",
        })

    episodes = []
    if title_ids:
        placeholders = ",".join("?" * len(title_ids))
        with db.conn() as c:
            ep_rows = c.execute(
                "SELECT id, title_id, filename, season, episode, share_url "
                "FROM files "
                "WHERE title_id IN (" + placeholders + ") "
                "AND season IS NOT NULL AND season > 0 "
                "ORDER BY title_id, season, episode",
                title_ids
            ).fetchall()
        for r in ep_rows:
            episodes.append({
                "id":       r["id"],
                "title_id": r["title_id"],
                "file_id":  str(r["id"]),
                "season":   r["season"],
                "episode":  r["episode"],
                "label":    "S{:02d}E{:02d}".format(r["season"] or 0, r["episode"] or 0),
                "share_url": r["share_url"] or "",
                "is_free":  0,
            })

    return jsonify({"version": _catalog_version(), "titles": titles,
                    "episodes": episodes, "count": len(titles)})


@bp.route("/share_url")
def get_share_url():
    """GET /api/catalog/share_url?file_id=<id>
    Returns the JazzDrive share_url for a specific file.
    Called by the Flutter player as a fallback when the local SQLite DB
    does not have the share_url (fresh install, DB corruption, or new content).
    Public endpoint.
    """
    file_id = request.args.get("file_id", "").strip()
    if not file_id:
        return jsonify({"error": "file_id required"}), 400
    try:
        with db.conn() as c:
            row = c.execute(
                "SELECT f.share_url FROM files f "
                "JOIN titles t ON f.title_id = t.id "
                "WHERE f.id=? AND t.is_published=1",
                (file_id,)
            ).fetchone()
        if row and row["share_url"]:
            return jsonify({"ok": True, "share_url": row["share_url"]})
        return jsonify({"error": "not found"}), 404
    except Exception:
        log.exception("Error in get_share_url for file_id=%s", file_id)
        return jsonify({"error": "server error"}), 500


@bp.route("/share_url/batch", methods=["POST", "GET"])
def batch_share_url():
    """Resolve JazzDrive share_urls for multiple files in one request.

    POST /api/catalog/share_url/batch
      Body: {"file_ids": [1, 2, 3, ...]}   (max 50)

    GET  /api/catalog/share_url/batch?ids=1,2,3
      Comma-separated file IDs (max 50)

    Response:
      {"ok": true, "results": {"1": "https://...", "2": null, ...},
       "found": N, "requested": M}

    Used by Flutter player queue to resolve share_urls for multiple episodes
    in a single round-trip instead of N individual /share_url calls.
    """
    if request.method == "GET":
        ids_raw = request.args.get("ids", "")
        try:
            file_ids = [int(x.strip()) for x in ids_raw.split(",") if x.strip()]
        except (ValueError, TypeError):
            return jsonify({"error": "ids must be comma-separated integers"}), 400
    else:
        data = request.get_json(force=True, silent=True) or {}
        raw_ids = data.get("file_ids") or []
        try:
            file_ids = [int(x) for x in raw_ids]
        except (TypeError, ValueError):
            return jsonify({"error": "file_ids must be a list of integers"}), 400

    if not file_ids:
        return jsonify({"error": "file_ids required"}), 400
    if len(file_ids) > 50:
        return jsonify({"error": "max 50 file_ids per request"}), 400

    try:
        placeholders = ",".join("?" * len(file_ids))
        with db.conn() as c:
            rows = c.execute(
                "SELECT f.id, f.share_url FROM files f "
                "JOIN titles t ON f.title_id = t.id "
                "WHERE f.id IN (" + placeholders + ") AND t.is_published=1",
                file_ids
            ).fetchall()
        results = {str(r["id"]): r["share_url"] or None for r in rows}
        for fid in file_ids:
            results.setdefault(str(fid), None)
        found = sum(1 for v in results.values() if v)
        return jsonify({"ok": True, "results": results, "found": found,
                        "requested": len(file_ids)})
    except Exception:
        log.exception("Error in batch_share_url")
        return jsonify({"error": "server error"}), 500


@bp.route("/play")
def play():
    """GET /api/catalog/play?file_id=<id>
    Returns a direct streamable URL for the given file.

    Checks the stream_links cache first (8-hour TTL). Generates a fresh
    direct link via JazzDrive API on cache miss or expiry.

    Response:
      {"ok": true, "file_id": 5, "direct_url": "https://...",
       "expires_at": 1234, "cached": true|false,
       "title": "Off Campus", "label": "S01E01", "size_bytes": N}
    """
    file_id_str = request.args.get("file_id", "").strip()
    if not file_id_str:
        return jsonify({"error": "file_id required"}), 400
    try:
        file_id = int(file_id_str)
    except ValueError:
        return jsonify({"error": "invalid file_id"}), 400

    try:
        cached = db.get_stream_link(file_id)
        if cached:
            return jsonify({
                "ok":        True,
                "file_id":   file_id,
                "direct_url": cached["download_url"],
                "expires_at": cached["expires_at"],
                "cached":    True,
            })

        with db.conn() as c:
            row = c.execute(
                "SELECT f.id, f.filename, f.share_url, f.account_id, "
                "       f.season, f.episode, t.title "
                "FROM files f JOIN titles t ON f.title_id = t.id "
                "WHERE f.id=? AND t.is_published=1",
                (file_id,)
            ).fetchone()

        if not row:
            return jsonify({"error": "file not found"}), 404
        if not row["share_url"]:
            return jsonify({"error": "no share_url for this file"}), 404

        from hub import jazzdrive
        res = jazzdrive.generate_direct_link(row["share_url"], row["filename"])
        if not res.get("ok"):
            return jsonify({"error": res.get("error") or "failed to generate link"}), 502

        direct_url = res["direct_link"]
        expires_in = 28800
        db.save_stream_link(file_id, direct_url,
                            expires_in=expires_in,
                            account_id=row["account_id"])

        label = None
        s = row["season"]
        e = row["episode"]
        if s and e:
            label = "S{:02d}E{:02d}".format(s or 0, e or 0)

        return jsonify({
            "ok":         True,
            "file_id":    file_id,
            "direct_url": direct_url,
            "expires_at": int(time.time()) + expires_in,
            "cached":     False,
            "title":      row["title"],
            "label":      label,
            "size_bytes": res.get("size_bytes"),
        })
    except Exception:
        log.exception("Error in play for file_id=%s", file_id)
        return jsonify({"error": "server error"}), 500


@bp.route("/posters")
def posters():
    with db.conn() as c:
        rows = c.execute(
            "SELECT id, poster FROM titles WHERE is_published=1 AND poster IS NOT NULL"
        ).fetchall()
    return jsonify({"posters": [{"key": "title_" + str(r["id"]), "url": r["poster"]}
                                for r in rows if r["poster"]]})


@bp.route("/db_update")
def db_update():
    now = int(time.time())
    with db.conn() as c:
        title_rows = c.execute(
            "SELECT t.id, t.title, t.year, t.media_type, t.plot, t.overview, "
            "       t.rating, t.genres, t.language, t.is_free, t.updated_at, "
            "       t.poster, t.poster_share_url, t.runtime, t.season_count, t.episode_count, "
            "       f.id AS file_id, f.share_url AS file_share_url "
            "FROM titles t "
            "LEFT JOIN files f ON f.title_id = t.id "
            "  AND (f.season IS NULL OR f.season = 0) "
            "WHERE t.is_published = 1 "
            "GROUP BY t.id ORDER BY t.id"
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
            "media_type":  ("show" if (r["media_type"] or "movie") in ("tv", "series") else (r["media_type"] or "movie")),
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
                "SELECT id, title_id, filename, season, episode, share_url "
                "FROM files WHERE title_id IN (" + placeholders + ") "
                "AND season IS NOT NULL AND season > 0 "
                "ORDER BY title_id, season, episode",
                title_ids
            ).fetchall()
        for r in ep_rows:
            episodes_out.append({
                "id":       r["id"],
                "title_id": r["title_id"],
                "file_id":  str(r["id"]),
                "season":   r["season"],
                "episode":  r["episode"],
                "label":    "S{:02d}E{:02d}".format(r["season"] or 0, r["episode"] or 0),
                "share_url": r["share_url"] or "",
                "quality":  None,
                "is_free":  0,
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


@bp.route("/delta")
def delta():
    """GET /api/catalog/delta
    Oracle fallback endpoint consumed by Flutter SyncService._syncFromJazzDriveDelta().
    Returns the full published catalog in db_update JSON shape,
    without Content-Disposition header so Dio parses it as JSON directly.
    """
    now = int(time.time())
    with db.conn() as c:
        title_rows = c.execute(
            "SELECT t.id, t.title, t.year, t.media_type, t.plot, t.overview, "
            "       t.rating, t.genres, t.language, t.is_free, t.updated_at, "
            "       t.poster, t.runtime, t.season_count, t.episode_count, "
            "       f.id AS file_id, f.share_url AS file_share_url "
            "FROM titles t "
            "LEFT JOIN files f ON f.title_id = t.id "
            "  AND (f.season IS NULL OR f.season = 0) "
            "WHERE t.is_published = 1 "
            "GROUP BY t.id ORDER BY t.id"
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
            "media_type":  ("show" if (r["media_type"] or "movie") in ("tv", "series") else (r["media_type"] or "movie")),
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
                "SELECT id, title_id, filename, season, episode, share_url "
                "FROM files WHERE title_id IN (" + placeholders + ") "
                "AND season IS NOT NULL AND season > 0 "
                "ORDER BY title_id, season, episode",
                title_ids
            ).fetchall()
        for r in ep_rows:
            episodes_out.append({
                "id":       r["id"],
                "title_id": r["title_id"],
                "file_id":  str(r["id"]),
                "season":   r["season"],
                "episode":  r["episode"],
                "label":    "S{:02d}E{:02d}".format(r["season"] or 0, r["episode"] or 0),
                "share_url": r["share_url"] or "",
                "quality":  None,
                "is_free":  0,
            })

    catalog_version = _catalog_version() or now
    return jsonify({
        "version":      catalog_version,
        "generated_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "titles":       titles_out,
        "episodes":     episodes_out,
    })
