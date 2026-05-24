# JazzMAX — Next Agent Handoff

**Updated:** 2026-05-24  
**Stack:** Flutter (Android APK) + Radd Hub (Flask/Python, port 5000) + Watch Prototype (Flask, port 6000) + Oracle VM (ubuntu@92.4.95.252) + SQLite DB

---

## Access

| Resource | Detail |
|----------|--------|
| Oracle SSH | `ubuntu@92.4.95.252` key in `ORACLE_SSH_KEY` secret |
| Admin URL | `http://92.4.95.252/` |
| Admin login | user: `admin` pass: `6LQRmtOM5d1PETSI` (in `/opt/jazzmax/radd-hub/.env` as `RADD_ADMIN_PASS`) |
| GitHub | `raddclub/jazzmax-app` (public) token in `GITHUB_TOKEN` |
| DB path | `/opt/jazzmax/radd-hub/data/radd_hub.db` |
| Radd Hub src | `/opt/jazzmax/radd-hub/hub/` |
| Watch Prototype | `/opt/jazzmax/watch-prototype/` (port 6000) |

---

## Services (supervisorctl)

```bash
sudo supervisorctl status          # check all
sudo supervisorctl restart jazzmax_radd   # Radd Hub (admin panel, port 5000)
sudo supervisorctl restart jazzmax_watch  # Watch Prototype (Flutter API, port 6000)
```

---

## What Was Done (This Session — 2026-05-24)

### ✅ Nginx routing fixed
- Root cause: `/` was proxying to Watch Prototype (6000) instead of Radd Hub (5000)
- `/api/db_mgmt/` was swallowed by generic `/api/` → port 6000
- Fixed config at `/etc/nginx/sites-available/jazzmax`, also saved to `nginx/jazzmax.conf` in GitHub
- All routes verified: `/` → admin login, `/api/db_mgmt/` → Movie DB, `/app-users/` → App Users

### ✅ OMDB API keys — test_provider fix
- `test_provider()` in `keys.py` had no OMDB case → every "Test" click returned ok=False → keys showed as "invalid"
- Added OMDB test: calls `http://www.omdbapi.com/?apikey=...&t=Inception` and checks `Response=="True"`
- Reset both OMDB key statuses to `last_status='ok'` in DB

### ✅ Dashboard completely rebuilt (home.html)
- **Removed:** aria2/Chromium/AI Router health widgets (not installed on this server, showed as "not found")
- **Removed:** GitHub Mirror / Google Sheets Mirror cards (were showing "(not configured)" alarm)
- **Added:** App Users count, Active Subscriptions count, Pending TIDs count
- **Added:** System Health (Server, Watch Service, DB, API Keys)
- **Added:** JazzDrive Sessions widget
- **Added:** Recent TID Payments widget on dashboard
- Quick action "Bot Control" replaced with "App Users"

### ✅ Nav sidebar cleaned up (base.html)
- **Removed:** "Movie Database" nav link (duplicate of Media Library, ugly raw SQL browser)
- **Changed:** Media Library icon from ▤ (confusing table glyph) to 🎬
- **Updated:** Media Library subtitle to "Browse & manage catalog"

### ✅ App Users panel stats API
- Added `/app-users/api/stats` endpoint → returns total users, active subs, pending TIDs
- Used by new dashboard widget

### ✅ App Users panel (previous session, still working)
- Full CRUD at `/app-users/`
- Set subscription plan/days, activate/deactivate, delete, watch history modal

### ✅ Previous sessions (all done)
- TID panel, db_update endpoint, free titles, subscription polling UI, auto-advance player, Nginx routing

---

## Current Architecture

```
Internet
  │
Nginx (:80)
  ├── /                    → Radd Hub :5000  (admin panel)
  ├── /library/            → Radd Hub :5000  (media catalog)
  ├── /api/db_mgmt/        → Radd Hub :5000  (DB browser)
  ├── /app-users/          → Radd Hub :5000  (app users)
  ├── /tid/                → Radd Hub :5000  (TID payments)
  ├── /hub/                → Radd Hub :5000  (bot health probe)
  ├── /api/ping            → Radd Hub :5000  (heartbeat)
  ├── /api/health/         → Radd Hub :5000  (health badges)
  ├── /api/tunnel/         → Radd Hub :5000  (cloudflare tunnel)
  └── /api/                → Watch Prototype :6000  (Flutter app API)
```

---

## NEXT TASKS (Priority Order)

### 🔴 CRITICAL — Zero-Rated System

Jazz SIM users with zero internet balance can still access JazzDrive files.  
The goal: users can get catalog updates + posters WITHOUT any internet package.

#### Research needed first:
1. **Confirm zero-rated domains**: Verify that `cloud.jazzdrive.com.pk` is actually zero-rated on Jazz SIM (test with a Jazz SIM with zero balance but active JazzDrive)
2. **Understand JazzDrive share links**: Files shared via JazzDrive generate `cloud.jazzdrive.com.pk/share/f/...` links. Are these accessible zero-rated?

#### Implementation plan:
```
Step 1: Create JazzDrive "catalog" folder
  - Create a shared folder on JazzDrive called "jazzmax_catalog"
  - Upload lightweight JSON/compressed catalog file there
  - The share URL for this folder becomes the zero-rated catalog endpoint

Step 2: Catalog sync generator (Radd Hub)
  - New admin task: "Export catalog to JazzDrive"
  - Generates: catalog.json (title ID, title, year, type, poster_share_url, file_share_url)
  - Uploads to JazzDrive catalog folder
  - Stores the public share URL in settings

Step 3: Flutter app changes
  - On app launch: check last sync time
  - If > 12h: try to download catalog.json from JazzDrive URL
  - On success: merge into local SQLite DB
  - On failure: use cached local DB (works offline)
  - Poster loading: use poster_share_url from catalog (JazzDrive) → no TMDB needed

Step 4: Poster zero-rating
  - Each title in DB has poster_share_url (JazzDrive hosted image)
  - App: if Jazz network detected → use JazzDrive poster URL directly
  - App: if other network → use TMDB URL (cached locally after first load)
```

**Current DB poster fields:**
```sql
titles.poster           -- TMDB URL (requires internet)
titles.poster_share_url -- JazzDrive share URL (zero-rated)
```
Many titles are missing `poster_share_url` — need to add posters to JazzDrive and update DB.

### 🟡 HIGH — Poster System (Admin Side)

The admin needs a way to manage posters:
1. **Bulk-fill missing posters from OMDB** — one button on Movie Database page
2. **Upload poster to JazzDrive** — per-title button that uploads poster.jpg to the title's JazzDrive folder and saves the share URL to `titles.poster_share_url`
3. **Poster status view** — in library, show which titles have JD poster vs TMDB-only vs none

Currently in library.html: titles show with poster images loaded from TMDB URLs.  
When user has no internet → poster fails to load.

### 🟡 HIGH — Media Library improvements

The `/library/` page (which replaced Movie Database) needs:
1. **Edit title metadata** — click title to open edit modal (title, year, rating, genres, director, cast)  
2. **Link files to titles** — bulk-assign unidentified files to their titles
3. **Identify unidentified media** — button on orphan files to auto-search OMDB/TMDB by filename
4. **Delete title + files** — with confirmation
5. **OMDB bulk enrich** — for titles missing metadata, fetch from OMDB

### 🟠 MEDIUM — JazzDrive Database Sync Design

**Question to research/test:** Can the Flutter app download a file from a JazzDrive share URL  
(`cloud.jazzdrive.com.pk/share/f/...`) on a Jazz SIM with ZERO balance?

If yes → the entire zero-rated sync system works.  
If no → need Jazz Zero-Rating approval (contact Jazz to whitelist API domains).

**Database file format:**
```
catalog_v{timestamp}.json:
{
  "version": 1234567890,
  "titles": [
    {"id": 1, "title": "...", "year": 2024, "type": "movie", "rating": 8.5,
     "genres": ["Action"], "poster_jd": "https://cloud.jazzdrive.com.pk/share/...",
     "files": [{"id": 1, "filename": "...", "share_url": "..."}]}
  ]
}
```

**Flutter sync logic:**
```dart
Future<void> syncCatalog() async {
  final lastSync = prefs.getInt('last_catalog_sync') ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if (now - lastSync < 43200) return; // 12h cooldown
  
  final url = prefs.getString('catalog_jd_url'); // stored from API
  if (url == null) return;
  
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final catalog = jsonDecode(response.body);
      await db.mergeCatalog(catalog['titles']);
      prefs.setInt('last_catalog_sync', now);
    }
  } catch (e) {
    // Silently fail — use local DB
  }
}
```

### 🟠 MEDIUM — Flutter App Issues (from project file)

From the project requirements file, these were mentioned as working but need verification:
- `expires_at` Unix timestamp parsing
- TV episode `file_id` missing in catalog sync  
- Subscription copy button not clickable
- Guest phone auto-filled with "guest"
- **Player features to implement:** audio track switching, subtitle styling, gesture controls, brightness/volume swipe, long press speed, background audio, PiP, quality switching, sleep timer
- **My Media section:** browse device local videos, SAF picker, hidden media indexing
- **External player REMOVAL:** must disable MX Player / VLC intents completely

### 🟢 LOW — Minor Admin Panel Bugs Found

1. **is_free resets to 0 on jazzmax_radd restart** — bug in Radd Hub `init.py` overwriting free title flags. Fix: remove the init override, or persist free status properly.  
   Workaround (run after each restart):
   ```bash
   sqlite3 /opt/jazzmax/radd-hub/data/radd_hub.db "UPDATE titles SET is_free=1 WHERE id IN (4, 12, 13);"
   ```

2. **Unidentified media in library** — 16 files (All Of Us Are Dead episodes) show as orphans with no title. Need auto-identify by filename parsing (extract show name + season/episode).

3. **DB page raw browser** — `/api/db_mgmt/` still accessible but not in nav. Should either be improved with a proper UI or redirect to `/library/`.

---

## Key File Locations on Oracle

```
/opt/jazzmax/radd-hub/
├── hub/
│   ├── app.py                    -- blueprint registrations
│   ├── keys.py                   -- API key vault (OMDB test now fixed)
│   ├── routes/
│   │   ├── home.py               -- dashboard route
│   │   ├── library.py            -- media library + catalog API
│   │   ├── db_mgmt.py            -- raw DB browser (not in nav)
│   │   ├── app_users_panel.py    -- App Users CRUD + stats API
│   │   ├── tid_panel.py          -- TID payment approval
│   │   ├── settings.py           -- API keys, proxies
│   │   ├── api.py                -- health, ping, keepalive endpoints
│   │   └── scan.py               -- JazzDrive account + indexing
│   └── templates/
│       ├── base.html             -- sidebar nav, tool badges
│       ├── home.html             -- dashboard (rebuilt this session)
│       ├── library.html          -- media catalog browser
│       ├── app_users.html        -- app users panel
│       └── tid_panel.html        -- TID payments panel
├── data/radd_hub.db              -- SQLite: titles, files, app_users, tid_payments
└── .env                          -- secrets (RADD_ADMIN_PASS, FLASK_SECRET_KEY)
```

---

## DB Schema (Key Tables)

```sql
-- Movie catalog
titles(id, title, original_title, year, media_type, rating, genres_csv, director, 
       cast_names, plot, poster, poster_share_url, is_free, tmdb_id, imdb_id)
files(id, title_id, filename, size_bytes, source, share_url, jazzdrive_file_id,
      github_status, gsheets_status, scanned_at, uploaded_at)

-- App users
app_users(id, phone, device_id, is_active, created_at)
app_subscriptions(id, user_id, plan, status, expires_at, created_at)
tid_payments(id, user_id, tid, amount, status, created_at)
app_refresh_tokens(id, user_id, token, expires_at)
watch_history(id, user_id, file_id, position_sec, duration_sec, updated_at)
```

---

## SSH Key Usage Pattern (for this Replit)

```python
import os, subprocess, tempfile, stat

ssh_key = os.environ.get('ORACLE_SSH_KEY', '')
with tempfile.NamedTemporaryFile(mode='w', suffix='.pem', delete=False) as f:
    f.write(ssh_key)
    key_path = f.name
os.chmod(key_path, stat.S_IRUSR | stat.S_IWUSR)
# Reuse: save key_path to /tmp/oracle_key_path.txt

# SSH
subprocess.run(['ssh', '-i', key_path, '-o', 'StrictHostKeyChecking=no',
    'ubuntu@92.4.95.252', 'your command'], ...)

# GitHub push (via API, not git)
import urllib.request, json, base64
TOKEN = os.environ.get('GITHUB_TOKEN', '')
# PUT to https://api.github.com/repos/raddclub/jazzmax-app/contents/{path}
```

---

## Zero-Rated Research Summary

From reading the project plan:
- JazzDrive (`cloud.jazzdrive.com.pk`) may be zero-rated on Jazz SIM
- If zero-rated: app can sync catalog + posters without any internet package
- Key files needed in JazzDrive: `catalog.json` (titles metadata), `poster.jpg` per title
- Admin task needed: "Export & Upload catalog to JazzDrive"
- Flutter task: detect Jazz network, use JazzDrive URLs when zero-rated

**IMPORTANT — Test before implementing:**  
Get a Jazz SIM, zero out the balance, verify you can access JazzDrive share URLs.  
Only then implement the zero-rated sync system.

---

## Flutter App Poster Handling (Current State)

From `library.py` code: `/library/api/poster/<title_id>` route:
1. Checks `titles.poster_share_url` (JazzDrive) → generates direct link → redirect
2. Falls back to `titles.poster` (TMDB URL) → redirect
3. Returns 404 if nothing found

**Problem:** Most titles only have TMDB poster URLs, not JazzDrive poster URLs.  
**Solution:** For each title in JazzDrive, upload poster.jpg and store the share URL.

---

*Every agent must update this file when they complete work.*
