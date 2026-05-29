"""Title metadata enrichment for Radd Hub.

Sources tried in order:
  1. TMDB       — best quality, covers international movies + TV
  2. OMDB       — IMDB-backed fallback, good for older content
  3. IMDbAPI.dev — free IMDB search, no key, great for Pakistani/Punjabi/South Asian
  4. AI (Groq / Gemini / OpenAI / OpenRouter) — regional content fallback
  5. YouTube    — poster-only last resort (trailer thumbnail)
  6. Google KG  — Google Knowledge Graph (requires 'google' vault API key)

Public API
----------
enrich_title(meta, *, tmdb_key, omdb_key)  → merged dict (best-effort)
confidence_score(meta)                      → int 0-100
slug_from(title, year)                      → url-safe slug
"""
from __future__ import annotations
import json
import logging
import re
import time
from typing import Optional

log = logging.getLogger("hub.metadata")


# ---------------------------------------------------------------------------
# Slug generation
# ---------------------------------------------------------------------------

def slug_from(title: str, year: Optional[str] = None) -> str:
    """Return a URL-safe lowercase slug, e.g. 'inception-2010'."""
    s = (title or "unknown").lower()
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"[\s_]+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    if year:
        s = f"{s}-{str(year)[:4]}"
    return s[:120]


# ---------------------------------------------------------------------------
# OMDB
# ---------------------------------------------------------------------------

_OMDB_BASE = "https://www.omdbapi.com/"


def fetch_omdb(title: str, year: Optional[str] = None,
               api_key: Optional[str] = None) -> dict:
    """Fetch from OMDB API.  Returns empty dict on any failure."""
    if not api_key or not title:
        return {}
    try:
        import requests as _req
    except ImportError:
        return {}

    def _get(type_hint: str) -> dict:
        params: dict = {"apikey": api_key, "t": title,
                        "type": type_hint, "plot": "full"}
        if year:
            params["y"] = str(year)[:4]
        try:
            r = _req.get(_OMDB_BASE, params=params, timeout=10)
            d = r.json()
            return d if d.get("Response") == "True" else {}
        except Exception:
            return {}

    data = _get("movie") or _get("series")
    if not data:
        return {}
    return _parse_omdb(data)


def _parse_omdb(data: dict) -> dict:
    def _flt(s):
        try:
            return float(re.sub(r"[^0-9.]", "", str(s or "")))
        except Exception:
            return None

    genres = [g.strip() for g in (data.get("Genre") or "").split(",")
              if g.strip() and g.strip() != "N/A"]
    cast   = [{"name": n.strip()} for n in (data.get("Actors") or "").split(",")
              if n.strip() and n.strip() != "N/A"]
    director = (data.get("Director") or "").strip()
    if director == "N/A":
        director = ""

    runtime_min = None
    m = re.search(r"(\d+)", data.get("Runtime") or "")
    if m:
        runtime_min = int(m.group(1))

    imdb_rating = None
    for r in (data.get("Ratings") or []):
        if "Internet Movie Database" in r.get("Source", ""):
            try:
                imdb_rating = float(r["Value"].split("/")[0])
            except Exception:
                pass
    if not imdb_rating:
        imdb_rating = _flt(data.get("imdbRating"))

    poster = data.get("Poster") or ""
    if poster == "N/A":
        poster = ""

    season_count = None
    ts = _flt(data.get("totalSeasons"))
    if ts:
        season_count = int(ts)

    raw_year = (data.get("Year") or "")[:4]

    return {
        "title":          data.get("Title") or "",
        "original_title": data.get("Title") or "",
        "year":           raw_year,
        "release_date":   data.get("Released") or "",
        "media_type":     "tv" if data.get("Type") == "series" else "movie",
        "plot":           data.get("Plot") or "",
        "overview":       data.get("Plot") or "",
        "genres":         json.dumps(genres),
        "genres_csv":     ", ".join(genres),
        "cast":           json.dumps(cast),
        "cast_names":     ", ".join(c["name"] for c in cast),
        "director":       director,
        "runtime":        runtime_min,
        "country":        (data.get("Country") or "").split(",")[0].strip(),
        "imdb_id":        data.get("imdbID") or "",
        "omdb_id":        data.get("imdbID") or "",
        "imdb_rating":    imdb_rating,
        "poster":         poster,
        "season_count":   season_count,
        "_source":        "omdb",
    }


# ---------------------------------------------------------------------------
# TMDB
# ---------------------------------------------------------------------------

_TMDB_BASE = "https://api.themoviedb.org/3"
_TMDB_IMG  = "https://image.tmdb.org/t/p/w500"


def fetch_tmdb(title: str, year: Optional[str] = None,
               media_type: str = "movie",
               api_key: Optional[str] = None) -> dict:
    """Fetch from TMDB.  Returns empty dict on any failure."""
    if not api_key or not title:
        return {}
    try:
        import requests as _req
    except ImportError:
        return {}

    kinds = (["movie", "tv"] if media_type in ("movie", "anime", "drama")
             else ["tv", "movie"])

    for kind in kinds:
        try:
            params: dict = {"api_key": api_key, "query": title, "language": "en-US"}
            if year and kind == "movie":
                params["year"] = str(year)[:4]
            r = _req.get(f"{_TMDB_BASE}/search/{kind}", params=params, timeout=10)
            results = (r.json().get("results") or [])
            if not results:
                continue
            best = results[0]
            det  = _req.get(
                f"{_TMDB_BASE}/{kind}/{best['id']}",
                params={"api_key": api_key,
                        "append_to_response": "credits",
                        "language": "en-US"},
                timeout=10
            ).json()
            return _parse_tmdb(det, kind)
        except Exception as e:
            log.debug("fetch_tmdb(%r, %r): %s", title, kind, e)
            continue
    return {}


def _parse_tmdb(data: dict, kind: str) -> dict:
    title  = data.get("title") or data.get("name") or ""
    year   = ""
    if data.get("release_date"):
        year = data["release_date"][:4]
    elif data.get("first_air_date"):
        year = data["first_air_date"][:4]

    genres = [g["name"] for g in (data.get("genres") or []) if g.get("name")]
    credits= data.get("credits") or {}
    cast   = [{"name": c.get("name", ""), "character": c.get("character", "")}
              for c in (credits.get("cast") or [])[:12]]
    crew   = credits.get("crew") or []
    director = next((c["name"] for c in crew if c.get("job") == "Director"), "")

    poster   = data.get("poster_path") or ""
    if poster:   poster   = _TMDB_IMG + poster

    runtime = data.get("runtime") or None
    if kind == "tv":
        ep_rt = data.get("episode_run_time") or []
        if ep_rt:
            runtime = ep_rt[0]

    countries = data.get("production_countries") or []
    country   = countries[0].get("iso_3166_1", "") if countries else ""

    status_raw = (data.get("status") or "").lower().replace(" ", "_")

    return {
        "tmdb_id":        data.get("id"),
        "title":          title,
        "original_title": data.get("original_title") or data.get("original_name") or title,
        "year":           year,
        "release_date":   data.get("release_date") or data.get("first_air_date") or "",
        "media_type":     "tv" if kind == "tv" else "movie",
        "plot":           data.get("overview") or "",
        "overview":       data.get("overview") or "",
        "genres":         json.dumps(genres),
        "genres_csv":     ", ".join(genres),
        "cast":           json.dumps(cast),
        "cast_names":     ", ".join(c["name"] for c in cast),
        "cast_json":      json.dumps(cast),
        "director":       director,
        "rating":         data.get("vote_average"),
        "vote_count":     data.get("vote_count") or 0,
        "runtime":        runtime,
        "status":         status_raw,
        "country":        country,
        "poster":         poster,
        "season_count":   data.get("number_of_seasons"),
        "episode_count":  data.get("number_of_episodes"),
        "_source":        "tmdb",
    }



# ---------------------------------------------------------------------------
# IMDbAPI.dev Fallback (free, no key, great for Pakistani/Punjabi dramas)
# ---------------------------------------------------------------------------

def fetch_imdbapi(title: str, year: Optional[str] = None, media_type: str = "movie") -> dict:
    """Search IMDbAPI.dev — free API, no key needed.
    Excellent for Pakistani/Punjabi/South Asian content absent from TMDB+OMDB.
    """
    if not title:
        return {}
    
    try:
        import requests as _req
        kinds = ["movie"] if media_type in ("movie",) else ["tvSeries", "movie"]
        if media_type in ("drama", "series", "tv", "show", "anime"):
            kinds = ["tvSeries", "tvMiniSeries", "movie"]
        
        for kind in kinds:
            params = {"q": title, "type": kind}
            if year:
                params["year"] = str(year)[:4]
            
            r = _req.get(
                "https://imdbapi.dev/api/v1/titles/search",
                params=params,
                timeout=10,
                headers={"User-Agent": "RaddFlix/1.5"}
            )
            if r.status_code != 200:
                continue
            
            results = r.json()
            if not isinstance(results, list):
                results = (results or {}).get("results") or []
            
            if not results:
                continue
                
            item = results[0]
            poster = ""
            img = item.get("primaryImage") or {}
            poster = img.get("url") or item.get("poster") or item.get("image") or ""
            
            genres = item.get("genres") or []
            if isinstance(genres, list):
                genres_csv = ", ".join(g.get("text", g) if isinstance(g, dict) else str(g) for g in genres)
            else:
                genres_csv = str(genres)
            
            cast = []
            for c in (item.get("cast") or [])[:5]:
                name = c.get("name") or (c.get("fullName") or {}).get("text") or ""
                if name:
                    cast.append({"name": name})
            
            result = {
                "title": item.get("primaryTitle") or item.get("title") or title,
                "year": str(item.get("startYear") or year or "")[:4] or None,
                "media_type": "tv" if "Series" in kind or "Mini" in kind else "movie",
                "overview": item.get("plot") or item.get("description") or "",
                "plot": item.get("plot") or item.get("description") or "",
                "genres": genres,
                "genres_csv": genres_csv,
                "rating": item.get("averageRating") or item.get("rating"),
                "imdb_id": item.get("id") or item.get("tconst") or "",
                "poster": poster,
                "cast": cast,
                "cast_names": ", ".join(c["name"] for c in cast),
                "_source": "imdbapi",
            }
            if result.get("title"):
                log.debug("IMDbAPI.dev hit for %r: %s", title, result["title"])
                return result
    except Exception as e:
        log.debug("IMDbAPI.dev fetch failed for %r: %s", title, e)
    
    return {}

# ---------------------------------------------------------------------------
# YouTube Fallback (Good for Punjabi/Regional movies)
# ---------------------------------------------------------------------------

def fetch_youtube_fallback(title: str, year: Optional[str] = None) -> dict:
    """Search YouTube for a trailer and use the thumbnail as a poster."""
    if not title:
        return {}
    
    query = f"{title} {year or ''} official trailer".strip()
    search_url = f"https://www.youtube.com/results?search_query={query.replace(' ', '+')}"
    
    try:
        import requests as _req
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        }
        r = _req.get(search_url, headers=headers, timeout=15)
        html = r.text
        
        # Simple regex to find the first videoId
        import re as _re
        video_ids = _re.findall(r'"videoId":"([^"]+)"', html)
        
        if video_ids:
            v_id = video_ids[0]
            # Highest res thumbnail
            poster = f"https://img.youtube.com/vi/{v_id}/maxresdefault.jpg"
            trailer = f"https://www.youtube.com/watch?v={v_id}"
            
            # Verify thumbnail exists (maxresdefault sometimes fails, fallback to hqdefault)
            check = _req.head(poster, timeout=5)
            if check.status_code != 200:
                poster = f"https://img.youtube.com/vi/{v_id}/hqdefault.jpg"
                
            return {
                "poster": poster,
                "trailer_url": trailer,
                "_source": "youtube"
            }
    except Exception as e:
        log.debug("YouTube fallback failed for %r: %s", title, e)
    
    return {}



# ---------------------------------------------------------------------------
# Google Knowledge Graph Fallback
# ---------------------------------------------------------------------------

def fetch_google_kg(title: str, year=None, api_key: str = "") -> dict:
    """Fetch from Google Knowledge Graph API.
    Requires a Google API key with the Knowledge Graph Search API enabled.
    Add key to vault provider 'google'. Returns empty dict on failure/no key.
    """
    if not api_key or not title:
        return {}
    try:
        import requests as _req
        import urllib.parse
        q = urllib.parse.quote_plus(f"{title} {year or ''} film".strip())
        r = _req.get(
            f"https://kgsearch.googleapis.com/v1/entities:search"
            f"?query={q}&key={api_key}&limit=3"
            f"&types=Movie&types=TVSeries&types=TVEpisode",
            timeout=10,
        )
        items = (r.json().get("itemListElement") or [])
        if not items:
            return {}
        result   = items[0].get("result") or {}
        name     = result.get("name") or title
        desc     = result.get("description") or ""
        detailed = result.get("detailedDescription") or {}
        overview = detailed.get("articleBody") or desc
        img      = result.get("image") or {}
        poster   = img.get("contentUrl") or img.get("url") or ""
        types    = result.get("@type") or []
        if isinstance(types, str):
            types = [types]
        mt = "tv" if any("TV" in t or "Series" in t for t in types) else "movie"
        return {
            "title":          name,
            "original_title": name,
            "year":           str(year or "")[:4] or None,
            "media_type":     mt,
            "overview":       overview,
            "plot":           overview,
            "poster":         poster,
            "_source":        "google_kg",
        }
    except Exception as e:
        log.debug("fetch_google_kg failed for %r: %s", title, e)
    return {}


# ---------------------------------------------------------------------------
# Unified enrichment
# ---------------------------------------------------------------------------

def enrich_title(meta: dict, *,
                 tmdb_key: Optional[str] = None,
                 omdb_key: Optional[str] = None) -> dict:
    """Enrich a title dict with TMDB → OMDB → AI → YouTube (poster only).

    Source priority:
      1. TMDB  — best quality (international)
      2. OMDB  — IMDB-backed, good for older/Western titles
      3. AI    — Groq/Gemini/OpenAI/OpenRouter — regional content
                 (Pakistani/Indian/Hindi/South/Punjabi/Chinese not on TMDB+OMDB)
      4. YouTube — last resort: grab trailer thumbnail as poster image

    Never overwrites fields that already have a non-empty value.
    Returns the merged dict with updated confidence score.
    """
    title = meta.get("title") or ""
    year  = str(meta.get("year") or "")[:4] or None
    kind  = meta.get("media_type") or "movie"

    enriched: dict = {}

    # 1. TMDB (preferred)
    if tmdb_key and not meta.get("tmdb_id"):
        try:
            enriched = fetch_tmdb(title, year, kind, api_key=tmdb_key)
        except Exception as e:
            log.debug("tmdb enrich failed for %r: %s", title, e)

    # 2. OMDB (supplement missing fields)
    if omdb_key:
        needs_plot   = not (enriched.get("plot") or meta.get("plot") or meta.get("overview"))
        needs_imdb   = not (enriched.get("imdb_id") or meta.get("imdb_id"))
        needs_poster = not (enriched.get("poster") or meta.get("poster") or meta.get("poster_share_url"))
        if needs_plot or needs_imdb or needs_poster:
            try:
                omdb_data = fetch_omdb(title, year, api_key=omdb_key)
                for k, v in omdb_data.items():
                    if k not in enriched or not enriched[k]:
                        enriched[k] = v
            except Exception as e:
                log.debug("omdb enrich failed for %r: %s", title, e)

    # 3. IMDbAPI.dev — free, no key, excellent for Pakistani/Punjabi content
    needs_poster  = not (enriched.get("poster") or meta.get("poster") or meta.get("poster_share_url"))
    needs_plot3   = not (enriched.get("plot") or enriched.get("overview") or meta.get("plot") or meta.get("overview"))
    if needs_plot3 or needs_poster:
        try:
            imdb_data = fetch_imdbapi(title, year, kind)
            if imdb_data:
                log.debug("IMDbAPI fallback hit for %r", title)
                for k, v in imdb_data.items():
                    if k.startswith("_"):
                        continue
                    if k not in enriched or not enriched[k]:
                        enriched[k] = v
        except Exception as e:
            log.debug("IMDbAPI enrich failed for %r: %s", title, e)

    # 4. AI fallback — Groq → Gemini → OpenAI → OpenRouter
    #    Best for Pakistani/Indian/South/Punjabi/Chinese content absent from TMDB+OMDB
    needs_plot   = not (enriched.get("plot") or enriched.get("overview")
                        or meta.get("plot") or meta.get("overview"))
    needs_meta   = not (enriched.get("genres") or enriched.get("cast") or enriched.get("director"))
    if needs_plot or needs_meta:
        try:
            from .metadata_lookup import _ai_search as _ai_lookup
            ai_data = _ai_lookup(title, int(year) if year else None, config={})
            if ai_data:
                log.debug("AI fallback hit for %r: %s", title, ai_data.get("title"))
                for k, v in ai_data.items():
                    if k.startswith("_"):
                        continue
                    if k not in enriched or not enriched[k]:
                        enriched[k] = v
        except Exception as e:
            log.debug("AI enrich failed for %r: %s", title, e)

    # 5. YouTube — poster-only last resort (trailer thumbnail)
    if not (enriched.get("poster") or meta.get("poster") or meta.get("poster_share_url")):
        try:
            yt_data = fetch_youtube_fallback(title, year)
            for k, v in yt_data.items():
                if k not in enriched or not enriched[k]:
                    enriched[k] = v
        except Exception as e:
            log.debug("youtube poster fallback failed for %r: %s", title, e)

    # 6. Google Knowledge Graph — name/description/poster (requires 'google' vault key)
    if not (enriched.get("poster") or meta.get("poster") or meta.get("poster_share_url")
            or enriched.get("overview") or meta.get("overview") or meta.get("plot")):
        _goog_keys = []
        try:
            from . import keys as _keys_mod
            _goog_keys = _keys_mod.get_all_active_values("google")
        except Exception:
            pass
        if _goog_keys:
            try:
                gk_data = fetch_google_kg(title, year, api_key=_goog_keys[0])
                if gk_data:
                    log.debug("Google KG fallback hit for %r", title)
                    for k, v in gk_data.items():
                        if k.startswith("_"):
                            continue
                        if k not in enriched or not enriched[k]:
                            enriched[k] = v
            except Exception as e:
                log.debug("Google KG enrich failed for %r: %s", title, e)

    if not enriched:
        result = dict(meta)
    else:
        result = dict(meta)
        for k, v in enriched.items():
            if k.startswith("_"):
                continue
            existing = result.get(k)
            if existing is None or existing == "" or existing == "[]" or existing == 0:
                result[k] = v

    # Auto-tag industry based on country or language if missing
    if not result.get("industry"):
        c = (result.get("country") or "").upper()
        l = (result.get("language") or "").lower()
        t = (result.get("title") or "").lower()
        
        if c == "IN" or "hindi" in l:
            result["industry"] = "bollywood"
        elif c == "PK" or "urdu" in l:
            result["industry"] = "lollywood"
        elif c == "CN":
            result["industry"] = "chinese"
        elif c == "KR":
            result["industry"] = "korean"
        elif c == "JP":
            result["industry"] = "japanese"
        elif c in ("US", "GB", "CA", "AU") or "english" in l or not c:
            # Default to hollywood for english or unknown country if title is alphanumeric
            if "english" in l or re.match(r'^[a-z0-9\s\-\:]+$', t):
                result["industry"] = "hollywood"

    # Always regenerate slug
    t = result.get("title") or title
    y = result.get("year") or year
    if t:
        result["slug"] = slug_from(t, y)


    # ── Status normalisation + multi-source determination ─────────────────
    # Map TMDB raw status → our canonical values
    _status_map = {
        "released": "released",
        "returning_series": "ongoing",
        "in_production": "ongoing",
        "planned": "ongoing",
        "ended": "completed",
        "canceled": "cancelled",
        "cancelled": "cancelled",
        "post_production": "released",
    }
    raw_st = (result.get("status") or "").lower().replace(" ", "_")
    if raw_st in _status_map:
        result["status"] = _status_map[raw_st]

    # If still no status, use OMDB keywords in plot
    if not result.get("status"):
        plot_lower = (result.get("plot") or result.get("overview") or "").lower()
        if any(kw in plot_lower for kw in ("ongoing", "currently airing", "new episodes", "season ongoing")):
            result["status"] = "ongoing"
        elif any(kw in plot_lower for kw in ("final episode", "series finale", "ended", "concluded")):
            result["status"] = "completed"

    # Year-based heuristic for regional shows (Pakistani/Bollywood/dramas) where
    # TMDB+OMDB have no data and AI didn't return a status.
    if not result.get("status"):
        mt = (result.get("media_type") or meta.get("media_type") or "movie").lower()
        if mt == "movie":
            result["status"] = "released"
        else:
            try:
                yr = int(result.get("year") or meta.get("year") or 0)
                current_year = 2026
                if yr >= current_year - 1:
                    result["status"] = "ongoing"
                else:
                    result["status"] = "completed"
            except Exception:
                result["status"] = "released"

    # Sync is_ongoing flag with status
    result["is_ongoing"] = 1 if result.get("status") == "ongoing" else 0

    result["confidence"] = confidence_score(result)
    return result


# ---------------------------------------------------------------------------
# Confidence scoring
# ---------------------------------------------------------------------------

def confidence_score(meta: dict) -> int:
    """Return 0-100 score based on metadata completeness."""
    score = 0
    if meta.get("title"):                                  score += 15
    if meta.get("year"):                                   score += 10
    if meta.get("media_type"):                             score += 5
    if meta.get("plot") or meta.get("overview"):           score += 15
    if meta.get("genres") or meta.get("genres_csv"):       score += 10
    if meta.get("poster") or meta.get("poster_share_url"): score += 10
    if meta.get("director"):                               score += 5
    if meta.get("cast") or meta.get("cast_names"):         score += 5
    if meta.get("tmdb_id"):                                score += 10
    if meta.get("imdb_id") or meta.get("omdb_id"):         score += 5
    if meta.get("folder_share_url"):                       score += 5
    if meta.get("industry"):                               score += 5
    return min(score, 100)
