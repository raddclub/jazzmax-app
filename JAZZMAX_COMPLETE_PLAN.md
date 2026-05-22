# JazzMAX — Complete System Plan & Architecture

> **App:** JazzMAX — Jazz zero-rated streaming & download app for Pakistan  
> **Status:** Watch Prototype running. Flutter app planned. Production on Oracle Ubuntu (free tier).  
> **Last updated:** May 2026

---

## 1. What JazzMAX Is

JazzMAX is a streaming app for **Jazz SIM users in Pakistan**. All video content is hosted on **JazzDrive** (Jazz's cloud storage). Jazz SIM users access JazzDrive content without using their internet bundle (zero-rated). This makes premium entertainment effectively free for Jazz subscribers.

**Core value proposition:**  
"Watch unlimited movies and TV shows without using your data — for Jazz users."

---

## 2. Current Working Components

| Component | Status | Port | Entry Point |
|---|---|---|---|
| Watch Prototype (Flask) | ✅ Running | 8000 | `_watch_prototype/run.py` |
| Radd Hub (admin backend) | ✅ Running | 5000 | `radd-hub/radd_hub.py` |
| SQLite Database | ✅ Working | — | `radd-hub/data/` |
| JazzDrive link generation | ✅ Working | — | `radd-hub/hub/jazzdrive.py` |

**Content in DB right now:** 14 movies, 4 TV shows  
**Poster strategy:** TMDB API (free) → local disk cache → JazzDrive (last resort only)

---

## 3. Tech Stack

### Backend (Python)
- **Flask** — web framework
- **SQLite** → will migrate to PostgreSQL on Oracle Ubuntu
- **JazzDrive API** — proprietary link generation in `jazzdrive.py`
- **TMDB API** — all poster & backdrop images
- **Stream link cache** — 6 hours (JazzDrive links confirmed valid ≥6h)

### Frontend (Web prototype)
- **Swiper.js 11** — touch carousels (CDN)
- **GSAP 3.12** — animations (CDN)
- **Jinja2** — server-side templates

### Mobile App (Flutter — planned)
- **Flutter** (Dart) — cross-platform, Android APK first
- **media_kit** — video player (supports MKV, EAC3, multiple audio tracks, subtitles)
- **Drift** — encrypted local SQLite (offline-first catalog)
- **Riverpod** — state management / dependency injection
- **Dio** — HTTP client
- **flutter_secure_storage** — JWT token storage
- **AES-256** — encrypted .rdw download files

---

## 4. JazzDrive Rules (CRITICAL)

```
JazzDrive = VIDEO streaming and downloads ONLY.
NEVER use JazzDrive for images (posters, backdrops, thumbnails).
All images come from TMDB or are cached locally.
```

**Why:** JazzDrive image links are slow to generate, expire quickly, and aren't zero-rated for images. TMDB is free, fast, and has every poster.

**Episode fix (done):** All episodes share the same folder `share_url`. The fix passes `target_filename=filename` to `generate_direct_link()` so it targets the correct file in the folder.

---

## 5. Database Schema (Current SQLite)

### `titles` table
```sql
id, title, year, media_type (movie/show), poster, backdrop, backdrop_share_url,
rating, plot, overview, runtime, genres (JSON array), language,
trailer_url, is_free, folder_share_url, poster_share_url
```

### `files` table
```sql
id, title_id (FK), filename, file_id (JazzDrive), share_url (folder),
season, episode, size_mb, duration_seconds, quality (480p/720p/1080p)
```

### Tables to ADD for production:
```sql
-- Users
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  phone TEXT UNIQUE,           -- Jazz phone number
  email TEXT UNIQUE,
  password_hash TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  is_active BOOLEAN DEFAULT 1,
  jazz_verified BOOLEAN DEFAULT 0  -- confirmed Jazz SIM
);

-- Subscriptions
CREATE TABLE subscriptions (
  id INTEGER PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  plan TEXT CHECK(plan IN ('free','basic','premium','jazz_bundle')),
  status TEXT CHECK(status IN ('active','expired','cancelled')),
  started_at TIMESTAMP,
  expires_at TIMESTAMP,
  device_limit INTEGER DEFAULT 1,
  auto_renew BOOLEAN DEFAULT 1
);

-- Devices (device binding)
CREATE TABLE devices (
  id INTEGER PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  device_id TEXT NOT NULL,       -- unique fingerprint
  device_name TEXT,              -- "Galaxy S24", "Vivo Y36"
  platform TEXT,                 -- android/ios/web
  last_seen TIMESTAMP,
  is_active BOOLEAN DEFAULT 1
);

-- Watch History + Progress
CREATE TABLE watch_history (
  id INTEGER PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  file_id INTEGER REFERENCES files(id),
  progress_seconds INTEGER DEFAULT 0,
  duration_seconds INTEGER,
  completed BOOLEAN DEFAULT 0,
  watched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Cached stream links
CREATE TABLE stream_cache (
  file_id INTEGER PRIMARY KEY REFERENCES files(id),
  stream_url TEXT,
  cached_at TIMESTAMP,
  expires_at TIMESTAMP
);

-- Download tracking
CREATE TABLE downloads (
  id INTEGER PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  file_id INTEGER REFERENCES files(id),
  status TEXT CHECK(status IN ('queued','downloading','complete','failed')),
  local_path TEXT,              -- encrypted .rdw file path on device
  downloaded_at TIMESTAMP
);
```

---

## 6. Authentication & Login — Full Flow

### 6.1 Registration Options

**Option A — Phone (Primary):**
1. User enters Jazz mobile number (03xx-xxxxxxx)
2. Server sends OTP via Jazz SMS API (or Twilio as fallback)
3. User enters 6-digit OTP
4. Account created, jazz_verified = true
5. Auto-detects if user is on Jazz network (zero-rated content unlocked)
6. JWT access + refresh tokens issued

**Option B — Email/Password (Secondary):**
1. User enters email + password
2. Email verified via link
3. Account created, jazz_verified = false (no zero-rating benefit)
4. JWT tokens issued

### 6.2 JWT Token Strategy

```
Access Token:  15 minutes expiry    → stored in memory (Riverpod state)
Refresh Token: 30 days expiry       → stored in flutter_secure_storage
```

**Token refresh flow:**  
When access token expires → app automatically uses refresh token → gets new access token → user never sees a login prompt.

**Security:**  
- Tokens are signed with `SECRET_KEY` (env var, never in code)
- Refresh tokens are hashed in DB — if stolen and revoked remotely, they stop working
- Device ID sent with every request — server validates device is registered

### 6.3 Device Binding

Each plan allows N devices:
- Free: 1 device
- Basic: 1 device
- Premium: 2 devices
- Jazz Bundle: 2 devices

**How it works:**
1. On first login, device fingerprint (hardware ID + install ID) is registered
2. Server checks: is this device registered for this user?
3. If user already has max devices → show "Manage devices" screen
4. User can remotely deactivate old devices

### 6.4 Session Security

- All video stream requests require valid access token
- Stream URL is tied to the requesting user's ID — cannot be shared
- JazzDrive link generation happens server-side only — URLs never stored in the app long-term
- Rate limiting: max 10 stream requests per hour per user

---

## 7. Subscription Plans

| Plan | Price | Devices | Quality | Downloads | Zero-rating |
|---|---|---|---|---|---|
| **Free** | PKR 0 | 1 | 480p | ✗ | Videos only |
| **Basic** | PKR 149/mo | 1 | 720p | 3/month | ✅ All content |
| **Premium** | PKR 299/mo | 2 | 1080p | Unlimited | ✅ All content |
| **Jazz Bundle** | Via Jazz bill | 2 | 1080p | Unlimited | ✅ Priority |

**Payment integration (planned):**
- JazzCash API (primary — Jazz users already have JazzCash)
- Easypaisa (secondary)
- Credit/debit card via Stripe (for non-Jazz users)

**Free tier limits:**
- Can watch `is_free = true` content only
- 3 titles per day max
- No downloads
- Lower quality stream

---

## 8. API Endpoints — Complete List

### Auth
```
POST /api/auth/register          Body: {phone, password}
POST /api/auth/login             Body: {phone, password} → {access_token, refresh_token}
POST /api/auth/otp/send          Body: {phone}
POST /api/auth/otp/verify        Body: {phone, otp} → {access_token, refresh_token}
POST /api/auth/refresh           Header: Bearer <refresh_token> → {access_token}
POST /api/auth/logout            Revokes refresh token
GET  /api/auth/me                Returns user profile + subscription
```

### Catalog (mobile sync)
```
GET  /api/catalog                Returns movies + shows (public, limited for free)
GET  /api/catalog/version        Returns {version: "20260522-001", count: 18}
GET  /api/catalog/sync?since=V   Returns only titles changed since version V (delta sync)
```

### Content
```
GET  /api/show/:slug             Returns show + all episodes
POST /api/play/:file_id          Generates JazzDrive stream link (auth required for premium)
GET  /api/search?q=term          Full-text search
```

### User
```
GET  /api/history                Watch history for current user
POST /api/history/:file_id       Update progress: {progress_seconds, completed}
GET  /api/devices                List registered devices
DELETE /api/devices/:id          Remove a device
GET  /api/downloads              List downloads (mobile app only)
POST /api/downloads/:file_id     Queue a download
```

### Admin (Radd Hub only — internal)
```
POST /api/admin/titles           Add new title with JazzDrive links
PUT  /api/admin/titles/:id       Update title metadata
POST /api/admin/scrape/tmdb/:id  Pull metadata from TMDB for a title
POST /api/admin/poster/:id       Fetch & cache poster from JazzDrive
```

---

## 9. Mobile App (Flutter) — Architecture

### Screens
```
SplashScreen       → Check token → route to Home or Login
OnboardingScreen   → First launch only — explain zero-rating benefit
LoginScreen        → Phone + OTP or Email + Password
HomeScreen         → Featured showcase + content rows (bottom nav)
SearchScreen       → Live search + filters
DetailScreen       → Full info + Watch + Download buttons
PlayerScreen       → Full-screen video (media_kit)
DownloadsScreen    → Offline downloads list
ProfileScreen      → Account info + subscription + device management
```

### Offline-First Architecture
```
App launch → Load from local SQLite (instant)
           → Fetch /api/catalog/version in background
           → If version changed → sync delta from /api/catalog/sync
           → Update local SQLite
           → Refresh UI
```

This means users always see content immediately, even with no internet.

### Encrypted Downloads (.rdw format)
```
1. App requests download from /api/play/:file_id (gets JazzDrive URL)
2. App streams file from JazzDrive URL
3. AES-256 key generated per-download (tied to device_id + user_id)
4. Encrypted chunks saved to private app storage as title.rdw
5. On playback: decrypt on-the-fly using media_kit custom data source
6. If user's subscription expires → downloads stop decrypting
```

### APK Build (no PC needed)
- GitHub Actions workflow triggers on push to `release` branch
- Builds signed APK automatically
- Uploads to GitHub Releases
- User downloads directly from GitHub Releases page

---

## 10. Production Server (Oracle Ubuntu — Free Tier)

### Infrastructure
```
Oracle Ubuntu 22.04 (ARM, 4 OCPU, 24GB RAM — all free)
├── Nginx (reverse proxy + SSL)
├── Let's Encrypt (free HTTPS)
├── Gunicorn (Python WSGI server)
├── PostgreSQL (when ready to migrate from SQLite)
└── Supervisor (process management)
```

### Migration plan (SQLite → PostgreSQL)
1. Export SQLite with `sqlite3 data/radd.db .dump > backup.sql`
2. Convert SQLite syntax to PostgreSQL (types, autoincrement → serial)
3. Import to PostgreSQL
4. Update connection string in `hub/db.py`
5. Test all endpoints

### Domain
`jazzmax.pk` (register when ready to launch)  
Redirect: `watch.jazzmax.pk` → Oracle server

### Nginx config (key parts)
```nginx
server {
    listen 443 ssl;
    server_name jazzmax.pk;
    location /watch { proxy_pass http://localhost:8000; }
    location /hub   { proxy_pass http://localhost:5000; }
}
```

---

## 11. Current File Map

```
workspace/
├── _watch_prototype/
│   ├── run.py                    Flask entry point (PORT env var, default 6000)
│   ├── routes/
│   │   └── watch.py              All API endpoints + catalog logic
│   ├── templates/
│   │   └── watch/
│   │       └── index.html        JazzMAX web app (Swiper + GSAP)
│   └── posters/                  Permanently cached poster images
│
├── radd-hub/
│   ├── radd_hub.py               Hub entry point
│   ├── data/                     SQLite database files
│   └── hub/
│       ├── db.py                 Database connection helper
│       ├── jazzdrive.py          JazzDrive link generation
│       └── auth.py               Hub authentication
│
├── WATCH_APP.md                  Server architecture notes
├── MOBILE_APP_PLAN.md            Flutter app detailed plan
├── DESIGN_PLAN.md                Brand/design language notes
└── JAZZMAX_COMPLETE_PLAN.md      ← This file
```

---

## 12. What To Build Next (Priority Order)

### Phase 1 — Complete Web Prototype
- [x] Catalog API with rich metadata
- [x] JazzMAX UI design (Swiper, GSAP)
- [x] Episode playback fix
- [ ] "Continue Watching" row (localStorage)
- [ ] Search with genre filters
- [ ] Trailer player (YouTube embed, only if trailer_url exists)

### Phase 2 — Auth & Accounts
- [ ] User registration (phone + OTP)
- [ ] JWT auth middleware
- [ ] Subscription check on /api/play
- [ ] Device binding
- [ ] Watch history API

### Phase 3 — Flutter App (Android first)
- [ ] Project scaffold (Flutter + Riverpod + Drift)
- [ ] Auth screens (login/OTP)
- [ ] Home screen (mirrors web design)
- [ ] Video player (media_kit)
- [ ] Offline catalog sync
- [ ] Encrypted downloads

### Phase 4 — Production Launch
- [ ] Oracle Ubuntu server setup
- [ ] PostgreSQL migration
- [ ] Nginx + Let's Encrypt
- [ ] JazzCash payment integration
- [ ] Google Play Store submission

---

## 13. Known Constraints & Rules

1. **JazzDrive for video only** — never for images
2. **Stream links cached 6 hours** — confirmed safe duration
3. **Episode folder_share_url** — all episodes share same URL, must pass `target_filename`
4. **Posters saved as** `title_{id}.jpg` or `show_{file_id}.jpg` in `_watch_prototype/posters/`
5. **No thumbnails for episodes** — not planned, keeps it simple
6. **No multiple audio dubs** — removed from scope
7. **DB path** — `radd-hub/data/` — both Hub and Watch API share same SQLite file

---

## 14. Branding

- **App name:** JazzMAX
- **Primary color:** `#E8002D` (Jazz Red — Jazz Pakistan's official brand red)
- **Background:** `#08080E` (Obsidian)
- **Surface:** `#0E0E1C` / `#151528`
- **Font:** Inter (Google Fonts)
- **Tagline:** "Pakistan ka entertainment, data-free"
- **Logo:** `Jazz` (white) + `MAX` (red gradient) + small red dot pulse
