"""JazzMAX catalog sync API — for Flutter app offline-first database.

The Flutter app calls these endpoints to download and keep its local
encrypted SQLite database up to date.

Endpoints:
  GET /api/catalog/version        — returns current catalog version + count
  GET /api/catalog/sync           — full catalog (JSON) or delta since ?since=<version>
  GET /api/catalog/posters        — list of poster keys the app should have cached

Version strategy: we use the maximum updated_at timestamp across all published
titles.  The app stores this number locally and sends it with sync requests to
get only rows that changed since then.
"""
from __future__ import annotations
import json
import logging
from flask import Blueprint, request, jsonify
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
    return jsonify({
        "version": _get_catalog_version(),
        "count":   _count_published(),
    })


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

    with db.conn() as c:
        title_rows = c.execute(
            """
            SELECT
                t.id, t.title, t.year, t.media_type, t.plot, t.overview,
                t.rating, t.genres, t.language, t.is_free, t.updated_at,
                t.poster, t.runtime, t.season_count, t.episode_count
            FROM titles t
            WHERE t.is_published = 1
              AND (t.updated_at IS NULL OR t.updated_at > ?)
            ORDER BY t.updated_at DESC
            """,
            (since,)
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
            "media_type":    r["media_type"] or "movie",
            "description":   r["plot"] or r["overview"] or "",
            "rating":        r["rating"],
            "genres":        genres,
            "language":      r["language"] or "",
            "is_free":       bool(r["is_free"]),
            "runtime":       r["runtime"],
            "season_count":  r["season_count"],
            "episode_count": r["episode_count"],
            "poster_key":    f"title_{r['id']}",
            "poster_url":    r["poster"] or "",
            "db_version":    int(r["updated_at"] or 0),
        })

    episodes = []
    if title_ids:
        placeholders = ",".join("?" * len(title_ids))
        with db.conn() as c:
            ep_rows = c.execute(
                f"""
                SELECT id, title_id, filename, season, episode, is_free
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
                "season":   r["season"],
                "episode":  r["episode"],
                "label":    f"S{r['season']:02d}E{r['episode']:02d}",
                "is_free":  bool(r["is_free"]) if r["is_free"] is not None else False,
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
