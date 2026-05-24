"""Streaming watch API — catalog + on-demand play link generation.

Design rule: stream URLs are generated ONLY when a user clicks play.
The catalog and episode list endpoints NEVER return stream URLs.
This prevents hammering JazzDrive and keeps the system scalable.
"""
from __future__ import annotations
import re
import time
import logging
from pathlib import Path
from flask import Blueprint, render_template, request, jsonify, send_from_directory
from hub import db

log = logging.getLogger("hub.watch")

bp = Blueprint("watch", __name__, url_prefix="/watch")

LINK_CACHE_SECONDS = 21600  # 6 hours — tested: JazzDrive links stay valid at least 6h

# ── Simple in-memory rate limiter for /api/play ───────────────────────────────
# Tracks (user_id_or_ip → list[timestamp]) — resets on server restart (acceptable).
# Limit: 20 play requests per hour per authenticated user; 5/hour for guests/anon.
import threading
_rl_lock   = threading.Lock()
_rl_store: dict[str, list[float]] = {}
_RL_WINDOW = 3600   # 1 hour in seconds
_RL_LIMIT_USER  = 20
_RL_LIMIT_GUEST = 5

def _rate_limit_key(payload: dict | None) -> str:
    """Return a string key identifying the requester for rate limiting."""
    if payload and not payload.get("is_guest") and payload.get("sub") != "guest":
        return f"u:{payload['sub']}"
    # Fall back to IP address for guests / unauthenticated requests
    return f"ip:{request.remote_addr}"

def _is_rate_limited(key: str, limit: int) -> bool:
    """Return True if this key has exceeded its limit within the rolling window."""
    now = time.time()
    with _rl_lock:
        hits = _rl_store.get(key, [])
        # Drop timestamps outside the window
        hits = [t for t in hits if now - t < _RL_WINDOW]
        if len(hits) >= limit:
            _rl_store[key] = hits
            return True
        hits.append(now)
        _rl_store[key] = hits
        return False

# Posters are saved here permanently — never fetched from JazzDrive again
POSTERS_DIR = Path(__file__).parent.parent / "posters"
POSTERS_DIR.mkdir(exist_ok=True)


# ── UI page ───────────────────────────────────────────────────────────────────

@bp.route("/")
@bp.route("")
def page():
    return render_template("watch/index.html")


# ── Serve locally-cached poster images ───────────────────────────────────────


@bp.route("/poster/<int:title_id>")
def poster_by_id(title_id: int):
    """Serve poster binary with 6-layer fallback. Cached to disk permanently."""
    from flask import send_file, Response
    import base64

    local_path = POSTERS_DIR / ("title_" + str(title_id) + ".jpg")

    if not local_path.exists():
        with db.conn() as c:
            row = c.execute(
                "SELECT id, title, year, media_type, poster, "
                "folder_share_url, poster_share_url FROM titles WHERE id=?",
                (title_id,)
            ).fetchone()

        if row:
            mt = (row["media_type"] or "").lower()
            done = False

            if not done and row["poster"]:
                done = _download_and_save(row["poster"], local_path)

            if not done:
                url = _tvmaze_poster(row["title"])
                if url:
                    done = _download_and_save(url, local_path)

            if not done:
                url = _wikipedia_poster(row["title"], row["year"])
                if url:
                    done = _download_and_save(url, local_path)

            if not done:
                if mt in ("tv", "series", "show", "anime", "drama"):
                    url = _tmdb_tv_poster(_extract_show_name(row["title"]))
                else:
                    url = _tmdb_movie_poster(row["title"], row["year"])
                if url:
                    done = _download_and_save(url, local_path)

            if not done:
                share_url = row["folder_share_url"] or row["poster_share_url"]
                if share_url:
                    try:
                        from hub import jazzdrive as _jd
                        res = _jd.generate_folder_image_link(
                            share_url, filename_hint="poster"
                        )
                        if res.get("ok") and res.get("url"):
                            _download_and_save(res["url"], local_path)
                    except Exception:
                        pass

    if not local_path.exists():
        placeholder = base64.b64decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk"
            "YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        )
        return Response(placeholder, mimetype="image/png",
                        headers={"Cache-Control": "no-store"})

    return send_file(str(local_path), mimetype="image/jpeg",
                     max_age=86400, conditional=True)


@bp.route("/poster-img/<key>")
def poster_img(key: str):
    """Serve a permanently cached poster image from disk.

    key format:  title_<title_id>   — movie poster
                 show_<file_id>     — show poster
    """
    fname = key + ".jpg"
    if not (POSTERS_DIR / fname).exists():
        return jsonify({"error": "not found"}), 404
    return send_from_directory(str(POSTERS_DIR), fname, mimetype="image/jpeg")


# ── Catalog (NO stream URLs) ──────────────────────────────────────────────────

@bp.route("/api/catalog")
def catalog():
    """Return movies + shows with metadata only. Zero stream URLs generated."""
    with db.conn() as c:
        # Movies: join titles + files (include folder_share_url for poster fetching)
        movie_rows = c.execute("""
            SELECT t.id AS title_id, t.title, t.year, t.poster,
                   t.backdrop, t.backdrop_share_url,
                   t.rating, t.plot, t.overview, t.runtime,
                   t.genres, t.language, t.trailer_url, t.is_free,
                   t.folder_share_url, t.poster_share_url,
                   f.id AS file_id
            FROM titles t
            JOIN files f ON f.title_id = t.id
            WHERE t.media_type = 'movie'
              AND (f.season IS NULL OR f.season = 0)
            GROUP BY t.id
            ORDER BY t.title COLLATE NOCASE
        """).fetchall()

    movies = []
    for r in movie_rows:
        # Check if we already have a locally-saved poster for this title
        local_key = f"title_{r['title_id']}"
        if (POSTERS_DIR / f"{local_key}.jpg").exists():
            poster = f"/watch/poster-img/{local_key}"
        else:
            poster = r["poster"]

        # Backdrop: prefer TMDB, then JazzDrive — only include if actually available
        backdrop = r["backdrop"] or r["backdrop_share_url"] or None

        movies.append({
            "title_id":         r["title_id"],
            "title":            r["title"],
            "year":             r["year"],
            "poster":           poster,
            "backdrop":         backdrop,
            "rating":           r["rating"],
            "plot":             r["plot"] or r["overview"],
            "runtime":          r["runtime"],
            "genres":           _parse_json_list(r["genres"]),
            "language":         r["language"],
            "trailer_url":      r["trailer_url"] or None,
            "is_free":          bool(r["is_free"]),
            "file_id":          r["file_id"],
            "has_folder_share": bool(r["folder_share_url"] or r["poster_share_url"]),
            "type":             "movie",
        })

    with db.conn() as c:
        # Episodes: files with season/episode set, grouped by show name
        ep_rows = c.execute("""
            SELECT id AS file_id, filename, season, episode
            FROM files
            WHERE season IS NOT NULL AND season > 0
            ORDER BY filename, season, episode
        """).fetchall()

    # Group episodes by show name
    shows: dict[str, dict] = {}
    for r in ep_rows:
        show_name = _extract_show_name(r["filename"])
        slug = _slugify(show_name)
        if slug not in shows:
            shows[slug] = {
                "slug":          slug,
                "title":         show_name,
                "poster":        None,
                "episode_count": 0,
                "first_file_id": r["file_id"],
                "type":          "show",
            }
        shows[slug]["episode_count"] += 1

    # Attach locally-saved poster for shows (if already fetched)
    for slug, show in shows.items():
        local_key = f"show_{show['first_file_id']}"
        if (POSTERS_DIR / f"{local_key}.jpg").exists():
            show["poster"] = f"/watch/poster-img/{local_key}"
        show["type"] = "show"

    return jsonify({
        "movies": movies,
        "shows":  list(shows.values()),
    })


# ── Show episodes (NO stream URLs) ───────────────────────────────────────────

@bp.route("/api/show/<slug>")
def show_episodes(slug: str):
    """Return episode list for a show. Zero stream URLs generated."""
    with db.conn() as c:
        ep_rows = c.execute("""
            SELECT id AS file_id, filename, season, episode
            FROM files
            WHERE season IS NOT NULL AND season > 0
            ORDER BY season, episode
        """).fetchall()

    episodes = []
    show_title = None
    for r in ep_rows:
        sn = _extract_show_name(r["filename"])
        if _slugify(sn) == slug:
            show_title = sn
            episodes.append({
                "file_id": r["file_id"],
                "season":  r["season"],
                "episode": r["episode"],
                "label":   f"S{r['season']:02d}E{r['episode']:02d}",
            })

    if not episodes:
        return jsonify({"error": "show not found"}), 404

    return jsonify({
        "slug":     slug,
        "title":    show_title,
        "episodes": episodes,
    })


# ── On-demand play link (generated ONLY on user click) ───────────────────────

@bp.route("/api/play/<int:file_id>", methods=["POST"])
def play(file_id: int):
    """Generate a direct stream URL for ONE file — called only when user clicks play.

    Auth rules:
      - Premium (non-free) titles → valid Bearer token required (guest token OK for
        free titles, but NOT for paid content).
      - Free titles (is_free=1) → guests may play without a token.
      - If the title is premium and the token is missing/invalid → 401.
      - Guest tokens (is_guest=True) may only play free titles.

    Caches the link in stream_links for LINK_CACHE_SECONDS to avoid re-hitting
    JazzDrive on every page reload. Each user click still goes through this endpoint.
    """
    from routes.app_auth import _verify_access_token

    # --- resolve the file and its parent title so we know is_free ----------------
    with db.conn() as c:
        file_row = c.execute(
            """SELECT f.id, f.share_url, f.title_id, f.filename,
                      COALESCE(t.is_free, 0) AS is_free
               FROM files f
               LEFT JOIN titles t ON t.id = f.title_id
               WHERE f.id = ?""",
            (file_id,)
        ).fetchone()

    if not file_row:
        return jsonify({"error": "file not found"}), 404

    share_url = file_row["share_url"]
    filename  = file_row["filename"] or ""   # used to target the correct file in the folder
    is_free   = bool(file_row["is_free"])

    if not share_url:
        return jsonify({"error": "no share URL for this file"}), 500

    # --- auth check: premium titles require a valid, non-guest token -------------
    auth_header = request.headers.get("Authorization", "")
    token = auth_header[7:] if auth_header.startswith("Bearer ") else None
    payload = _verify_access_token(token) if token else None

    is_guest = payload.get("is_guest", False) if payload else True  # no token = treat as guest

    if not is_free and is_guest:
        return jsonify({
            "error": "subscribe to watch this title",
            "code": "SUBSCRIPTION_REQUIRED",
        }), 403

    if not is_free and payload is None:
        return jsonify({
            "error": "login required to watch this title",
            "code": "AUTH_REQUIRED",
        }), 401

    # --- rate limiting -------------------------------------------------------
    rl_key   = _rate_limit_key(payload)
    rl_limit = _RL_LIMIT_GUEST if (payload is None or is_guest) else _RL_LIMIT_USER
    if _is_rate_limited(rl_key, rl_limit):
        log.warning("play(%d): rate limit hit for key=%s", file_id, rl_key)
        return jsonify({
            "error": "too many requests — please wait before playing another video",
            "code": "RATE_LIMITED",
        }), 429

    # Check cached link (avoid hitting JazzDrive again if still valid)
    now = int(time.time())
    with db.conn() as c:
        cached = c.execute(
            "SELECT download_url, expires_at FROM stream_links "
            "WHERE file_id = ? AND is_valid = 1 "
            "ORDER BY generated_at DESC LIMIT 1",
            (file_id,),
        ).fetchone()

    if cached:
        expires = cached["expires_at"] or 0
        if now < expires and cached["download_url"]:
            log.debug("play(%d): returning cached link (expires in %ds)", file_id, expires - now)
            return jsonify({"ok": True, "url": cached["download_url"], "cached": True})

    # Generate fresh link — pass filename so the right episode is targeted in the folder
    log.info("play(%d): generating fresh stream link for '%s'", file_id, filename)
    try:
        from hub import jazzdrive as jd
        result = jd.generate_direct_link(share_url, target_filename=filename)
    except Exception as e:
        log.error("play(%d): generate_direct_link error: %s", file_id, e)
        return jsonify({"error": str(e)}), 500

    if not result.get("ok"):
        return jsonify({"error": result.get("error", "link generation failed")}), 500

    # Prefer transcoded stream_url for browser <video> tag (browser-compatible codec)
    # Fall back to direct_link (raw MKV) if no transcoded stream available
    play_url   = result.get("stream_url") or result["direct_link"]
    expires_at = result.get("expires_at") or (now + LINK_CACHE_SECONDS)

    # Cache the stream link (with expires_at — required NOT NULL column)
    with db.conn() as c:
        c.execute(
            "UPDATE stream_links SET is_valid = 0 WHERE file_id = ?",
            (file_id,),
        )
        c.execute(
            "INSERT INTO stream_links "
            "(file_id, download_url, generated_at, expires_at, is_valid, account_id) "
            "VALUES (?, ?, ?, ?, 1, NULL)",
            (file_id, play_url, now, expires_at),
        )

    return jsonify({"ok": True, "url": play_url, "cached": False})


# ── Poster fetch — JazzDrive (movies) or TMDB (shows) ────────────────────────

@bp.route("/api/poster/movie/<int:title_id>")
def movie_poster(title_id: int):
    """Fetch and permanently save a poster for a movie title.

    Priority order (designed to minimise JazzDrive requests):
      1. Already on disk → serve instantly, zero network calls.
      2. TMDB movie search by title+year → free, no JazzDrive quota used.
      3. Existing TMDB URL stored in the DB → direct download.
      4. JazzDrive folder poster (poster.jpg) → last resort only.

    Once saved to disk the file is served forever from the local cache.
    The unique filename (title_<id>.jpg) prevents collisions even when
    multiple JazzDrive folders all contain a file named poster.jpg.
    """
    local_key = f"title_{title_id}"
    local_path = POSTERS_DIR / f"{local_key}.jpg"
    if local_path.exists():
        return jsonify({"ok": True, "poster_url": f"/watch/poster-img/{local_key}"})

    with db.conn() as c:
        title_row = c.execute(
            "SELECT id, title, year, folder_share_url, poster_share_url, poster "
            "FROM titles WHERE id = ?", (title_id,)
        ).fetchone()

    if not title_row:
        return jsonify({"error": "title not found"}), 404

    # ── 1. Try TMDB movie search (free, no JazzDrive quota) ───────────────────
    tmdb_url = _tmdb_movie_poster(title_row["title"], title_row["year"])
    if not tmdb_url:
        # Fall back to the URL already stored in DB (also from TMDB)
        tmdb_url = title_row["poster"]

    if tmdb_url:
        saved = _download_and_save(tmdb_url, local_path)
        if saved:
            log.info("movie_poster(%d): saved from TMDB → %s", title_id, local_path.name)
            return jsonify({"ok": True, "poster_url": f"/watch/poster-img/{local_key}"})

    # ── 2. Last resort: JazzDrive folder poster — only if TMDB failed ─────────
    share_url = title_row["folder_share_url"] or title_row["poster_share_url"]
    if share_url:
        try:
            from hub import jazzdrive as jd
            result = jd.generate_folder_image_link(share_url, filename_hint="poster")
        except Exception as e:
            log.warning("movie_poster(%d): JazzDrive image link error: %s", title_id, e)
            result = {"ok": False}

        if result.get("ok") and result.get("url"):
            saved = _download_and_save(result["url"], local_path)
            if saved:
                log.info("movie_poster(%d): saved from JazzDrive (last resort) → %s", title_id, local_path.name)
                return jsonify({"ok": True, "poster_url": f"/watch/poster-img/{local_key}"})

    return jsonify({"ok": False, "poster_url": None}), 404


@bp.route("/api/poster/show/<int:file_id>")
def show_poster(file_id: int):
    """Fetch and permanently save a TMDB poster for the show that owns this file.

    Searches TMDB TV by show name extracted from the filename, downloads the
    poster once and saves to disk — never hits TMDB again after that.
    """
    local_key = f"show_{file_id}"
    local_path = POSTERS_DIR / f"{local_key}.jpg"
    if local_path.exists():
        return jsonify({"ok": True, "poster_url": f"/watch/poster-img/{local_key}"})

    with db.conn() as c:
        file_row = c.execute(
            "SELECT filename FROM files WHERE id = ?", (file_id,)
        ).fetchone()

    if not file_row:
        return jsonify({"error": "file not found"}), 404

    show_name = _extract_show_name(file_row["filename"])
    tmdb_url = _tmdb_tv_poster(show_name)
    if not tmdb_url:
        return jsonify({"ok": False, "poster_url": None}), 404

    saved = _download_and_save(tmdb_url, local_path)
    if saved:
        log.info("show_poster(%d): saved TMDB poster for '%s' → %s", file_id, show_name, local_path.name)
        return jsonify({"ok": True, "poster_url": f"/watch/poster-img/{local_key}"})

    return jsonify({"ok": False, "poster_url": None}), 500


# ── Helpers ───────────────────────────────────────────────────────────────────

def _parse_json_list(value) -> list:
    """Safely parse a JSON array string into a Python list."""
    if not value:
        return []
    try:
        import json
        result = json.loads(value)
        return result if isinstance(result, list) else []
    except Exception:
        return []


def _extract_show_name(filename: str) -> str:
    """Extract show name from filename like 'Show Name S01E01.mkv'."""
    name = re.sub(r'\.[a-z0-9]+$', '', filename, flags=re.IGNORECASE)
    name = re.sub(r'\s*S\d{1,2}E\d{1,2}.*$', '', name, flags=re.IGNORECASE).strip()
    return name


def _slugify(text: str) -> str:
    """Convert show name to URL slug."""
    return re.sub(r'[^a-z0-9]+', '-', text.lower()).strip('-')


def _download_and_save(url: str, dest: Path) -> bool:
    """Download an image URL and save bytes to dest. Returns True on success."""
    try:
        import requests
        r = requests.get(url, timeout=20, stream=True)
        if r.status_code != 200:
            return False
        content_type = r.headers.get("content-type", "")
        if "image" not in content_type and "octet" not in content_type:
            # If content-type looks like HTML/video, skip — it's not an image
            first_bytes = b""
            for chunk in r.iter_content(32):
                first_bytes = chunk
                break
            if not first_bytes or first_bytes[:3] not in (b"\xff\xd8\xff", b"\x89PN", b"GIF"):
                return False
            dest.write_bytes(first_bytes + b"".join(r.iter_content(8192)))
            return True
        dest.write_bytes(r.content)
        return dest.stat().st_size > 1024  # sanity: must be > 1 KB
    except Exception as e:
        log.warning("_download_and_save(%s): %s", url[:60], e)
        return False


def _tmdb_movie_poster(title: str, year: int | None) -> str | None:
    """Search TMDB for a movie by title+year and return a w500 poster URL.

    Uses the free TMDB API — zero JazzDrive quota consumed.
    """
    try:
        from hub import keys as _keys, config as _cfg
        _cfg.load_env()
        tmdb_keys = _keys.get_all_active_values("tmdb")
    except Exception:
        tmdb_keys = []

    if not tmdb_keys:
        return None

    import requests
    params: dict = {"query": title, "include_adult": "false"}
    if year:
        params["year"] = year

    for api_key in tmdb_keys:
        try:
            r = requests.get(
                "https://api.themoviedb.org/3/search/movie",
                params={"api_key": api_key, **params},
                timeout=10,
            )
            results = r.json().get("results", [])
            if results and results[0].get("poster_path"):
                return f"https://image.tmdb.org/t/p/w500{results[0]['poster_path']}"
        except Exception:
            continue
    return None


def _tmdb_tv_poster(show_name: str) -> str | None:
    """Search TMDB for a TV show by name and return a w500 poster URL."""
    try:
        from hub import keys as _keys, config as _cfg
        _cfg.load_env()
        tmdb_keys = _keys.get_all_active_values("tmdb")
    except Exception:
        tmdb_keys = []

    if not tmdb_keys:
        return None

    import requests
    for api_key in tmdb_keys:
        try:
            r = requests.get(
                "https://api.themoviedb.org/3/search/tv",
                params={"api_key": api_key, "query": show_name, "include_adult": "false"},
                timeout=10,
            )
            results = r.json().get("results", [])
            if results and results[0].get("poster_path"):
                return f"https://image.tmdb.org/t/p/w500{results[0]['poster_path']}"
        except Exception:
            continue
    return None


def _tvmaze_poster(title: str):
    try:
        import requests as _req, urllib.parse as _up
        q = _up.quote(title)
        r = _req.get("https://api.tvmaze.com/singlesearch/shows?q=" + q, timeout=8)
        if r.status_code == 200:
            img = r.json().get("image") or {}
            return img.get("original") or img.get("medium")
    except Exception:
        pass
    return None


def _wikipedia_poster(title: str, year=None):
    try:
        import requests as _req, urllib.parse as _up
        base = title.replace(" ", "_")
        yr = str(year) if year else ""
        suffixes = (["_(" + yr + "_film)"] if yr else []) + [
            "_(film)", "_(TV_series)", "_(American_TV_series)", "_(television_series)", ""
        ]
        for suf in suffixes:
            slug = _up.quote(base + suf)
            r = _req.get(
                "https://en.wikipedia.org/api/rest_v1/page/summary/" + slug,
                timeout=8
            )
            if r.status_code == 200:
                th = r.json().get("thumbnail") or {}
                if th.get("source"):
                    return th["source"]
    except Exception:
        pass
    return None
