"""JazzMAX search API.

Endpoints:
  GET /api/search?q=<term>   — search titles by name, genre, language (no auth required)
"""
from __future__ import annotations
import json
import logging
from flask import Blueprint, request, jsonify
from hub import db

log = logging.getLogger("hub.app_search")

bp = Blueprint("app_search", __name__, url_prefix="/api/search")


@bp.route("", methods=["GET"])
def search():
    """Search published titles by title, genre, language.

    Query params:
      q        str   search term (required, min 2 chars)
      type     str   'movie' | 'tv' | 'all' (default: 'all')
      limit    int   max results (default 30, max 100)

    Returns a flat list of matching titles with enough info for the Flutter card grid.
    """
    q     = (request.args.get("q", "") or "").strip()
    kind  = (request.args.get("type", "all") or "all").lower()
    limit = min(int(request.args.get("limit", 30) or 30), 100)

    if len(q) < 2:
        return jsonify({"error": "query must be at least 2 characters", "results": []}), 400

    pattern = f"%{q}%"

    # Build media_type filter
    if kind == "movie":
        type_filter = "AND t.media_type = 'movie'"
    elif kind in ("tv", "show"):
        type_filter = "AND t.media_type = 'tv'"
    else:
        type_filter = ""

    with db.conn() as c:
        rows = c.execute(f"""
            SELECT
                t.id        AS title_id,
                t.title,
                t.year,
                t.media_type,
                t.poster,
                t.rating,
                t.plot,
                t.overview,
                t.genres,
                t.language,
                t.is_free,
                f.id        AS file_id
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
            "title_id":   r["title_id"],
            "title":      r["title"],
            "year":       r["year"],
            "type":       r["media_type"],
            "poster":     r["poster"],
            "rating":     r["rating"],
            "plot":       r["plot"] or r["overview"],
            "genres":     genres,
            "language":   r["language"],
            "is_free":    bool(r["is_free"]),
            "file_id":    r["file_id"],
        })

    return jsonify({"query": q, "count": len(results), "results": results})
