# JazzMAX — Master Project File
> **Read this first before doing anything.** This file contains everything about the project — what it is, what is built, what is left, how to continue, and instructions for every Replit account working on it.

**App:** JazzMAX — Android streaming app for Jazz SIM users in Pakistan  
**Owner:** Muhammad Rehan (GitHub: `raddclub`)  
**Package ID:** `com.jazzmax.app`  
**Tagline:** "Pakistan ka entertainment, data-free"  

---

## ⚡ NEW REPLIT ACCOUNT — COMPLETE SETUP (2 steps only)

### Step 1 — Add 2 Replit Secrets (manual, 1 minute)
> Replit sidebar → 🔒 Secrets → + Add Secret
>
> | Secret Name | Value |
> |---|---|
> | `GITHUB_TOKEN` | `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` |
> | `SESSION_SECRET` | ask Muhammad Rehan for this value |

### Step 2 — Run ONE command in Shell (does everything automatically)
> ```bash
> curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
>   "https://raw.githubusercontent.com/raddclub/jazzmax-app/main/setup_new_account.sh" \
>   | bash
> ```
> **This single command:**
> - Downloads full project from GitHub
> - Installs all Python packages
> - Updates `jazzmax_config.json` with this account's URL (so installed APKs auto-connect)
> - Publishes all movie titles in the database
> - Creates test account (03001234567 / test123)
> - Shows what to do next
>
> After it finishes: **refresh your browser (F5)** — workflows appear automatically.
> Then tell the Agent: `"I am Muhammad Rehan. Read JAZZMAX_MASTER.md Section 14, find first unchecked [ ] item, build it."`

## ⚡ TEST WITHOUT APK — API Test Panel
> After setup, verify everything works BEFORE installing APK:
> ```
> Open in browser: https://[your-replit-domain]/watch/test
> ```
> Tests: login, register, catalog (14 movies), subscription, play links, search.
> If it works here → it works in the app. Only install APK for video + downloads testing.

## ⚡ AUTOMATED ANDROID EMULATOR TEST (no phone needed)
> After APK builds on GitHub Actions, trigger an emulator test:
> 1. Go to: **github.com/raddclub/jazzmax-app → Actions → Test JazzMAX on Android Emulator**
> 2. Click **"Run workflow"**
> 3. Wait ~15 minutes
> 4. Download artifact **emulator-test-N** → contains screenshots + crash logs
>
> Screenshots: splash screen, home screen, catalog loaded.
> If no crash = safe to install on real phone.

## ⚡ END OF SESSION — PUSH TO GITHUB
> **Run before finishing every session:**
> ```bash
> bash push_to_github.sh
> ```
> Commits + pushes everything to **github.com/raddclub/jazzmax-app** (private repo).

## ⚡ IMPORTANT: jazzmax_config.json controls the API URL
> Every time you move to a new Replit account, `setup_new_account.sh` automatically updates this file.
> All installed APKs fetch this file from GitHub at every launch — they auto-switch to the new server.
> **You do NOT need to rebuild the APK when switching accounts.**

---

## TABLE OF CONTENTS
1. [What Is JazzMAX](#1-what-is-jazzmax)
2. [How The App Works](#2-how-the-app-works)
3. [Branding & Design](#3-branding--design)
4. [Project Structure — File Map](#4-project-structure--file-map)
5. [Tech Stack](#5-tech-stack)
6. [Database — All Tables](#6-database--all-tables)
7. [API Endpoints — All Built](#7-api-endpoints--all-built)
8. [Running The Project](#8-running-the-project)
9. [GitHub & APK Build Pipeline](#9-github--apk-build-pipeline)
10. [Payment System — TID Method](#10-payment-system--tid-method)
11. [Subscription Plans](#11-subscription-plans)
12. [Device Locking](#12-device-locking)
13. [Critical Rules — Never Break These](#13-critical-rules--never-break-these)
14. [Full Task Checklist](#14-full-task-checklist)
15. [How To Hand Off To Next Replit Account](#15-how-to-hand-off-to-next-replit-account)
16. [Manual Shell Commands (Do These Yourself)](#16-manual-shell-commands-do-these-yourself)
17. [Production Server Plan](#17-production-server-plan)
18. [Known Issues & Sharp Edges](#18-known-issues--sharp-edges)

---

## 1. What Is JazzMAX

JazzMAX is an **Android app** for Jazz SIM users in Pakistan. It lets users watch movies and TV shows **without using their internet data** (zero-rated) because all videos are hosted on **JazzDrive** — Jazz Pakistan's cloud storage which is zero-rated for Jazz users.

**We are building Android app ONLY. No iOS. No website (web prototype is for testing backend only).**

**How zero-rating works:**
- Jazz users' internet traffic to JazzDrive does not count against their data bundle
- So when the app streams a video from JazzDrive, it costs the user PKR 0 in data
- This is the entire value of the app — free entertainment for Jazz users

---

## 2. How The App Works

```
User opens JazzMAX app
  ↓
App loads catalog from local database (works offline, no internet needed)
  ↓
User taps a movie/show
  ↓
App sends request to our server: POST /api/play/<file_id>
  ↓
Server generates a JazzDrive streaming link (valid for 6 hours)
  ↓
App plays the video — zero-rated for Jazz users
  ↓
Progress saved locally (resume where you left off)
```

**Content pipeline (how movies get into the app):**
```
Radd Hub (admin panel) → downloads movie → uploads to JazzDrive → saves to database
→ app syncs catalog → movie appears for users
```

---

## 3. Branding & Design

| Property | Value |
|---|---|
| App name | JazzMAX |
| Primary color | `#E8002D` (Jazz Pakistan official red) |
| Background | `#08080E` (Obsidian dark) |
| Surface colors | `#0E0E1C` / `#151528` / `#1C1C35` |
| Text color | `#F2F2FF` |
| Muted text | `#6A6A90` |
| Font | Inter (Google Fonts) |
| Logo | "Jazz" in white + "MAX" in red gradient + small red pulsing dot |
| Tagline | "Pakistan ka entertainment, data-free" |

---

## 4. Project Structure — File Map

```
workspace/
├── _watch_prototype/                  ← Flask backend (Python) — the API server
│   ├── run.py                         ← Entry point — run this to start API server
│   ├── routes/
│   │   ├── watch.py                   ← Main catalog + play link API
│   │   ├── app_auth.py                ← Auth API (register/login/JWT) ✅ BUILT
│   │   ├── app_catalog.py             ← Catalog sync API for Flutter app ✅ BUILT
│   │   └── app_subscription.py        ← Subscription + TID payment API ✅ BUILT
│   ├── templates/watch/index.html     ← Web prototype UI (testing only)
│   └── posters/                       ← Locally cached poster images
│
├── radd-hub/                          ← Admin backend (Python Flask)
│   ├── radd_hub.py                    ← Entry point — run this to start admin panel
│   ├── data/
│   │   ├── radd_hub.db                ← THE MAIN DATABASE (SQLite) — both apps share this
│   │   └── logs/
│   └── hub/
│       ├── db.py                      ← Database connection + all table schemas
│       ├── jazzdrive.py               ← JazzDrive link generation (critical)
│       ├── auth.py                    ← Admin login
│       ├── config.py                  ← Env vars, paths, logging setup
│       ├── app.py                     ← Flask app factory — registers all blueprints
│       ├── routes/
│       │   ├── library.py             ← Content library management
│       │   ├── tid_panel.py           ← TID payment verification panel ✅ BUILT
│       │   └── [many others...]
│       └── templates/
│           └── base.html              ← Admin UI base template
│
├── jazzmax_flutter/                   ← Flutter Android app ❌ NOT BUILT YET
│   (entire folder to be created)
│
├── JAZZMAX_MASTER.md                  ← THIS FILE — read first
├── JAZZMAX_COMPLETE_PLAN.md           ← Original architecture plan
├── MOBILE_APP_PLAN.md                 ← Flutter app detailed plan
├── WATCH_APP.md                       ← Server architecture notes
└── DESIGN_PLAN.md                     ← Design language details
```

---

## 5. Tech Stack

### Backend (Already Built — Python)
- **Flask** — web framework
- **SQLite** — database (file: `radd-hub/data/radd_hub.db`)
- **PyJWT** — JSON Web Tokens for auth
- **Werkzeug** — password hashing
- **Flask-CORS** — allows Flutter app to call the API

### Flutter App (To Be Built)
- **Flutter** + Dart — Android app framework
- **Riverpod** — state management
- **Drift** — local encrypted SQLite database
- **media_kit** — video player (handles MKV, EAC3, subtitles)
- **Dio** — HTTP client for API calls
- **flutter_secure_storage** — store JWT tokens securely
- **flutter_downloader** + **WorkManager** — background downloads
- **device_info_plus** — get unique device ID for binding
- **cached_network_image** — poster image caching

### APK Build
- **GitHub Actions** — free cloud builds, produces APK automatically on every push

---

## 6. Database — All Tables

**Database file:** `radd-hub/data/radd_hub.db` (SQLite)  
Both the Watch API and Radd Hub admin panel share this same file.

### Tables that exist (key ones):

| Table | Purpose |
|---|---|
| `titles` | Movies + TV shows catalog (metadata, TMDB poster URLs, JazzDrive folder links) |
| `files` | Individual video files (JazzDrive share URLs, season/episode numbers, quality) |
| `accounts` | JazzDrive accounts used for scanning and uploading |
| `stream_links` | Cached streaming URLs (valid 6 hours) — prevents hitting JazzDrive every play |
| `app_users` | JazzMAX mobile app user accounts (phone, password hash, device ID) |
| `app_subscriptions` | Which plan each user is on (free/basic/standard/premium + expiry) |
| `app_refresh_tokens` | JWT refresh tokens (hashed — never store raw) |
| `tid_payments` | Payment verification queue (TID submissions waiting for approval) |
| `plans` | Subscription plan definitions (price, limits) |
| `settings` | Key-value config store |
| `queue` | Download job queue |

### Key columns in `titles`:
```
id, title, year, media_type (movie/tv), poster (TMDB URL), backdrop,
rating, plot, genres (JSON), language, trailer_url, is_free,
folder_share_url (JazzDrive), is_published (1 = visible to users),
updated_at (used for delta sync versioning)
```

### Key columns in `files`:
```
id, title_id (FK), filename, share_url (JazzDrive folder), 
season, episode, quality, size_bytes
```

### Key columns in `app_users`:
```
id, phone (unique), password_hash, device_id, device_name,
device_bound_at, is_active, created_at, last_login_at
```

---

## 7. API Endpoints — All Built

**Base URL (development):** `http://localhost:8000`  
**Base URL (production):** `https://YOUR_ORACLE_SERVER_IP` (not set up yet)

### Auth (`/api/auth/`)
| Method | Endpoint | What it does | Auth needed |
|---|---|---|---|
| POST | `/api/auth/register` | Create account: `{phone, password}` | No |
| POST | `/api/auth/login` | Login: `{phone, password, device_id}` → tokens | No |
| POST | `/api/auth/refresh` | Get new access token: `{refresh_token}` | No |
| POST | `/api/auth/logout` | Revoke refresh token | Yes |
| GET | `/api/auth/me` | User profile + subscription | Yes |
| POST | `/api/auth/device` | Bind device: `{device_id, device_name}` | Yes |

### Catalog (`/api/catalog/`)
| Method | Endpoint | What it does | Auth needed |
|---|---|---|---|
| GET | `/api/catalog/version` | Returns `{version, count}` for sync check | No |
| GET | `/api/catalog/sync` | Full catalog or `?since=<timestamp>` delta | No |
| GET | `/api/catalog/posters` | List of poster URLs for pre-caching | No |

### Subscription (`/api/subscription/`)
| Method | Endpoint | What it does | Auth needed |
|---|---|---|---|
| GET | `/api/subscription/plans` | List all plans + prices + payment numbers | No |
| GET | `/api/subscription/status` | Current user's plan + expiry | Yes |
| POST | `/api/subscription/tid/submit` | Submit TID: `{phone, tid, plan, payment_method}` | No |
| GET | `/api/subscription/tid/status` | Check my TID submissions | Yes |

### Watch (`/watch/api/`)
| Method | Endpoint | What it does | Auth needed |
|---|---|---|---|
| GET | `/watch/api/catalog` | Movies + shows list | No |
| GET | `/watch/api/show/<slug>` | Episode list for a show | No |
| POST | `/watch/api/play/<file_id>` | Generate stream URL from JazzDrive | No (add auth later) |

### JWT Token Info
- **Access token:** valid 15 minutes — sent as `Authorization: Bearer <token>`
- **Refresh token:** valid 30 days — stored securely on device, used to get new access token
- **Secret key:** from `SESSION_SECRET` env var (set in Replit secrets)

---

## 8. Running The Project

### Replit Workflows (auto-start these):

**Watch Prototype (API server):**
```
Name: Watch Prototype
Command: cd _watch_prototype && PORT=8000 python run.py
```

**Radd Hub (admin panel):**
```
Name: Radd Hub
Command: cd radd-hub && python3 radd_hub.py run --skip-setup
```

### Access URLs:
- Watch API: `http://localhost:8000`
- Radd Hub admin: `http://localhost:5000`
- TID payment panel: `http://localhost:5000/tid/`

### Test the API is working:
```bash
curl http://localhost:8000/api/catalog/version
# Should return: {"count": 0, "version": 0}
# (0 because titles need is_published=1 — see below)
```

### Make titles visible to the app:
```bash
# In Replit shell — run this once to publish all titles:
cd radd-hub && python3 -c "
import sys; sys.path.insert(0,'.')
from hub import db, config
config.load_env()
db.init_db()
with db.conn() as c:
    n = c.execute('UPDATE titles SET is_published=1').rowcount
    print(f'Published {n} titles')
"
```

---

## 9. GitHub & APK Build Pipeline

### Credentials (KEEP PRIVATE — do not share publicly)
- **GitHub username:** `raddclub`
- **GitHub token:** `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`
- **App package:** `com.jazzmax.app`

### How APK building works (simple version)
1. Flutter code lives in `jazzmax_flutter/` folder in this project
2. We push the code to GitHub repo (free)
3. GitHub Actions (free cloud computer) automatically builds the APK
4. APK download link appears in GitHub → Releases
5. Share that link with users — they install directly (no Play Store needed)

### Setting up GitHub repo (do once — not done yet):
```bash
# In Replit shell — run these commands:
cd /home/runner/workspace
git init jazzmax_flutter_repo 2>/dev/null || true
cd jazzmax_flutter
git init
git remote add origin https://raddclub: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@github.com/raddclub/jazzmax-app.git
git add .
git commit -m "Initial Flutter app"
git push -u origin main
```

### GitHub Actions build file location (to be created):
`jazzmax_flutter/.github/workflows/build_apk.yml`

This file tells GitHub to build the APK automatically. The agent will create this file when building the Flutter app.

---

## 10. Payment System — TID Method

**No API keys needed. Works from day one. PKR 0 cost.**

### How it works:
1. User wants to subscribe
2. App shows: "Send PKR [amount] to JazzCash/Easypaisa: **03286839827** (Muhammad Rehan)"
3. User pays from their JazzCash/Easypaisa app
4. User comes back to JazzMAX app and enters:
   - Their phone number
   - The Transaction ID (TID) from their payment receipt
5. Muhammad Rehan opens Radd Hub → TID Payments panel → verifies the payment
6. Click "Approve" → subscription activates automatically
7. User's app shows they are now subscribed

### Payment details:
- **JazzCash number:** 03286839827
- **Easypaisa number:** 03286839827
- **Account name:** Muhammad Rehan

### TID Panel location:
Radd Hub → `/tid/` → shows Pending / Approved / Rejected tabs

---

## 11. Subscription Plans

| Plan | Price | What user gets |
|---|---|---|
| Free | PKR 0 | Only `is_free=1` titles, 480p |
| Basic | PKR 149/month | All titles, 720p, 5 downloads/day |
| Standard | PKR 299/month | All titles, 1080p, 15 downloads/day |
| Premium | PKR 499/month | All titles, 1080p, unlimited downloads |

Prices can be changed any time in `_watch_prototype/routes/app_subscription.py` — no app update needed (Flutter app fetches plans from `/api/subscription/plans`).

---

## 12. Device Locking

**One subscription = one phone. Cannot be shared.**

- When user subscribes, their phone's Device ID is saved in `app_users.device_id`
- Every login checks: does this device ID match the registered device?
- If someone tries to log in from a different phone → blocked with error "account registered on another device"
- User can transfer to new phone once every 30 days (via `/api/auth/device` endpoint)
- Muhammad Rehan can manually reset device binding in Radd Hub database if needed

---

## 13. Critical Rules — Never Break These

1. **JazzDrive is for VIDEO ONLY** — never use JazzDrive URLs for images (posters, backdrops, thumbnails). Always use TMDB URLs for images.

2. **Episode share URLs** — all episodes in a show share the same `folder_share_url`. You MUST pass `target_filename=filename` to `generate_direct_link()` to get the correct episode file. Without this, you get the wrong video.

3. **Stream links cached 6 hours** — `LINK_CACHE_SECONDS = 21600`. JazzDrive links confirmed valid for at least 6 hours. Do not lower this or you'll hammer JazzDrive.

4. **Never store stream URLs in the local app database** — stream URLs expire. The Flutter app must always fetch a fresh URL from `/api/play/<file_id>` before playing.

5. **Posters saved as** `title_{id}.jpg` or `show_{file_id}.jpg` in `_watch_prototype/posters/`. Once saved, they are served locally — never fetched from JazzDrive again.

6. **Both Radd Hub and Watch API share ONE database file:** `radd-hub/data/radd_hub.db`. Do not create a second database.

7. **JWT sub claim must be a string** — PyJWT v2 requires `"sub": str(user_id)`. Parse back with `int(payload["sub"])`. This is already done correctly in `app_auth.py`.

---

## 14. Full Task Checklist

Use this to track progress across all Replit accounts. When something is done, change `[ ]` to `[x]`.

### Phase 0 — Backend APIs (Server)
- [x] Flask API server running on port 8000
- [x] Database schema with all tables (titles, files, app_users, app_subscriptions, tid_payments, app_refresh_tokens)
- [x] POST /api/auth/register — phone + password registration
- [x] POST /api/auth/login — returns JWT access + refresh tokens
- [x] POST /api/auth/refresh — refresh token flow
- [x] POST /api/auth/logout — revoke refresh token
- [x] GET /api/auth/me — user profile + subscription
- [x] POST /api/auth/device — device binding
- [x] GET /api/catalog/version — sync version check
- [x] GET /api/catalog/sync — full + delta catalog sync
- [x] GET /api/catalog/posters — poster URL list
- [x] GET /api/subscription/plans — plan list with prices
- [x] GET /api/subscription/status — user's current plan
- [x] POST /api/subscription/tid/submit — TID payment submission
- [x] GET /api/subscription/tid/status — payment status check
- [x] TID payment verification panel in Radd Hub (/tid/)
- [x] Payment numbers set: 03286839827 (Muhammad Rehan)
- [x] Add auth check to POST /watch/api/play/<file_id> (require valid token for premium titles)
- [x] Watch history API: POST /api/history/<file_id> with {progress_seconds, completed}
- [x] GET /api/history — return user's watch history
- [x] Search API: GET /api/search?q=term
- [x] Rate limiting on /api/play (max 20 requests/hour per user — in-memory, resets on restart)

### Phase 1 — Flutter App: Project Setup
- [x] Create `jazzmax_flutter/` folder with full Flutter project structure
- [x] `pubspec.yaml` with all dependencies (media_kit, sqflite, dio, riverpod, etc.)
- [x] `android/app/src/main/AndroidManifest.xml` with all permissions
- [x] `android/app/build.gradle` configured for com.jazzmax.app
- [x] `.github/workflows/build_apk.yml` — GitHub Actions APK build pipeline
- [x] Push to GitHub repo: `raddclub/jazzmax-app` ← pushed via GitHub API (May 22 2026)
- [x] Verify GitHub Actions builds APK successfully (check Actions tab on GitHub)

### Phase 2 — Flutter App: Core Structure
- [x] `lib/main.dart` — app entry point
- [x] `lib/app.dart` — MaterialApp with dark theme + routing
- [x] `lib/core/api/api_client.dart` — Dio HTTP client with JWT interceptor + auto-refresh
- [x] `lib/core/api/auth_api.dart` — login, register, refresh token calls
- [x] `lib/core/api/catalog_api.dart` — sync catalog, get stream URL
- [x] `lib/core/api/subscription_api.dart` — plans, TID submit
- [x] `lib/core/db/local_db.dart` — sqflite local SQLite (offline catalog)
- [x] `lib/core/db/sync_service.dart` — full + delta catalog sync
- [x] `lib/core/security/device_id.dart` — get unique Android device ID
- [x] `lib/core/security/keystore.dart` — store tokens in Android Keystore

### Phase 3 — Flutter App: Screens
- [x] Splash screen (check token → route to Home or Login)
- [x] Login screen (phone + password fields, JazzMAX branding)
- [x] Register screen (phone + password + confirm)
- [x] Home screen (poster grid — Movies + TV Shows sections + search bar)
- [x] Movie/Show detail sheet (poster, title, year, rating, Watch button — bottom sheet)
- [x] Search screen (offline local SQLite search — built into Home screen)
- [x] Downloads screen (list of downloaded files) ← built in Phase 5
- [x] Profile/Settings screen (plan info, device info, logout)
- [x] Subscription plans screen (plan cards + TID payment instructions)
- [x] TID submission screen (enter TID after payment — built into Subscription screen)

### Phase 4 — Flutter App: Video Player
- [x] `lib/screens/player_screen.dart` — fullscreen player (777 lines)
- [x] media_kit integration (handles MKV, EAC3, multiple audio tracks)
- [x] Playback controls (play/pause, seek bar, time display)
- [x] Double-tap left/right to seek ±10 seconds (with flash indicator)
- [x] Swipe left half = screen brightness (screen_brightness package)
- [x] Swipe right half = player volume (volume_controller package)
- [x] Audio track selector (bottom sheet, for multi-language MKV files)
- [ ] Subtitle selector (built-in + external .srt) ← next phase
- [x] Aspect ratio toggle (Fit / Cover / Fill cycle)
- [x] Screen lock button (tap-to-unlock overlay)
- [x] Resume position (save every 5s to local_db, restore on open)
- [x] Wakelock active during playback (wakelock_plus)

### Phase 5 — Flutter App: Downloads
- [x] `lib/core/download/download_service.dart` — Dio-based download with progress
- [x] `lib/providers/downloads_provider.dart` — Riverpod state for downloads list
- [x] `lib/screens/downloads_screen.dart` — full downloads list UI
- [x] `lib/core/db/local_db.dart` downloads table — status, progress, local_path
- [x] Download progress tracking (0.0 → 1.0, updates UI live)
- [x] Delete downloaded file (removes local file + DB record)
- [x] Offline playback from local file (passes local_path to player)
- [ ] AES-256 encryption of downloaded files ← future
- [ ] Download limit per subscription tier ← future
- [ ] Background download survives app kill ← future

### Phase 6 — Polish & Release
- [x] Splash screen with fade animation + pulsing dot
- [x] Onboarding screen (4 pages, skip button, shown once via SharedPreferences)
- [x] Bottom nav: Downloads tab replaces Subscribe (subscribe accessible from Profile)
- [x] App icon (JazzMAX red logo) ← red J+MAX PNG, all mipmap densities + adaptive icon
- [x] ProGuard/R8 code obfuscation ← enabled in build.gradle with proguard-rules.pro
- [x] Sign APK with keystore (required for release) ← PKCS12 keystore, CI reads from GitHub Secret KEYSTORE_BASE64
- [ ] Test on real Android phone ← needs APK build to pass first
- [ ] Upload signed APK to GitHub Releases ← after signing
- [ ] Share APK link with first users

### Phase 7 — Production Server
- [ ] Create Oracle Cloud free tier account (cloud.oracle.com)
- [ ] Spin up Ubuntu 22.04 ARM instance (4 OCPU, 24GB RAM — free forever)
- [ ] Install Python, pip, Nginx, Supervisor
- [ ] Clone project to Oracle server
- [ ] Set up Gunicorn for Flask apps (port 8000 and 5000)
- [ ] Configure Nginx reverse proxy
- [ ] Get free SSL certificate with Let's Encrypt (certbot)
- [ ] Register domain `jazzmax.pk` (~PKR 800/year) — optional
- [ ] Point domain to Oracle server IP
- [ ] Update Flutter app's API base URL to production server
- [ ] Test everything end-to-end on production

---

## 15. How To Hand Off To Next Replit Account

### When you finish your work session, do this:
1. Note which tasks you completed — update the checkboxes in section 14 above
2. Add any new issues or notes to section 18 (Known Issues)
3. The next account will read this file first and know exactly where to continue

### Instructions for the next Replit account receiving this project:

**Step 1 — Read this file completely before doing anything.**

**Step 2 — Start the two workflows:**
- Go to Replit shell and run:
```bash
# Start Watch API (port 8000)
cd _watch_prototype && PORT=8000 python run.py &

# Start Radd Hub admin (port 5000)  
cd /home/runner/workspace/radd-hub && python3 radd_hub.py run --skip-setup &
```
Or restart them from the Replit Workflows panel.

**Step 3 — Check what's done vs what's left:**
- Look at section 14 checkboxes — anything with `[x]` is done, `[ ]` is to build
- Find the first `[ ]` item and continue from there

**Step 4 — Key things to know:**
- The main database is at `radd-hub/data/radd_hub.db` — shared by both apps
- All new Flask API routes go in `_watch_prototype/routes/` and must be registered in `_watch_prototype/run.py`
- All admin panel routes go in `radd-hub/hub/routes/` and must be registered in `radd-hub/hub/app.py`
- The Flutter app does not exist yet — it needs to be created at `jazzmax_flutter/`
- JWT secret is from `SESSION_SECRET` environment variable (already set in Replit Secrets)
- Never change the database file location

**Step 5 — When building the Flutter app:**
- Create the folder `jazzmax_flutter/` in the workspace root
- Use package name: `com.jazzmax.app`
- API server base URL variable should be easy to change (for when we move to production server)
- Follow `MOBILE_APP_PLAN.md` for complete architecture details

**What each agent should tell the next one:**
At the end of your session, write a short note at the bottom of this file under "Session Notes" with:
- Date
- What you built
- What the next account should do first
- Any problems you ran into

---

## 16. Manual Shell Commands (Do These Yourself)

### CREATE ZIP — Run this at end of every session (REQUIRED):
```bash
bash create_zip.sh
```
- Creates `jazzmax_YYYYMMDD_HHMM.zip` (~80 MB) in the workspace root
- Excludes: 641MB local binaries, 372MB node_modules, 227MB .pythonlibs, logs, pycache
- Includes: all source code, database, posters, config files
- Then: Files panel → right-click the zip → Download → upload to next Replit account

### UNZIP on next Replit account:
```bash
# After uploading the zip to the new account's Files panel:
cd /home/runner/workspace
python3 -c "
import zipfile
zf = zipfile.ZipFile('jazzmax_20260522_1957.zip')  # change filename
zf.extractall('.')
zf.close()
print('Done!')
"
```

---

These are simple things you can run yourself in the Replit shell to save time:

### Publish all titles so they appear in the app:
```bash
cd /home/runner/workspace/radd-hub && python3 -c "
import sys; sys.path.insert(0,'.')
from hub import db, config
config.load_env()
db.init_db()
with db.conn() as c:
    n = c.execute('UPDATE titles SET is_published=1').rowcount
    print(f'Published {n} titles')
"
```

### Check how many titles are in the database:
```bash
cd /home/runner/workspace/radd-hub && python3 -c "
import sys; sys.path.insert(0,'.')
from hub import db, config
config.load_env()
db.init_db()
with db.conn() as c:
    m = c.execute(\"SELECT COUNT(*) FROM titles WHERE media_type='movie'\").fetchone()[0]
    t = c.execute(\"SELECT COUNT(*) FROM titles WHERE media_type='tv'\").fetchone()[0]
    u = c.execute('SELECT COUNT(*) FROM app_users').fetchone()[0]
    p = c.execute(\"SELECT COUNT(*) FROM tid_payments WHERE status='pending'\").fetchone()[0]
    print(f'Movies: {m}, TV Shows: {t}, App Users: {u}, Pending Payments: {p}')
"
```

### Install Python packages if missing:
```bash
pip install PyJWT flask flask-cors werkzeug
```

### Install Flutter (when ready to build Flutter app):
```bash
# This takes a few minutes — run in Replit shell
cd /home/runner
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:/home/runner/flutter/bin"
flutter doctor
```

### Create Flutter project (after installing Flutter):
```bash
export PATH="$PATH:/home/runner/flutter/bin"
cd /home/runner/workspace
flutter create --org com.jazzmax --project-name jazzmax_app jazzmax_flutter
cd jazzmax_flutter
flutter pub add media_kit media_kit_video media_kit_libs_android_video
flutter pub add drift sqlite3_flutter_libs drift_dev
flutter pub add dio riverpod flutter_riverpod
flutter pub add flutter_secure_storage device_info_plus
flutter pub add cached_network_image path_provider
flutter pub add flutter_downloader workmanager
```

### Push Flutter app to GitHub (after creating it):
```bash
cd /home/runner/workspace/jazzmax_flutter
git init
git remote add origin https://raddclub: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@github.com/raddclub/jazzmax-app.git
git add .
git commit -m "Flutter app initial commit"
git push -u origin main
```

### Test an API endpoint:
```bash
# Test registration
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"phone":"03001234567","password":"test123"}'

# Test catalog version
curl http://localhost:8000/api/catalog/version

# Test subscription plans
curl http://localhost:8000/api/subscription/plans
```

---

## 17. Production Server Plan

**When ready to go live with real users (not needed yet):**

### Oracle Cloud Free Tier (free forever):
- Go to cloud.oracle.com → create free account
- Create VM: Ubuntu 22.04, ARM shape, 4 OCPU, 24GB RAM
- This is **permanently free** — not a trial

### What to install on Oracle server:
```bash
sudo apt update && sudo apt install -y python3 python3-pip nginx supervisor git
pip3 install flask flask-cors pyjwt werkzeug gunicorn
```

### Cost breakdown for production:
| Item | Cost |
|---|---|
| Oracle Cloud server | Free forever |
| Let's Encrypt SSL | Free |
| GitHub (code + APK builds) | Free |
| JazzDrive (video storage) | Free (Jazz provides it) |
| TMDB API (poster images) | Free |
| Domain `jazzmax.pk` | ~PKR 800/year (optional) |
| **Total** | **PKR 0 — PKR 800/year** |

---

## 18. Known Issues & Sharp Edges

1. **Catalog shows 0 items by default** — titles need `is_published=1` in database. Run the publish command in section 16.

2. **JazzDrive session expires** — Radd Hub keepalive thread handles this but sometimes fails. If streaming stops working, go to Radd Hub → JazzDrive Accounts and re-authenticate.

3. **PyJWT sub must be string** — Already fixed in `app_auth.py`. If you rewrite auth, remember `"sub": str(user_id)` when signing and `int(payload["sub"])` when reading.

4. **SESSION_SECRET env var** — JWT signing uses the `SESSION_SECRET` Replit secret. This is already configured. If moving to Oracle server, set this same env var there.

5. **Both workflows must be running** — Watch API (port 8000) and Radd Hub (port 5000) are separate Flask processes. Both must be running for everything to work.

6. **Flutter is not installed on Replit yet** — Installing Flutter takes ~5 minutes and ~1.5GB disk. Do this manually in shell when ready to start Flutter work (see section 16).

7. **APK signing** — Release APK needs a keystore file for signing. Generate once: `keytool -genkey -v -keystore jazzmax.keystore -alias jazzmax -keyalg RSA -keysize 2048 -validity 10000`. Store the keystore file and password safely — if lost, cannot update the app without reinstalling.

---

## Session Notes

### How to add a session note (every account must do this):
At the end of your work, add a new session block below in this format:
```
### Session N — Date
Account: [whose account]
Built: [list of what you completed]
Checkboxes updated: [yes/no]
Zip created: [filename]
Next account should: [what to do first]
```

---

### Session 2 — May 23, 2026
**Account:** New Replit account (continuing from Session 1)
**Built:**
- Fixed Watch Prototype crash (PyJWT not installed → installed + restarted)
- Fixed Flutter app URL: `constants.dart` + `jazzmax_config.json` updated to current domain
- Fixed critical bug: `main.dart` was NOT calling `RemoteConfig.fetch()` — added it (app now auto-fetches URL on every launch, no APK rebuild needed when server changes)
- Registered Watch Prototype in proxy routing (artifact.toml) so Flutter app can reach /api/auth, /api/catalog etc. through Replit dev domain
- Added auth check to `POST /watch/api/play/<file_id>` — free titles open to all, premium needs valid non-guest token (Phase 0 task)
- Built `GET /api/search?q=term` — full-text search across titles, plot, genres, language
- Added in-memory rate limiting to play endpoint (20/hr per user, 5/hr for guests)
- Fixed guest token crash in `app_history.py` (sub="guest" → 401 instead of ValueError)
- Marked all actually-done items in checklist (history API, downloads screen were built but unchecked)
- Pushed all changes to GitHub → APK build triggered automatically
**Checkboxes updated:** Yes — Phase 0 all done, Phase 3 downloads fixed
**Next account should:**
1. Check GitHub Actions → verify APK builds successfully
2. Read section 14 — find first `[ ]` → next is Phase 1 "Verify GitHub Actions" then Phase 4 "Subtitle selector"
3. When changing Replit accounts: just update `jazzmax_config.json` in GitHub — NO APK rebuild needed
4. URL change process: edit `jazzmax_config.json` → change `api_base_url` → push to GitHub → done

---

### Session 3 — May 23, 2026
**Account:** Muhammad Rehan (switching to new account — reached token limit)

**What was built this session:**

#### 1. Oracle Production Server — FULLY RUNNING at `92.4.95.252`
- `oracle_setup.sh` — one-command setup script for Oracle Ubuntu 24.04 aarch64
- Nginx (port 80) → proxies to Flask (port 8000) and Radd Hub (port 5000)
- Supervisor keeps both services auto-restarting
- UFW + iptables-persistent configured (ports 22, 80, 8000 open)
- Oracle Cloud Security List: port 80 ingress rule added (Security List: "Replit-said")
- Health check working externally: `curl http://92.4.95.252/health` → `JazzMAX Oracle OK`
- Login API working: `POST http://92.4.95.252/api/auth/login` ✅
- Database HAS all 14 movies + 4 shows — but NOT yet published for app (see FIRST TASK below)

#### 2. Oracle Server Credentials & Details
- **IP:** `92.4.95.252` (permanent — never changes)
- **SSH user:** `ubuntu`  
- **SESSION_SECRET on Oracle:** `f0e69b8946173acfcfb5e66135bed3a74b28dce4beaf5e13443ae9b9fbe306b3`
- **DB path on Oracle:** `/opt/jazzmax/radd-hub/data/jazzmax.db`
- **Project dir on Oracle:** `/opt/jazzmax/`
- **Logs:** `tail -f /var/log/jazzmax_watch.err.log` and `/var/log/jazzmax_radd.err.log`

#### 3. Flutter App Updated for Oracle
- `jazzmax_config.json` on GitHub → `http://92.4.95.252` (APKs fetch this on launch)
- `jazzmax_flutter/lib/core/constants.dart` → fallback URL = `http://92.4.95.252`
- `jazzmax_flutter/android/app/src/main/res/xml/network_security_config.xml` → created (allows HTTP to 92.4.95.252)
- `jazzmax_flutter/android/app/src/main/AndroidManifest.xml` → references network_security_config

#### 4. Automation Tools Built
- `setup_new_account.sh` v2 — one-line Replit setup command (auto URL + publish + test account)
- `.github/workflows/emulator_test.yml` — Android emulator test on GitHub Actions
- JAZZMAX_MASTER.md quick-start section completely rewritten (2 steps instead of 5)

#### 5. Android Emulator on Oracle
- KVM is NOT currently available on Oracle instance (shows: `⚠ KVM not available`)
- To enable: Oracle Console → Compute → Instances → Edit → Enable "Nested Virtualization" → then re-run `oracle_setup.sh` (the script will auto-install Android emulator when KVM is present)

---

## ⚡ FIRST TASK FOR NEXT ACCOUNT — DO THIS BEFORE ANYTHING ELSE

**The Oracle server DB has all movies but they are NOT published for the app yet.**
The setup script didn't include this step. Run this in Termius on the Oracle server:

```bash
sqlite3 /opt/jazzmax/radd-hub/data/jazzmax.db "UPDATE titles SET is_published=1; SELECT COUNT(*) || ' titles published' FROM titles WHERE is_published=1;"
```

Expected output: `14 titles published`

Then verify the app catalog API works:
```bash
curl -s http://92.4.95.252/api/catalog/sync | python3 -c "
import json,sys; d=json.load(sys.stdin)
print(len(d.get('movies',[])), 'movies,', len(d.get('shows',[])), 'shows')
"
```
Expected: `14 movies, 4 shows`

**ALSO** — add `oracle_setup.sh` title-publishing step so it's automatic for future setups.
Find the `[7/7]` section in `oracle_setup.sh` and add before it:
```bash
echo "[6b] Publishing all titles in DB..."
sqlite3 "$PROJECT_DIR/radd-hub/data/jazzmax.db" "UPDATE titles SET is_published=1;" 2>/dev/null || true
echo "  ✓ Titles published"
```
Then push oracle_setup.sh to GitHub.

---

**After fixing titles, continue Section 14 checklist — next unchecked items are:**
1. Phase 4: Subtitle selector in video player
2. Phase 5: Push notifications
3. Phase 6: Android emulator test (KVM needs enabling in Oracle Console first)
4. Phase 7: Free HTTPS/SSL on Oracle server via Let's Encrypt (certbot)

### Session 1 — May 22, 2026
**Account:** Muhammad Rehan (main account)  
**Built:**
- Flask auth API (register, login, refresh, logout, me, device binding)
- Catalog sync API (version check, full sync, delta sync, poster list)
- Subscription API (plans, status, TID submit, TID status check)
- TID payment verification panel in Radd Hub admin (`/tid/`)
- All database tables: app_users, app_subscriptions, app_refresh_tokens, tid_payments
- Payment numbers set to 03286839827 (Muhammad Rehan)
- JWT tokens working correctly (PyJWT v2 string sub fix applied)
- `JAZZMAX_MASTER.md` — this master file (all project info + task checklist)
- `create_zip.sh` — export script for moving between Replit accounts
**Checkboxes updated:** Yes (Phase 0 all done)
**Zip created:** `jazzmax_20260522_1957.zip` (~80 MB)

**Next account should do:**
1. Unzip project, install packages, create 2 workflows (see Quick Start at top of this file)
2. Run the "publish all titles" shell command from section 16
3. Start Phase 1 of Flutter app — install Flutter, create project, set up GitHub Actions
4. Use `com.jazzmax.app` as package name, GitHub: `raddclub/jazzmax-app`
5. Read `MOBILE_APP_PLAN.md` before writing any Flutter code
6. API server is fully ready — Flutter just needs to connect to `http://YOUR_SERVER/api/`
