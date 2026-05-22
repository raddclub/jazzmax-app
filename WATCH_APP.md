# Radd Watch — Project Plan & Architecture

> This document exists so any future AI agent (or developer) can pick up exactly where we left off without needing a long explanation. Keep it updated as decisions change.

---

## What This App Is

**Radd Watch** is a Jazz zero-rated streaming and download app for Pakistani users. "Zero-rated" means Jazz mobile subscribers can watch movies and download them **without consuming their internet bundle** — the traffic goes through JazzDrive's zero-rated network.

Users can:
- Browse a catalog of movies and TV shows
- Watch online (stream directly in browser/app)
- Download for offline viewing
- All of the above without an active internet bundle (zero-rated)

---

## The Core Problem We Are Solving

Jazz zero-rated works via JazzDrive shared folder links. We host media files on JazzDrive, share them via folder share URLs, and generate direct stream/download links from those. As long as the link is a JazzDrive link, Jazz routes it as zero-rated traffic.

**The risk:** JazzDrive accounts have rate limits. Too many users hitting JazzDrive for images, posters, thumbnails, etc. will get the account flagged or banned. So we must be very careful about **what we use JazzDrive for** and **what we get from other sources**.

---

## JazzDrive Usage Rules

| Request type | Allowed on JazzDrive? | Alternative |
|---|---|---|
| Stream video (watch online) | YES — this is the core feature | None needed |
| Download video | YES — this is the core feature | None needed |
| Poster/thumbnail images | NO — use TMDB/OMDB instead | TMDB API (free) |
| Any image or metadata | NO | TMDB/OMDB/OMDB |

**Rule: JazzDrive is ONLY used for actual video streaming and downloading. Never for images.**

The only exception is if TMDB completely fails to provide a poster (e.g. a very obscure local title not in TMDB's database) — only then do we fall back to the JazzDrive folder poster as a last resort.

---

## Poster Image Strategy

### Why posters matter
Showing nice poster images (like Netflix does) makes the catalog look professional and helps users find what they want. We have ~18 titles currently (14 movies + 4 shows).

### The naming conflict problem
Every JazzDrive folder contains a file called `poster.jpg`. If we ever download these and save them all as `poster.jpg`, they will overwrite each other on disk. 

**Solution already implemented:** We save each poster with a unique key derived from the database ID:
- Movies: `title_{title_id}.jpg` (e.g. `title_3.jpg`)
- Shows: `show_{file_id}.jpg` (e.g. `show_10.jpg`)

This means even if 100 JazzDrive folders all have `poster.jpg`, our saved files never collide.

### Poster fetch priority order (server-side, current)

```
1. Already on disk?  → serve instantly, zero network calls
2. TMDB movie/TV search by title+year → free API, no JazzDrive used
3. TMDB URL already stored in DB → direct download
4. JazzDrive folder poster → LAST RESORT only
```

This is implemented in `_watch_prototype/routes/watch.py` in the `movie_poster()` and `show_poster()` endpoints.

### Where posters are stored (server/prototype)
```
_watch_prototype/posters/
  title_1.jpg
  title_2.jpg
  ...
  show_10.jpg
  show_34.jpg
  ...
```
These are permanent — never deleted, never expire. The server only fetches once per poster ever.

---

## Mobile App — Future Implementation Plan

When we build the mobile app (React Native / Expo), poster handling must follow these rules:

### Internet detection
```
User has active internet bundle (WiFi or mobile data) ?
  YES → fetch poster from TMDB (fast, high quality, free)
  NO  → check device local cache first
        if not cached → skip poster or show placeholder
        (do NOT use JazzDrive for posters — save JazzDrive quota for video)
```

### Hidden persistent storage
Posters must be saved to a **hidden app folder** that:
- Is NOT visible in the user's gallery or file manager
- Survives app cache clears (user clearing cache must NOT delete posters)
- Is only deleted when the user uninstalls the app

**Platform locations:**

| Platform | Where to save | How |
|---|---|---|
| Android | `Context.getFilesDir()` or `Context.getExternalFilesDir(null)` | `FileSystem.documentDirectory` in Expo |
| iOS | `Application Support` directory (not `Caches`) | `FileSystem.documentDirectory` in Expo |

In **Expo / React Native**, use:
```js
import * as FileSystem from 'expo-file-system';

const POSTER_DIR = FileSystem.documentDirectory + 'posters/';

// Save a poster (call once, never again for that title)
async function savePoster(key, imageUrl) {
  await FileSystem.makeDirectoryAsync(POSTER_DIR, { intermediates: true });
  const dest = POSTER_DIR + key + '.jpg';
  const info = await FileSystem.getInfoAsync(dest);
  if (info.exists) return dest;  // already saved, skip download
  await FileSystem.downloadAsync(imageUrl, dest);
  return dest;
}
```

`FileSystem.documentDirectory` maps to:
- Android: internal app storage (survives cache clear, deleted on uninstall)
- iOS: `Application Support` (survives cache clear, deleted on uninstall)

This is exactly the behavior we want.

### Key naming (mobile — same as server)
Use the exact same naming convention:
- Movies: `title_{title_id}.jpg`
- Shows: `show_{file_id}.jpg`

This matches the server keys so the same API response `poster_key` field can be used on both platforms without any translation.

### Mobile poster flow
```
App opens catalog screen
  → API returns list of titles, each with { poster_key, tmdb_poster_url }
  → For each card:
      localPath = POSTER_DIR + poster_key + '.jpg'
      if (localPath exists on device):
          show local image immediately
      else if (user has internet bundle):
          download from tmdb_poster_url
          save to localPath permanently
          show image
      else:
          show placeholder/skeleton
```

---

## Video Streaming & Download (Zero-Rated)

### How it works
1. User taps "Watch" or "Download"
2. App calls `POST /watch/api/play/<file_id>`
3. Server logs into JazzDrive with the file's `share_url`
4. Server returns a direct JazzDrive stream URL (valid at least 6 hours — tested)
5. App plays the stream URL in a video player (zero-rated ✓)

### Link caching
Stream links are cached in the `stream_links` DB table for 6 hours (confirmed by real-world testing — links stay valid at least 6 hours). If the user taps play again within 6 hours, the same link is returned without hitting JazzDrive again. This saves JazzDrive requests significantly.

### Download (future)
For downloads, the same `/watch/api/play/<file_id>` URL can be used with a download manager. The app should:
1. Get the stream URL from the API
2. Hand it to a background download manager
3. Save the file to device storage (user-visible, in Downloads or a Radd Watch folder)

---

## Database Structure (Key Tables)

| Table | Purpose |
|---|---|
| `titles` | Movies/shows metadata — title, year, TMDB poster URL, folder_share_url |
| `files` | Individual video files — share_url (for stream link generation), season/episode |
| `stream_links` | Cached JazzDrive stream URLs (expire every 2 hours) |
| `settings` | Key-value store for app config |

---

## API Endpoints (Watch Prototype)

| Method | Path | Purpose |
|---|---|---|
| GET | `/watch/api/catalog` | List all movies + shows with metadata |
| GET | `/watch/api/show/<slug>` | Episode list for a TV show |
| POST | `/watch/api/play/<file_id>` | Generate stream URL (JazzDrive) |
| GET | `/watch/api/poster/movie/<title_id>` | Fetch+cache movie poster |
| GET | `/watch/api/poster/show/<file_id>` | Fetch+cache show poster |
| GET | `/watch/poster-img/<key>` | Serve cached poster image from disk |

---

## Project Structure

```
workspace/
  _watch_prototype/          ← Watch app prototype (Flask)
    posters/                 ← Permanently cached poster images
      title_1.jpg            ← Movie poster (unique by DB id)
      show_10.jpg            ← Show poster (unique by DB id)
    routes/
      watch.py               ← All API endpoints + poster logic
    templates/
      watch/
        index.html           ← Frontend (HTML/JS, no framework)
    run.py                   ← Flask app entry point (port 8000)

  radd-hub/                  ← Main Radd Hub backend
    hub/
      jazzdrive.py           ← JazzDrive login + link generation
      db.py                  ← Database connection helpers
      keys.py                ← API key vault (TMDB etc.)
    data/                    ← SQLite database lives here
```

---

## Key Decisions Made

1. **TMDB first, JazzDrive last for posters** — JazzDrive quota is precious. TMDB is free. Always try TMDB first. Only hit JazzDrive for posters if TMDB has nothing.

2. **Unique poster filenames** — Even though every JazzDrive folder has `poster.jpg`, we save as `title_{id}.jpg` / `show_{id}.jpg` so files never overwrite each other.

3. **Permanent storage, no TTL** — Posters are saved once, never re-fetched. No expiry. Disk space used is tiny (~80KB per poster × 18 titles = ~1.5MB total).

4. **Stream URLs generated on-demand only** — The catalog endpoint NEVER returns stream URLs. URLs are only generated when the user actually taps play. This is the most important rule for keeping JazzDrive happy.

5. **6-hour stream link cache** — JazzDrive links stay valid for at least 6 hours (confirmed by testing). If a user pauses and resumes within 6 hours, the same link is reused. No new JazzDrive request needed.

6. **Mobile hidden storage** — Posters go into `documentDirectory` (not `cacheDirectory`) on mobile. Cache clears don't wipe them. Only an app uninstall does.

---

## Full System Architecture — How New Movies Reach Users

This is the complete data pipeline from content acquisition to the user's phone.

```
┌─────────────────────────────────────────────────────────────────┐
│                  Oracle Ubuntu Server (production)              │
│                                                                 │
│  ┌─────────────┐   downloads   ┌──────────────┐               │
│  │  Radd Hub   │ ────────────► │  JazzDrive   │               │
│  │  (scraper + │               │  (cloud host)│               │
│  │  scheduler) │               └──────┬───────┘               │
│  │             │  updates DB          │ zero-rated links       │
│  │             │ ◄────────────────────┘                       │
│  └──────┬──────┘                                               │
│         │ reads same SQLite DB                                 │
│         ▼                                                       │
│  ┌─────────────┐   serves API   ┌──────────────┐              │
│  │  Watch API  │ ──────────────►│  Mobile App  │              │
│  │  (Flask)    │                │  (Flutter)   │              │
│  └─────────────┘                └──────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

### Step-by-Step: New Movie Added

```
1. Radd Hub scheduler runs (daily/nightly)
      → Finds new movie/episode
      → Downloads it
      → Uploads to JazzDrive shared folder
      → Writes to SQLite:
            titles table: title, year, poster (TMDB), folder_share_url
            files table:  share_url, filename
      → Increments global catalog_version (e.g. 47 → 48)

2. Watch API (running on same server, same DB)
      → Immediately sees the new row — no sync needed between them
      → catalog_version endpoint now returns 48

3. Mobile app (next time user opens app or background sync triggers)
      → Calls GET /api/catalog/version → gets 48
      → Local version is 47 → needs update
      → Calls GET /api/catalog/sync?since=47
      → Server returns only the new/changed rows (tiny delta, not full DB)
      → App applies delta to local encrypted SQLite
      → Local version updated to 48
      → New movie appears in catalog immediately
```

### Catalog Version Sync (Incremental — Never Full DB Download)

Every title and episode row has a `db_version` integer stamp. When Radd Hub adds or updates content it increments a global counter and stamps affected rows.

```
Mobile app logic:
  on app open, or every 6 hours in background:
    1. GET /api/catalog/version
         → { version: 48 }
    2. if 48 != local_version (47):
         GET /api/catalog/sync?since=47
         → { version: 48, new_titles: [...], updated_titles: [...], deleted_ids: [...] }
    3. Apply changes to local SQLite
    4. Save local_version = 48
```

For a user with no internet bundle (zero-rated only), the sync just waits until any connection appears. Their existing local DB is still fully usable in the meantime — they just won't see the newest additions until sync runs.

---

## Hosting Plan — Oracle Ubuntu (Production)

**Current:** Replit (development/prototype only)
**Production target:** Oracle Cloud free-tier Ubuntu instance

### What Runs on Oracle Ubuntu

```
Oracle Ubuntu Instance
  ├── radd-hub/           ← Content pipeline (downloads, JazzDrive upload, DB updates)
  │     └── scheduler      ← Runs nightly: scans for new content, uploads, updates DB
  │
  ├── watch-api/          ← Flask API server (nginx reverse proxy in front)
  │     ├── /api/auth/*   ← User accounts, JWT tokens
  │     ├── /api/catalog/ ← Sync endpoint for mobile app
  │     ├── /api/play/    ← JazzDrive stream link generation
  │     └── /api/sub/     ← Subscription status + limits
  │
  ├── data/radd.db        ← Single SQLite database (shared by both above)
  └── nginx               ← HTTPS termination, reverse proxy
```

### Migration Steps (Replit → Oracle)
1. `git push` the full repo to GitHub
2. `git clone` on Oracle Ubuntu instance
3. Copy `radd-hub/data/` (the SQLite DB with all existing content) to Oracle
4. Install Python deps: `pip install -r requirements.txt`
5. Set up nginx as reverse proxy with SSL (Let's Encrypt, free)
6. Set `RADD_API_BASE_URL` in the Flutter app to point to Oracle domain
7. Done — Replit becomes dev-only environment

### Why Oracle Free Tier Works
- Oracle free tier: 4 OCPUs + 24 GB RAM on ARM — more than enough
- SQLite handles thousands of concurrent reads easily for this scale
- No database server to manage (SQLite file = the DB)
- JazzDrive handles all video bandwidth — Oracle instance only serves API responses (tiny)

---

## What Needs to Be Built Next

- [ ] Add `db_version` column + global version counter to SQLite schema
- [ ] `GET /api/catalog/version` endpoint
- [ ] `GET /api/catalog/sync?since=<version>` endpoint (delta sync)
- [ ] User auth endpoints (register, login, JWT)
- [ ] Subscription + device binding tables and endpoints
- [ ] Flutter mobile app (Phase 1 — see MOBILE_APP_PLAN.md)
- [ ] GitHub Actions APK build pipeline
- [ ] Oracle Ubuntu setup + nginx + SSL
- [ ] Radd Hub scheduler integration (stamp db_version on new rows)
