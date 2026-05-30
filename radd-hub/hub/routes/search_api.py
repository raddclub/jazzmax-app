"""RaddFlix search API — Flutter app title search.

Migrated from _watch_prototype/routes/app_search.py.
Registered in app.py at /api/search prefix.

Endpoints:
  GET /api/search?q=<term>&type=all|movie|tv&limit=30
"""
from __future__ import annotations
import json
import logging
from flask import Blueprint, request, jsonify
from hub import db

log = logging.getLogger("hub.search_api")

bp = Blueprint("search_api", __name__, url_prefix="/api/search")


@bp.route("", methods=["GET"], strict_slashes=False)
def search():
    q     = (request.args.get("q", "") or "").strip()
    kind  = (request.args.get("type", "all") or "all").lower()
    limit = min(int(request.args.get("limit", 30) or 30), 100)

    if len(q) < 2:
        return jsonify({"error": "query must be at least 2 characters", "results": []}), 400

    pattern = f"%{q}%"

    if kind == "movie":
        type_filter = "AND t.media_type = 'movie'"
    elif kind in ("tv", "show"):
        type_filter = "AND t.media_type IN ('tv', 'show', 'series')"
    else:
        type_filter = ""

    with db.conn() as c:
        rows = c.execute(f"""
            SELECT t.id AS title_id, t.title, t.year, t.media_type, t.poster,
                   t.rating, t.plot, t.overview, t.genres, t.language, t.is_free,
                   f.id AS file_id
            FROM titles t
            LEFT JOIN files f ON f.title_id = t.id
                AND (f.season IS NULL OR f.season = 0)
            WHERE t.is_published = 1
              {type_filter}
              AND (
                  t.title    LIKE ? COLLATE NOCASE
               OR t.plot     LIKE ? COLLATE NOCASE
               OR t.overview LIKE ? COLLATE NOCASE
               OR t.genres   LIKE ? COLLATE NOCASE
               OR t.language LIKE ? COLLATE NOCASE
              )
            GROUP BY t.id
            ORDER BY
                CASE WHEN t.title LIKE ? COLLATE NOCASE THEN 0 ELSE 1 END,
                t.title COLLATE NOCASE
            LIMIT ?
        """, (pattern, pattern, pattern, pattern, pattern, pattern, limit)).fetchall()

    results = []
    for r in rows:
        genres = []
        try:
            raw = r["genres"]
            if raw:
                parsed = json.loads(raw)
                genres = parsed if isinstance(parsed, list) else []
        except Exception:
            pass
        results.append({
            "id":         r["title_id"],
            "title":      r["title"],
            "year":       (int(r["year"]) if r["year"] and str(r["year"]).isdigit() else None),
            "media_type": ("show" if r["media_type"] in ("tv","series") else (r["media_type"] or "movie")),
            "poster":     r["poster"],
            "rating":     r["rating"],
            "plot":       r["plot"] or r["overview"],
            "genres":     genres,
            "language":   r["language"],
            "is_free":    1 if r["is_free"] else 0,
            "file_id":    r["file_id"],
        })

    return jsonify({"query": q, "count": len(results), "results": results})
