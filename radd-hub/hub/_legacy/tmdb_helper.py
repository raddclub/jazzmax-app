import os
import re
import time
import difflib
import logging
import requests
from urllib.parse import quote
log = logging.getLogger("RaddFlix.TMDB")

# S1 audit-fix: TMDB key is now read from the environment.
# The hard-coded fallback below is kept ONLY so existing local installs that
# never set up `.env` keep working.  Any production user MUST override it via
# TMDB_API_KEY in their .env (see .env.example).
_LEGACY_FALLBACK = "8a317497935478446b38c644a30e7191"
DEFAULT_TMDB_KEY = os.environ.get("TMDB_API_KEY") or _LEGACY_FALLBACK
_last_tmdb_call = 0.0
_TMDB_MIN_INTERVAL = 0.26                                            
def _tmdb_get(url):
    global _last_tmdb_call
    elapsed = time.time() - _last_tmdb_call
    if elapsed < _TMDB_MIN_INTERVAL:
        time.sleep(_TMDB_MIN_INTERVAL - elapsed)
    r = requests.get(url, timeout=10)
    _last_tmdb_call = time.time()
    return r
def clean_filename(filename):
    name = re.sub(r'\.[a-zA-Z0-9]{2,4}$', '', filename)
    name = re.sub(r'[\._\-]', ' ', name)
    patterns = [
        r'\b\d{3,4}p\b', r'\b4[kK]\b', r'\b[hH][dD][rR]\b',
        r'\b[wW][eE][bB][rR][iI][pP]\b', r'\b[bB][lL][uU][rR][aA][yY]\b',
        r'\b[xX]26[45]\b', r'\b[hH]26[45]\b', r'\b[aA][cC]3\b', r'\b[dD][dD]5 1\b',
        r'\b[dD][uU][aA][lL]\s+[aA][uU][dD][iI][oO]\b', r'\b[eE][sS][uU][bB]\b',
        r'\b[hH][cC]\b', r'\b[yY][tT][sS]\b', r'\b[rR][aA][rR][bB][gG]\b',
    ]
    for p in patterns:
        name = re.sub(p, '', name, flags=re.IGNORECASE)
    year_match = re.search(r'\b(19|20)\d{2}\b', name)
    year = year_match.group(0) if year_match else None
    if year:
        name = name.split(year)[0]
    name = re.sub(r'\s+', ' ', name).strip()
    return name, year
def best_tmdb_match(results, cleaned_title, year):
    if not results:
        return None
    cleaned_lower = cleaned_title.lower().strip()
    def score(movie):
        tmdb_title = (movie.get("title") or "").lower().strip()
        similarity = difflib.SequenceMatcher(None, cleaned_lower, tmdb_title).ratio()
        tmdb_year = (movie.get("release_date") or "")[:4]
        year_bonus = 0.2 if year and tmdb_year == str(year) else 0
        pop_bonus = min(movie.get("popularity", 0) / 1000, 0.05)
        return similarity + year_bonus + pop_bonus
    scored = sorted(results, key=score, reverse=True)
    best = scored[0]
    if score(best) < 0.4:
        log.warning("No confident TMDB match for '%s' (best score: %.2f)", cleaned_title, score(best))
        return None
    return best
def fetch_movie_metadata(filename, api_key=None):
    api_key = api_key or DEFAULT_TMDB_KEY
    title, year = clean_filename(filename)
    if not title:
        return None
    log.debug("Searching TMDB for: %s (%s)", title, year or "No Year")
    try:
        search_url = f"https://api.themoviedb.org/3/search/movie?api_key={api_key}&query={quote(title)}"
        if year:
            search_url += f"&year={year}"
        r = _tmdb_get(search_url)
        r.raise_for_status()
        results = r.json().get("results", [])
        if not results and year:
            log.debug("No results with year, trying title only...")
            r2 = _tmdb_get(f"https://api.themoviedb.org/3/search/movie?api_key={api_key}&query={quote(title)}")
            results = r2.json().get("results", [])
        if not results:
            return None
        movie = best_tmdb_match(results, title, year)
        if not movie:
            return None
        return {
            "tmdb_id": movie.get("id"),
            "title": movie.get("title"),
            "original_title": movie.get("original_title"),
            "release_date": movie.get("release_date"),
            "year": movie.get("release_date", "")[:4] if movie.get("release_date") else None,
            "rating": movie.get("vote_average"),
            "overview": movie.get("overview"),
            "poster_path": f"https://image.tmdb.org/t/p/w500{movie.get('poster_path')}" if movie.get("poster_path") else None,
            "backdrop_path": f"https://image.tmdb.org/t/p/original{movie.get('backdrop_path')}" if movie.get("backdrop_path") else None,
            "genre_ids": movie.get("genre_ids"),
        }
    except Exception as exc:
        log.error("TMDB search error for %s: %s", title, exc)
        return None
def fetch_tv_metadata(query, api_key=None):
    api_key = api_key or DEFAULT_TMDB_KEY
    title, year = clean_filename(query)
    if not title:
        return None
    log.debug("Searching TMDB TV for: %s (%s)", title, year or "No Year")
    try:
        url = f"https://api.themoviedb.org/3/search/tv?api_key={api_key}&query={quote(title)}"
        if year:
            url += f"&first_air_date_year={year}"
        r = _tmdb_get(url)
        r.raise_for_status()
        results = r.json().get("results", [])
        if not results and year:
            r2 = _tmdb_get(f"https://api.themoviedb.org/3/search/tv?api_key={api_key}&query={quote(title)}")
            results = r2.json().get("results", [])
        if not results:
            return None
        cleaned_lower = title.lower().strip()
        def tv_score(show):
            tv_title = (show.get("name") or "").lower().strip()
            similarity = difflib.SequenceMatcher(None, cleaned_lower, tv_title).ratio()
            tv_year = (show.get("first_air_date") or "")[:4]
            year_bonus = 0.2 if year and tv_year == str(year) else 0
            pop_bonus = min(show.get("popularity", 0) / 1000, 0.05)
            return similarity + year_bonus + pop_bonus
        scored = sorted(results, key=tv_score, reverse=True)
        best = scored[0]
        if tv_score(best) < 0.4:
            return None
        return {
            "tmdb_id": best.get("id"),
            "title": best.get("name"),
            "original_title": best.get("original_name"),
            "release_date": best.get("first_air_date"),
            "year": (best.get("first_air_date") or "")[:4] or None,
            "rating": best.get("vote_average"),
            "overview": best.get("overview"),
            "poster_path": f"https://image.tmdb.org/t/p/w500{best['poster_path']}" if best.get("poster_path") else None,
            "media_type": "tv",
        }
    except Exception as exc:
        log.error("TMDB TV search error for %s: %s", query, exc)
        return None
def tmdb_quick_check(query, api_key=None):
    movie = fetch_movie_metadata(query, api_key)
    if movie:
        movie["found"] = True
        movie["media_type"] = "movie"
        return movie
    tv = fetch_tv_metadata(query, api_key)
    if tv:
        tv["found"] = True
        return tv
    return {"found": False}
def fetch_full_metadata_with_credits(query, year=None, api_key=None):
    import json as _json
    api_key = api_key or DEFAULT_TMDB_KEY
    title, parsed_year = clean_filename(query)
    if not year:
        year = parsed_year
    if not title:
        return None
    POSTER_BASE = "https://image.tmdb.org/t/p/w500"
    BACKDROP_BASE = "https://image.tmdb.org/t/p/w1280"
    def _get(url):
        return _tmdb_get(url)
    def _try_movie():
        url = f"https://api.themoviedb.org/3/search/movie?api_key={api_key}&query={quote(title)}&language=en-US"
        if year:
            url += f"&year={year}"
        data = _get(url)
        results = data.get("results", [])
        if not results and year:
            data2 = _get(f"https://api.themoviedb.org/3/search/movie?api_key={api_key}&query={quote(title)}&language=en-US")
            results = data2.get("results", [])
        best = best_tmdb_match(results, title, year)
        if not best:
            return None
        mid = best["id"]
        details = _get(f"https://api.themoviedb.org/3/movie/{mid}?api_key={api_key}&language=en-US") or {}
        credits = _get(f"https://api.themoviedb.org/3/movie/{mid}/credits?api_key={api_key}&language=en-US") or {}
        cast = credits.get("cast", [])[:10]
        crew = credits.get("crew", [])
        directors = [c for c in crew if c.get("job") == "Director"]
        cast_names = ", ".join(c.get("name", "") for c in cast if c.get("name"))
        director = directors[0].get("name", "") if directors else ""
        genres = details.get("genres", [])
        genres_csv = ", ".join(g.get("name", "") for g in genres if g.get("name"))
        languages = details.get("spoken_languages", [])
        languages_csv = ", ".join(l.get("english_name") or l.get("name", "") for l in languages)
        return {
            "tmdb_id": mid, "found": True, "media_type": "movie",
            "title": best.get("title") or details.get("title") or title,
            "original_title": best.get("original_title") or "",
            "year": (best.get("release_date") or "")[:4],
            "rating": best.get("vote_average"), "vote_count": best.get("vote_count", 0),
            "overview": details.get("overview") or best.get("overview") or "",
            "poster_path": (POSTER_BASE + details["poster_path"]) if details.get("poster_path") else (
                (POSTER_BASE + best["poster_path"]) if best.get("poster_path") else ""),
            "backdrop_path": (BACKDROP_BASE + details["backdrop_path"]) if details.get("backdrop_path") else "",
            "cast_names": cast_names, "cast_json": _json.dumps([{"name": c.get("name", ""), "character": c.get("character", "")} for c in cast]),
            "director": director, "genres_csv": genres_csv, "languages_csv": languages_csv,
            "runtime": details.get("runtime"), "imdb_id": details.get("imdb_id", ""),
            "tagline": details.get("tagline", ""), "status": details.get("status", ""),
        }
    def _try_tv():
        url = f"https://api.themoviedb.org/3/search/tv?api_key={api_key}&query={quote(title)}&language=en-US"
        if year:
            url += f"&first_air_date_year={year}"
        data = _get(url)
        results = data.get("results", [])
        if not results and year:
            data2 = _get(f"https://api.themoviedb.org/3/search/tv?api_key={api_key}&query={quote(title)}&language=en-US")
            results = data2.get("results", [])
        if not results:
            return None
        best = best_tmdb_match(results, title, year)
        if not best:
            return None
        tid = best["id"]
        details = _get(f"https://api.themoviedb.org/3/tv/{tid}?api_key={api_key}&language=en-US") or {}
        credits = _get(f"https://api.themoviedb.org/3/tv/{tid}/credits?api_key={api_key}&language=en-US") or {}
        cast = credits.get("cast", [])[:10]
        crew = credits.get("crew", [])
        directors = [c for c in crew if c.get("job") in ("Director", "Creator")]
        cast_names = ", ".join(c.get("name", "") for c in cast if c.get("name"))
        director = directors[0].get("name", "") if directors else ""
        genres = details.get("genres", [])
        genres_csv = ", ".join(g.get("name", "") for g in genres if g.get("name"))
        languages = details.get("spoken_languages", [])
        languages_csv = ", ".join(l.get("english_name") or l.get("name", "") for l in languages)
        return {
            "tmdb_id": tid, "found": True, "media_type": "tv",
            "title": best.get("name") or details.get("name") or title,
            "original_title": best.get("original_name") or "",
            "year": (best.get("first_air_date") or "")[:4],
            "rating": best.get("vote_average"), "vote_count": best.get("vote_count", 0),
            "overview": details.get("overview") or best.get("overview") or "",
            "poster_path": (POSTER_BASE + details["poster_path"]) if details.get("poster_path") else (
                (POSTER_BASE + best["poster_path"]) if best.get("poster_path") else ""),
            "backdrop_path": (BACKDROP_BASE + details["backdrop_path"]) if details.get("backdrop_path") else "",
            "cast_names": cast_names, "cast_json": _json.dumps([{"name": c.get("name", ""), "character": c.get("character", "")} for c in cast]),
            "director": director, "genres_csv": genres_csv, "languages_csv": languages_csv,
            "runtime": (details.get("episode_run_time") or [None])[0],
            "total_seasons": details.get("number_of_seasons"), "status": details.get("status", ""),
        }
    result = _try_movie()
    if result:
        return result
    return _try_tv()