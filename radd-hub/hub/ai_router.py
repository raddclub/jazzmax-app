from __future__ import annotations
import re
import threading
import logging
from . import db, sites

log = logging.getLogger("hub.ai_router")

# ── Mirror mapping for quick lookup ──────────────────────────────────────────
_CATEGORIES = {
    "punjabi":  ["WatchMoviesPK", "RogMovies", "SSRMovies"],
    "indian":   ["RogMovies", "WatchMoviesPK", "SSRMovies"],
    "english":  ["VegaMovies", "KatMovieHD", "WatchMoviesPK", "SSRMovies"],
    "anime":    ["RareAnimes", "GokuHD", "PikaHD"],
    "both":     ["VegaMovies", "RogMovies", "KatMovieHD", "SSRMovies", "WatchMoviesPK", "GokuHD", "PikaHD"],
}

def classify_movie(title: str) -> str:
    """Classify movie title into categories for site priority."""
    t = title.lower()
    
    # ── 1. Anime Detection ───────────────────────────────────
    if any(kw in t for kw in ["one piece", "naruto", "boruto", "anime", "hentai", "episode"]):
        return "anime"
        
    # ── 2. Punjabi / Indian Detection ────────────────────────
    if any(kw in t for kw in ["ardaas", "jatt", "singh", "punjabi", "hindi", "bolly", "south", "indian"]):
        return "indian"
        
    # ── 3. Hollywood / Western ──────────────────────────────
    if any(kw in t for kw in ["batman", "avengers", "marvel", "dc", "inception", "hollywood"]):
        return "english"
        
    return "both"

def get_prioritised_sites(title: str) -> list[str]:
    cat = classify_movie(title)
    log.info("[AI Router] Classifying: '%s' -> %s", title, cat)
    return _CATEGORIES.get(cat, _CATEGORIES["both"])
