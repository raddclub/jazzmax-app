"""Library routes — titles, files, actor/genre/director filters, recommendations.
v3.0: Added filter_type, filter_genre, filter_dir, filter_actor, sort params,
      file_count on titles, /api/files per-title endpoint.
"""
from flask import Blueprint, render_template, request, jsonify, redirect
from .. import db, auth

bp = Blueprint("library", __name__)

_SORT_MAP = {
    "title":     "t.title ASC",
    "year_desc": "t.year DESC NULLS LAST",
    "year_asc":  "t.year ASC NULLS LAST",
    "rating":    "t.rating DESC NULLS LAST",
    "added":     "t.id DESC",
}


def _list_titles_filtered(q="", media_type="", genre="", director="", actor="",
                           sort="title", limit=200):
    """Flexible title query with optional filters. Returns list of dicts."""
    sort_clause = _SORT_MAP.get(sort, "t.title ASC")
    conditions  = []
    params      = []

    if q:
        conditions.append(
            "(t.title LIKE ? OR t.original_title LIKE ? OR t.cast_names LIKE ?)"
        )
        pat = f"%{q}%"
        params += [pat, pat, pat]
    if media_type:
        conditions.append("LOWER(t.media_type) = ?")
        params.append(media_type.lower())
    if genre:
        conditions.append("t.genres_csv LIKE ?")
        params.append(f"%{genre}%")
    if director:
        conditions.append("t.director LIKE ?")
        params.append(f"%{director}%")
    if actor:
        conditions.append("t.cast_names LIKE ?")
        params.append(f"%{actor}%")

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
    sql = f"""
        SELECT t.*,
               (SELECT COUNT(*) FROM files f WHERE f.title_id = t.id) AS file_count
        FROM   titles t
        {where}
        ORDER  BY {sort_clause}
        LIMIT  ?
    """
    params.append(limit)

    with db.conn() as c:
        try:
            rows = c.execute(sql, params).fetchall()
        except Exception:
            # Fallback: no file_count column if DB schema older
            sql2 = f"SELECT * FROM titles t {where} ORDER BY {sort_clause} LIMIT ?"
            rows = c.execute(sql2, params).fetchall()
    return [db._enrich_title(r) for r in rows]


@bp.route("/")
@auth.login_required
def page():
    q            = request.args.get("q",        "").strip()
    filter_type  = request.args.get("type",     "").strip()
    filter_genre = request.args.get("genre",    "").strip()
    filter_dir   = request.args.get("director", "").strip()
    filter_actor = request.args.get("actor",    "").strip()
    sort         = request.args.get("sort",     "title").strip()
    if sort not in _SORT_MAP:
        sort = "title"

    titles = _list_titles_filtered(
        q=q, media_type=filter_type, genre=filter_genre,
        director=filter_dir, actor=filter_actor,
        sort=sort, limit=200,
    )

    # Fetch unidentified files (those without a title_id)
    orphans = []
    if not filter_type and not filter_genre and not filter_dir and not filter_actor:
        with db.conn() as c:
            sql_orphans = "SELECT * FROM files WHERE title_id IS NULL"
            if q:
                sql_orphans += " AND filename LIKE ?"
                rows_orphans = c.execute(sql_orphans + " LIMIT 100", (f"%{q}%",)).fetchall()
            else:
                rows_orphans = c.execute(sql_orphans + " LIMIT 100").fetchall()
            orphans = [dict(r) for r in rows_orphans]

    return render_template("library.html",
        titles=titles,
        orphans=orphans,
        query=q,
        filter_type=filter_type,
        filter_genre=filter_genre,
        filter_dir=filter_dir,
        filter_actor=filter_actor,
        sort=sort,
        stats=db.count_library(),
    )


# ---------------------------------------------------------------------------
# JSON API — list / search
# ---------------------------------------------------------------------------

@bp.route("/api/list")
@auth.login_required
def api_list():
    return jsonify(db.list_titles(
        limit=int(request.args.get("limit", 200)),
        q=request.args.get("q", ""),
    ))


@bp.route("/api/title/<int:title_id>")
@auth.login_required
def api_title(title_id):
    with db.conn() as c:
        t = c.execute("SELECT * FROM titles WHERE id=?", (title_id,)).fetchone()
    if not t:
        return jsonify({"error": "not found"}), 404
    return jsonify({"title": dict(t),
                    "files": db.list_files_for_title(title_id)})


@bp.route("/api/files")
@auth.login_required
def api_files_for_title():
    """List files for a title. ?title_id=<int>"""
    title_id = request.args.get("title_id", "").strip()
    if not title_id or not title_id.isdigit():
        return jsonify({"error": "title_id required"}), 400
    try:
        files = db.list_files_for_title(int(title_id))
        return jsonify(files)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@bp.route("/api/recent")
@auth.login_required
def api_recent():
    return jsonify(db.list_files(
        limit=int(request.args.get("limit", 50)),
        source=request.args.get("source"),
    ))


@bp.route("/api/poster/<int:title_id>")
@auth.login_required
def api_poster(title_id):
    """Proxy route to generate a zero-rated direct link for a title's poster."""
    import time
    from .. import jazzdrive, turbo_cache
    
    # 1. Check Cache first
    cache_key = f"poster_{title_id}"
    cached = turbo_cache.get(cache_key, site="jazzdrive", cat="links")
    if cached:
        return redirect(cached, code=302)

    # 2. Lookup share URL in DB
    with db.conn() as c:
        row = c.execute("SELECT poster_share_url, poster FROM titles WHERE id=?", (title_id,)).fetchone()
    
    if not row or not row["poster_share_url"]:
        # Fallback to TMDB if no JD asset
        if row and row["poster"]:
             return redirect(row["poster"], code=302)
        return jsonify({"error": "poster not found"}), 404

    # 3. Generate Direct Link
    res = jazzdrive.generate_direct_link(row["poster_share_url"], target_filename="poster.jpg")
    if res.get("ok"):
        direct_link = res["direct_link"]
        # Cache (default expiry for 'links' is 24h)
        turbo_cache.set(cache_key, direct_link, site="jazzdrive", cat="links")
        return redirect(direct_link, code=302)

    return jsonify({"error": "could not generate link", "detail": res.get("error")}), 503


@bp.route("/api/user/status")
@auth.login_required
def api_user_status():
    """Return mock or real quota status for the JazzBuzz app."""
    import time
    # In a real app, this would query the 'users' table or Jazz network API
    return jsonify({
        "ok": True,
        "user": {
            "username": "Cinema Explorer",
            "tier": "Premium",
            "quota_total_gb": 10.0,
            "quota_used_gb": 4.25,
            "quota_remaining_gb": 5.75,
            "data_speed": "4G/LTE+",
            "network": "Jazz Zero-Rated",
            "is_optimized": True,
            "points": 1240,
            "expires_at": int(time.time()) + (24 * 86400)
        }
    })


# ---------------------------------------------------------------------------
# Filter endpoints (v2-compatible)
# ---------------------------------------------------------------------------

@bp.route("/api/actor")
@auth.login_required
def api_by_actor():
    """Filter library titles by actor. ?name=Shah+Rukh+Khan&limit=50"""
    name  = request.args.get("name", "").strip()
    limit = int(request.args.get("limit", 50))
    if not name:
        return jsonify({"ok": False, "error": "Missing ?name= parameter"}), 400
    with db.conn() as c:
        rows = c.execute(
            "SELECT * FROM titles WHERE cast_names LIKE ? ORDER BY rating DESC LIMIT ?",
            (f"%{name}%", limit)
        ).fetchall()
    return jsonify({"ok": True, "actor": name, "count": len(rows),
                    "results": [dict(r) for r in rows]})


@bp.route("/api/genre")
@auth.login_required
def api_by_genre():
    """Filter library titles by genre. ?name=Action&limit=50"""
    name  = request.args.get("name", "").strip()
    limit = int(request.args.get("limit", 50))
    if not name:
        return jsonify({"ok": False, "error": "Missing ?name= parameter"}), 400
    with db.conn() as c:
        rows = c.execute(
            "SELECT * FROM titles WHERE genres_csv LIKE ? ORDER BY rating DESC LIMIT ?",
            (f"%{name}%", limit)
        ).fetchall()
    return jsonify({"ok": True, "genre": name, "count": len(rows),
                    "results": [dict(r) for r in rows]})


@bp.route("/api/director")
@auth.login_required
def api_by_director():
    """Filter library titles by director. ?name=Christopher+Nolan&limit=50"""
    name  = request.args.get("name", "").strip()
    limit = int(request.args.get("limit", 50))
    if not name:
        return jsonify({"ok": False, "error": "Missing ?name= parameter"}), 400
    with db.conn() as c:
        rows = c.execute(
            "SELECT * FROM titles WHERE director LIKE ? ORDER BY rating DESC LIMIT ?",
            (f"%{name}%", limit)
        ).fetchall()
    return jsonify({"ok": True, "director": name, "count": len(rows),
                    "results": [dict(r) for r in rows]})


@bp.route("/api/has")
@auth.login_required
def api_has():
    """Check if a title is in the library. ?title=Inception&year=2010"""
    title = request.args.get("title", "").strip()
    year  = request.args.get("year", "").strip()
    if not title:
        return jsonify({"ok": False, "error": "Missing ?title= parameter"}), 400
    with db.conn() as c:
        sql  = "SELECT id, title, year, poster FROM titles WHERE title LIKE ?"
        args = [f"%{title}%"]
        if year:
            sql  += " AND year LIKE ?"
            args.append(f"{year}%")
        row = c.execute(sql, args).fetchone()
    if row:
        return jsonify({"ok": True, "has": True, "title": dict(row)})
    return jsonify({"ok": True, "has": False})


@bp.route("/api/search")
@auth.login_required
def api_search():
    """Full-text search across title, original_title, cast, director, genres.
    ?q=inception&limit=50
    """
    q     = request.args.get("q", "").strip()
    limit = int(request.args.get("limit", 50))
    if not q:
        return jsonify({"ok": False, "error": "Missing ?q= parameter"}), 400
    pat = f"%{q}%"
    with db.conn() as c:
        rows = c.execute(
            "SELECT * FROM titles WHERE "
            "title LIKE ? OR original_title LIKE ? OR cast_names LIKE ? "
            "OR director LIKE ? OR genres_csv LIKE ? "
            "ORDER BY rating DESC LIMIT ?",
            (pat, pat, pat, pat, pat, limit)
        ).fetchall()
    return jsonify({"ok": True, "query": q, "count": len(rows),
                    "results": [dict(r) for r in rows]})


# ---------------------------------------------------------------------------
# Recommendations
# ---------------------------------------------------------------------------

@bp.route("/api/recommendations")
@auth.login_required
def api_recommendations():
    """TMDB-powered recommendations.  ?limit=10"""
    limit = int(request.args.get("limit", 10))
    try:
        from .. import radd_recommend
        items = radd_recommend.get_recommendations(limit=limit)
        return jsonify({"ok": True, "count": len(items), "items": items})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e), "items": []}), 500
