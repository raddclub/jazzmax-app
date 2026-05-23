# Radd Watch — Android Mobile App Plan

> Complete blueprint. Keep this updated as decisions change. Any AI agent reading this should be fully up to speed without needing extra explanation.

---

## All Questions Answered

### Can we build the Flutter app here on Replit (no PC)?
**Yes.** Flutter SDK installs on Replit (~1.5 GB, we have 27 GB free). We write all the code here. For the final APK file the user installs on their phone, we use **GitHub Actions** (free cloud build service) — it compiles the APK automatically every time we push code and makes it downloadable. No PC needed at any point.

### Should we use GitHub as the movie database mirror?
**No — this is a security risk.** GitHub repos are public. Anyone who finds your repo can download the database and build their own app. 

**The correct solution: Encrypted local SQLite in the app.** See the Database section below.

### How do users browse without internet (zero-rated)?
Users without an internet bundle cannot hit a server API. The solution is **offline-first design**:
- On first app open (any connection), the app downloads the full encrypted movie catalog to the device
- All browsing, searching, filtering happens 100% locally — zero network requests
- When any internet becomes available, the app silently syncs updates in the background
- Streaming/downloading still uses JazzDrive (zero-rated) — those links work without a bundle

### Is the subscription system possible?
**Yes, completely.** All the features requested are standard and achievable:
- Monthly subscription packages (Free / Basic / Premium)
- Device binding — one subscription = one device only
- Guest mode with limited free content
- Daily download limits
- Server controls everything — app just checks with server

---

## Chosen Language & Framework: Flutter (Dart)

| | Flutter | React Native/Expo |
|---|---|---|
| MKV + EAC3 support | ✅ `media_kit` (libVLC/MPV engine) | ⚠️ VLC plugin not Expo-compatible |
| Build on Replit | ✅ Code here, APK via GitHub Actions | ✅ Code here, APK via EAS Build |
| Future iOS | ✅ Same code, minor tweaks | ✅ Same code |
| Performance | ✅ Native-speed rendering | ⚠️ Bridge overhead |

**Flutter wins** because `media_kit` is the only cross-platform engine that properly handles MKV + EAC3 + multiple audio track switching.

---

## How APK Builds Work (No PC Needed)

```
Developer (Replit)                GitHub Actions (free cloud)
      │                                     │
      │  git push                           │
      ├────────────────────────────────────►│
      │                                     │  flutter build apk
      │                                     │  (takes ~10 minutes)
      │  Download APK link                  │
      │◄────────────────────────────────────┤
      │                                     │
      ▼                                     │
  Share APK link with users  ◄─────────────┘
```

Users install the APK directly (no Play Store needed initially).

---

## Database Strategy — Encrypted Local SQLite

### Why NOT GitHub mirror
- GitHub repos are public or semi-public
- Anyone who finds the database can extract all movie/JazzDrive data
- They can build competing apps using your content and links

### The Correct Approach: Offline-First Encrypted Sync

```
Server (our Radd Hub)                    User's App (Flutter)
        │                                        │
        │  POST /api/sync?device_id=ABC          │
        │◄───────────────────────────────────────┤
        │                                        │
        │  Returns: encrypted_catalog.db         │
        │  (AES-256, key = device_id + token)    │
        ├───────────────────────────────────────►│
        │                                        │
        │                              Save to private storage
        │                              Decrypt with device key
        │                              Open as local SQLite
        │                                        │
        │                               User browses offline ←────
        │                                        │
        │  Next sync check (on any connection)   │
        │◄───────────────────────────────────────┤
        │  Returns: { version: 47, changes: [...]}│
        ├───────────────────────────────────────►│
        │                                        │
        │                               Apply incremental changes
        │                               Re-encrypt and save
```

### Local Database Contents (what gets synced to device)
```sql
-- Only the catalog metadata — NO stream URLs, NO JazzDrive share keys
CREATE TABLE titles (
  id          INTEGER PRIMARY KEY,
  title       TEXT,
  year        INTEGER,
  media_type  TEXT,       -- 'movie' or 'show'
  description TEXT,
  rating      REAL,
  genres      TEXT,       -- JSON array
  poster_key  TEXT,       -- e.g. 'title_3' (maps to local poster file)
  is_free     INTEGER,    -- 1 = guest users can watch, 0 = subscribers only
  db_version  INTEGER     -- for incremental sync
);

CREATE TABLE episodes (
  id          INTEGER PRIMARY KEY,
  title_id    INTEGER,
  season      INTEGER,
  episode     INTEGER,
  label       TEXT,       -- "S01E02"
  is_free     INTEGER
);

-- NO share_urls, NO JazzDrive links stored locally
-- Stream URLs are generated server-side on demand, never stored in local DB
```

### Why this is secure
1. **No permanent JazzDrive links in the local DB** — stream URLs are generated server-side when the user taps Watch, then cached in `stream_cache` table for exactly 6 hours. After expiry they are deleted. The local catalog (`titles` and `episodes` tables) contains NO JazzDrive URLs — only metadata.
2. **Database is AES-256 encrypted** — the encryption key is `HMAC(device_id + auth_token + server_salt)`, unique per device
3. **Even if someone extracts the .db file** — they get an encrypted blob, useless without the key
4. **Key never stored on disk** — recomputed from device ID + token on every app launch
5. **Server controls what's in the DB** — free vs paid content flag is set server-side

---

## User Accounts & Subscription System

### Account Types

| Type | What they get |
|---|---|
| **Guest** | Browse free content only, limited catalog, 1 download/day |
| **Basic** | Full catalog streaming, 5 downloads/day, 1 device |
| **Standard** | Full catalog, 15 downloads/day, 1 device |
| **Premium** | Full catalog, unlimited downloads, 1 device, HD quality |

### Example Pricing (adjustable anytime in admin panel)
| Plan | Data | Price |
|---|---|---|
| Basic | 30 GB | Rs. 300/month |
| Standard | 70 GB | Rs. 500/month |
| Premium | 150 GB | Rs. 800/month |
| Ultra | 300 GB | Rs. 1000/month |

> These are example prices. Can be changed any time from server — no app update needed.

### Device Binding (One Subscription = One Device)

When user subscribes:
```
Server stores:
  user_id: 42
  subscription_tier: 'premium'
  bound_device_id: 'android_a1b2c3d4'  ← unique device fingerprint
  expires_at: 2026-06-22
```

When user opens the app:
```
App sends: { device_id: 'android_a1b2c3d4', auth_token: 'xxx' }
Server checks:
  - Is token valid? ✓
  - Does device_id match bound_device_id? ✓ → allow
  - Different device_id? → return 403 "Subscription is active on another device"
```

If user gets a new phone:
- They contact support (or we build a "transfer to new device" flow with a cooldown — e.g. one transfer per 30 days)

### Guest Mode
- App works without login
- Only titles with `is_free = 1` are shown in the catalog
- Guest users get 1 download per day (IP + device ID tracked server-side)
- A "Subscribe to unlock all movies" banner appears throughout the app

---

## Zero-Rated Browsing — Complete Solution

### The Problem
Jazz zero-rated users have no internet bundle. Normally they cannot hit any API server. But they need to browse the catalog and search for content.

### The Solution: Offline-First Local Database

```
Timeline:

Day 1 (user installs app, has any connection):
  → App downloads encrypted catalog (one time, ~500 KB)
  → Saves to private storage
  → User can now browse/search 100% offline forever

Any time internet is available:
  → App checks sync version in background
  → Downloads only new/changed entries (tiny delta, not full DB)
  → User never notices — it's automatic

User wants to watch (zero-rated, no bundle):
  → Browse catalog: ✓ local DB (offline)
  → Tap Watch: app calls POST /api/play/<id>
  → Request goes through JazzDrive zero-rated network ✓
  → Stream URL returned, video plays ✓

User wants to search:
  → 100% local SQLite full-text search
  → Instant results, zero network
```

### What Still Requires Connection
| Action | Needs connection? | Type |
|---|---|---|
| Browse catalog | No | Offline |
| Search | No | Offline |
| View poster images | Only first time | TMDB (free) |
| Watch/stream | Yes — but zero-rated | JazzDrive |
| Download | Yes — but zero-rated | JazzDrive |
| Login / subscribe | Yes — needs internet | Our server |
| DB sync | Optional | Our server |

---

## Video Player — Core Features

Built on `media_kit` (libVLC/MPV engine).

### Supported Formats
`.mkv`, `.mp4`, `.avi`, `.3gp`, `.webm`, `.m4v`, `.mov`, `.ts`, `.flv`

### Supported Codecs
- Video: H.264, H.265/HEVC, AV1, VP9, MPEG-4
- Audio: **EAC3 (Dolby Digital Plus)**, AC3, DTS, AAC, MP3, FLAC, TrueHD
- Subtitles: SRT, ASS/SSA, embedded MKV subtitles, PGS

### Player UI Controls (clean — MX Player + VLC feel)
```
┌─────────────────────────────────────────────────┐
│  ← Back    Movie Name                    ⋮ More │
├─────────────────────────────────────────────────┤
│                                                 │
│               ◄◄  ▶/⏸  ►►                      │
│           swipe left = brightness               │
│           swipe right = volume                  │
│           double-tap left = -10s                │
│           double-tap right = +10s               │
│                                                 │
├─────────────────────────────────────────────────┤
│  ──●────────────────────────── 00:42 / 1:52:10  │
│  🔊 English ▼    💬 Subtitles: Off ▼            │
│  ⛶ Fullscreen    ↕ Fit/Fill    🔒 Lock          │
└─────────────────────────────────────────────────┘
```

### Core Settings Only
1. Audio track selector (language names from MKV metadata)
2. Subtitle track selector + external .srt support
3. Subtitle font size (S/M/L) + background opacity
4. Playback speed (0.5× to 2×)
5. Aspect ratio (Fit / Fill / Crop / 16:9 / 4:3)
6. Swipe gestures for volume and brightness
7. Double-tap to seek ±10s
8. Screen lock button
9. Background audio (continues when screen off)
10. Resume position (remembers where you stopped)

---

## Download System — Protected & App-Only

### Storage Location
```
Android: /data/data/com.radd.watch/files/downloads/
Flutter:  getApplicationDocumentsDirectory() + '/downloads/'
```
- Not visible in file managers
- Not shareable to other apps
- Deleted only on app uninstall

### Encryption
- File downloaded as normal → then encrypted with AES-256-CBC
- Encryption key = `HMAC(device_id + user_token)` — unique per device
- Saved as `title_3.rdw` (Radd Watch Video format)
- Key stored in Android Keystore (hardware-backed, cannot be extracted)
- Playback: file decrypted into memory stream — raw video never touches disk

### Blocking Sharing
- No `FileProvider` registered for video files
- No "Open with" in the app
- "Share" button only shares a text/link — never the file

### Download Flow
```
Tap Download
  → Check subscription allows it (tier + daily limit)
  → POST /api/play/<file_id> → get JazzDrive URL
  → flutter_downloader queues download
  → Runs in background via WorkManager (survives app kill)
  → Progress shown in notification: "Downloading: Movie Name — 47%"
  → On complete: encrypt → save as .rdw → original temp file deleted
  → Appears in My Downloads
```

---

## Required Android Permissions

| Permission | Reason |
|---|---|
| INTERNET | All network requests |
| FOREGROUND_SERVICE | Keep download alive in background |
| FOREGROUND_SERVICE_DATA_SYNC | Android 14+ download service type |
| POST_NOTIFICATIONS | Download progress notifications |
| RECEIVE_BOOT_COMPLETED | Resume downloads after restart |
| WAKE_LOCK | Keep CPU alive during download |
| REQUEST_IGNORE_BATTERY_OPTIMIZATIONS | Ask user to exempt from battery saver |

---

## App Screen Structure

```
App Launch
  → Check local DB exists? → if not, download catalog (any connection)
  → Check auth token → Guest or Logged-in
  
Screens:
  Home (Catalog)
    ├── Movies grid
    ├── Shows grid
    └── Guest banner (subscribe to unlock)

  Movie / Show Detail
    ├── Poster + title + year + description + rating
    ├── [Watch] — stream (zero-rated)
    └── [Download] — save offline (zero-rated)

  Video Player (fullscreen)
    └── All controls above

  My Downloads
    ├── Downloaded titles (play offline)
    └── Download queue with progress

  Search
    └── Local full-text search (100% offline)

  Login / Register
    └── Account creation, subscription purchase

  Subscribe
    └── Plan selection + payment

  Settings
    ├── Playback defaults (preferred audio lang, subtitle)
    ├── Download quality
    ├── Storage used
    └── Logout
```

---

## Project Structure (Flutter App)

```
radd_watch_app/
  lib/
    main.dart                  ← Entry point
    app.dart                   ← MaterialApp + routing
    
    core/
      api/
        api_client.dart        ← Dio HTTP client
        auth_api.dart          ← Login, register, token refresh
        catalog_api.dart       ← Sync catalog DB, get stream URL
        subscription_api.dart  ← Plans, purchase, status
      db/
        local_db.dart          ← Encrypted SQLite (drift ORM)
        sync_service.dart      ← Background catalog sync
      security/
        encryption.dart        ← AES-256 file encryption
        device_id.dart         ← Unique device fingerprint
        keystore.dart          ← Android Keystore wrapper
      player/
        player_controller.dart ← media_kit controller
        
    features/
      catalog/
        catalog_screen.dart
        movie_card.dart
      detail/
        movie_detail_screen.dart
        show_detail_screen.dart
      player/
        player_screen.dart
        audio_track_sheet.dart
        subtitle_sheet.dart
      downloads/
        downloads_screen.dart
        download_item.dart
      auth/
        login_screen.dart
        register_screen.dart
      subscription/
        plans_screen.dart
      search/
        search_screen.dart
      settings/
        settings_screen.dart

  android/
    app/
      src/main/
        AndroidManifest.xml    ← All permissions declared here

  pubspec.yaml                 ← All dependencies
```

---

## Core Dependencies

```yaml
dependencies:
  # Video player — handles MKV, EAC3, all formats
  media_kit: ^1.1.10
  media_kit_video: ^1.1.10
  media_kit_libs_android_video: ^1.0.4  # native codec libs

  # Local encrypted database
  drift: ^2.14.0          # SQLite ORM for Flutter
  sqlite3_flutter_libs: ^0.5.20
  drift_dev: ^2.14.0

  # File encryption
  encrypt: ^5.0.3
  flutter_secure_storage: ^9.0.0   # Android Keystore

  # Downloads
  flutter_downloader: ^1.11.6
  workmanager: ^0.5.2

  # Networking
  dio: ^5.4.0
  connectivity_plus: ^6.0.3

  # Images
  cached_network_image: ^3.3.1

  # Utilities
  path_provider: ^2.1.2
  permission_handler: ^11.3.0
  wakelock_plus: ^1.2.5
  device_info_plus: ^10.1.0   # Device fingerprint for binding
  
  flutter:
    sdk: flutter
```

---

## Server-Side Changes Needed (Radd Hub)

New API endpoints to add to the Watch prototype / Radd Hub:

| Endpoint | Purpose |
|---|---|
| `POST /api/auth/register` | Create user account |
| `POST /api/auth/login` | Login, returns JWT token |
| `POST /api/auth/refresh` | Refresh expired token |
| `GET /api/catalog/sync` | Download encrypted catalog DB (or delta) |
| `GET /api/catalog/version` | Check if local DB is up to date |
| `POST /api/play/<file_id>` | Generate JazzDrive stream URL (auth required) |
| `GET /api/subscription/plans` | List available plans + prices |
| `POST /api/subscription/activate` | Activate a subscription + bind device |
| `GET /api/subscription/status` | Check current user's plan + limits |
| `GET /api/downloads/limit` | Check daily download count remaining |

---

## Development Phases

### Phase 0 — Server APIs (Do First)
- [ ] User auth (register, login, JWT)
- [ ] Device binding in subscription table
- [ ] Catalog sync endpoint (encrypted SQLite export)
- [ ] Subscription plans + daily download limit tracking
- [ ] Guest mode — mark titles as free in DB

### Phase 1 — Flutter Core
- [ ] Flutter project created on Replit
- [ ] GitHub Actions APK build pipeline set up
- [ ] API service layer (Dio)
- [ ] Local encrypted SQLite (drift)
- [ ] Catalog sync on first launch
- [ ] Home screen with poster grid
- [ ] Offline search

### Phase 2 — Video Player
- [ ] media_kit integration
- [ ] Stream link fetch + play
- [ ] Audio track switcher
- [ ] Subtitle selector
- [ ] All gesture controls
- [ ] Resume position

### Phase 3 — Downloads
- [ ] Background download (flutter_downloader)
- [ ] AES-256 encryption of downloaded files
- [ ] My Downloads screen
- [ ] Offline playback from encrypted file
- [ ] Download limits per subscription tier

### Phase 4 — Auth & Subscriptions
- [ ] Login / Register screens
- [ ] Guest mode UI
- [ ] Subscription plans screen
- [ ] Device binding enforcement
- [ ] Daily limit UI feedback

### Phase 5 — Polish & Release
- [ ] Dark theme, animations
- [ ] Battery optimization prompt
- [ ] App icon + splash screen
- [ ] ProGuard obfuscation
- [ ] Signed APK build
- [ ] Distribution

---

## Key Architecture Decisions

1. **Flutter + media_kit** — Only cross-platform option with proper MKV + EAC3 + audio track support.

2. **Offline-first local DB** — Catalog stored as encrypted SQLite on device. All browsing is offline. Zero-rated users can browse without a bundle. Only Watch/Download needs a connection.

3. **NO GitHub mirror** — GitHub is public. Database is served from our private API, encrypted per-device, contains no JazzDrive URLs.

4. **No JazzDrive URLs in local DB** — Stream links generated on-demand server-side, expire in 2 hours. Even if someone fully reverse-engineers the app, they get no usable links.

5. **AES-256 per-device encryption** — Both the catalog DB and downloaded video files are encrypted with a key derived from device ID + auth token. Moving files to another device = encrypted garbage.

6. **One device per subscription** — Device fingerprint bound to subscription at activation time. Different device = 403 error. Transfers allowed once per 30 days (prevents abuse).

7. **Guest mode controlled server-side** — Free content flag (`is_free`) is set in the DB on the server. We can change which content is free at any time without an app update.

8. **APK builds via GitHub Actions** — No PC needed. Code on Replit, push to GitHub, APK appears automatically.

9. **Incremental delta sync, not full DB download** — The catalog sync endpoint returns only rows that changed since the app's last known version. Adding 1 new movie sends ~500 bytes, not the full database.

10. **Radd Hub and Watch API share one SQLite file** — No inter-service sync needed on the server. Radd Hub writes new content → Watch API reads it immediately. Single source of truth.

---

## How New Movies Reach the App — Full Pipeline

```
Radd Hub (nightly scheduler on Oracle Ubuntu)
  ↓  finds new movie
  ↓  downloads it
  ↓  uploads to JazzDrive shared folder
  ↓  writes to SQLite (titles + files tables)
  ↓  increments catalog_version: 47 → 48
  ↓  stamps new rows with db_version = 48

Watch API (same server, same SQLite file)
  → immediately sees version 48

Mobile App (next app open OR background sync every 6 hours)
  → GET /api/catalog/version        returns { version: 48 }
  → local version is 47 → mismatch detected
  → GET /api/catalog/sync?since=47  returns only new/changed rows
  → apply delta to local encrypted SQLite
  → local_version saved as 48
  → new movie shows in catalog
```

### For zero-rated users (no bundle):
- Their local DB still works fully — they see all previously synced content
- They just won't see the newest additions until any connection becomes available
- Sync runs silently in background the moment any connection is detected
- Zero-rated JazzDrive Watch/Download still works at all times regardless

---

## Server Hosting — Oracle Ubuntu (Production)

**Current:** Replit (development and prototyping only)
**Production:** Oracle Cloud free-tier Ubuntu ARM instance

### Why Oracle Free Tier
- 4 OCPUs + 24 GB RAM (ARM) — free forever
- More than enough for thousands of users at this scale
- JazzDrive handles all video bandwidth — our server only serves API responses (tiny JSON)
- SQLite handles concurrent reads well at this user count

### What Runs on Oracle

```
Oracle Ubuntu
  ├── radd-hub/           ← Nightly content pipeline
  │     ├── scheduler     ← Downloads, uploads to JazzDrive, updates DB
  │     └── data/radd.db  ← Single SQLite (source of truth)
  │
  ├── watch-api/          ← Flask API server
  │     ├── /api/auth     ← User login, register, JWT
  │     ├── /api/catalog  ← Sync endpoint for mobile app
  │     ├── /api/play     ← JazzDrive stream link generation
  │     └── /api/sub      ← Subscription status + limits
  │
  └── nginx               ← HTTPS + reverse proxy (Let's Encrypt SSL, free)
```

Both Radd Hub and Watch API read the **same** `radd.db` file — no database sync between services needed.

### Migration Steps (Replit → Oracle, when ready)
1. Push full repo to GitHub
2. `git clone` on Oracle Ubuntu
3. Copy `radd-hub/data/radd.db` to Oracle (contains all existing content)
4. `pip install -r requirements.txt`
5. Set up nginx + Let's Encrypt SSL
6. Point Flutter app's `API_BASE_URL` to Oracle domain
7. Replit stays as dev-only environment

### Mobile App API Base URL (environment-aware)
```dart
// lib/core/api/api_client.dart
const String kApiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://radd.yourdomain.com',  // Oracle production
);

// During development, override with:
// flutter run --dart-define=API_BASE_URL=https://your-replit-url.replit.dev
```
