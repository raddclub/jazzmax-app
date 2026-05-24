# JazzMAX — Replit Account Handoff Guide

> **Read this completely before starting.** Following these steps in order prevents every error.

---

## BEFORE YOU LEAVE THE OLD ACCOUNT

Run this in Shell to save everything to GitHub:

```bash
bash push_to_github.sh
```

Wait for `✅ DONE!` — then close the old account.

---

## SETTING UP ON THE NEW REPLIT ACCOUNT

### STEP 1 — Add Secrets (do this FIRST, before anything else)

Go to: **Replit sidebar → Secrets (🔒 lock icon) → + Add Secret**

| Secret Name | What to put |
|---|---|
| `GITHUB_TOKEN` | Your GitHub Personal Access Token (needs `repo` permission) |
| `SESSION_SECRET` | The Flask secret key (same value always — check your notes) |
| `ORACLE_SSH_KEY` | Full private SSH key (including `-----BEGIN...` and `-----END...` lines) |

### STEP 2 — Run Setup Script

```bash
curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
  "https://raw.githubusercontent.com/raddclub/jazzmax-app/main/setup_new_account.sh" \
  | bash
```

This downloads the project, installs dependencies, and updates `jazzmax_config.json` so installed APKs auto-connect.

### STEP 3 — Start Servers

```bash
# Terminal 1 — Radd Hub admin panel (port 5000)
cd radd-hub && python run.py

# Terminal 2 — Watch Prototype / API server (port 6000)
cd _watch_prototype && python run.py
```

Or use the Replit workflow buttons if they're configured.

---

## PROJECT OVERVIEW (May 2026)

JazzMAX is an Android streaming app for Jazz SIM users in Pakistan. Streaming is **zero-rated** via JazzDrive — users watch HD content without using any data bundle.

### What's Built

| Feature | Status | File |
|---|---|---|
| Full Flutter app (auth, catalog, player, downloads) | ✅ Complete | `jazzmax_flutter/` |
| MX Player-level video player | ✅ Complete | `screens/player_screen.dart` |
| - Long-press 2× speed (hold for instant, release to resume) | ✅ | |
| - Speed selector sheet (0.25× – 4×) | ✅ | |
| - Background audio (continues when app backgrounded) | ✅ | |
| - Subtitle font-size slider | ✅ | |
| - External .srt file picker | ✅ | |
| - Skip ±10s, brightness/volume gestures, lock screen | ✅ | |
| - ALL formats: MP4, MKV, AVI, EAC3, DTS, TrueHD, TS | ✅ | |
| Local Media screen ("My Files" tab) | ✅ Complete | `screens/local_media_screen.dart` |
| Smart poster system (TMDB→OMDB→JazzDrive fallback) | ✅ Complete | `services/poster_service.dart` |
| JazzDrive zero-rated DB update service | ✅ Complete | `services/jazzdrive_db_service.dart` |
| 5-tab bottom nav (Home/Search/Downloads/My Files/Profile) | ✅ Complete | `widgets/bottom_nav.dart` |
| Local SQLite v7 with all tables | ✅ Complete | `core/db/local_db.dart` |
| Backend JWT auth, catalog sync, subscription | ✅ Complete | `_watch_prototype/routes/` |
| JazzDrive DB update API routes | ✅ Complete | `routes/jazzdrive_db.py` |
| Radd Hub admin panel | ✅ Complete | `radd-hub/` |

### What Still Needs Doing

| Task | Notes |
|---|---|
| Set real OMDB API key | Add via Radd Hub Settings → Key Vault page (plaintext, no encryption needed) |
| Upload db_update.json to JazzDrive | After adding content via Radd Hub |
| Set `jd_db_update_url` via API | After upload — see JazzDrive DB Update section below |
| Build and test APK | `cd jazzmax_flutter && flutter build apk --release` |

### Completed This Session (May 2026)

| Task | Status |
|---|---|
| Server-side poster proxy (`/api/poster/search`) | ✅ Working on Replit + Oracle |
| TMDB keys in vault as plaintext (no encryption) | ✅ 2 keys active |
| poster_proxy.py — no Fernet encryption, reads DB directly | ✅ Done |
| Android 13+ `READ_MEDIA_VIDEO` + `READ_MEDIA_AUDIO` permissions | ✅ Added |
| Oracle sync — all backend files pushed to `/opt/jazzmax` | ✅ Done |
| GitHub — all files pushed to `raddclub/jazzmax-app` | ✅ Done |
| push_to_oracle.sh — SSH key reconstruction + pip --break-system-packages | ✅ Fixed |

---

## KEY FILE LOCATIONS

```
jazzmax_flutter/lib/
├── app.dart                   — routes (all 6 routes including localMedia)
├── core/constants.dart        — AppRoutes, AppColors, AppConstants
├── core/db/local_db.dart      — SQLite v7 (7 tables)
├── screens/player_screen.dart — full MX-level video player
├── screens/local_media_screen.dart  — user's own video files
├── screens/home_screen.dart   — 5-tab nav shell
├── services/poster_service.dart     — smart poster loading
├── services/jazzdrive_db_service.dart — zero-rated DB updates
└── widgets/bottom_nav.dart    — 5-tab bottom navigation

_watch_prototype/
├── run.py                     — Flask app entry point
└── routes/
    ├── app_auth.py
    ├── app_catalog.py
    ├── app_subscription.py
    ├── app_history.py
    ├── app_search.py
    └── jazzdrive_db.py        — NEW zero-rated DB update routes
```

---

## BOTTOM NAV TAB INDICES

**IMPORTANT — these changed in v1.5.0:**

| Index | Tab | Route |
|---|---|---|
| 0 | Home | (inline) |
| 1 | Search | (inline) |
| 2 | Downloads | `/downloads` |
| 3 | My Files | `/local-media` |
| 4 | Profile | `/profile` ← **was 3 before** |

If you see profile-related code checking index 3, update it to 4.

---

## JAZZDRIVE ZERO-RATED DB UPDATE SYSTEM

This lets users get catalog updates without a data bundle.

**Admin workflow (after adding new content to Radd Hub):**

```bash
# 1. Generate db_update.json from current catalog
curl -X POST "https://YOUR_SERVER/api/jazzdrive/generate_db_update?admin_key=YOUR_KEY"

# 2. Upload the generated file to JazzDrive
#    File saved at: radd-hub/data/db_update.json
#    Upload manually via JazzDrive web interface

# 3. Set the direct download URL
curl -X POST "https://YOUR_SERVER/api/jazzdrive/set_db_update_url" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://JAZZ_DRIVE_DIRECT_LINK/db_update.json"}'
```

App then downloads this file every 12 hours, zero-rated.

---

## SMART POSTER SYSTEM

Posters load in this priority order:
1. Local hidden cache (`appSupportDir/.jazzmax_posters/<md5>.jpg`) — instant, no data
2. TMDB API — best quality, free
3. OMDB API — fallback
4. JazzDrive poster URL — zero-rated, last resort

**Poster proxy is server-side** — the Flutter app calls `/api/poster/search?title=...&year=...&media_type=...` on the Watch Prototype server. Keys are stored in the Radd Hub DB (table: `keys`) as **plaintext** (no Fernet encryption).

**To add an OMDB key:** Radd Hub → Settings → Key Vault → Add Key → provider: omdb. OR:
```bash
curl -X POST http://localhost:8000/api/poster/add_key \
  -H "Content-Type: application/json" \
  -d '{"provider":"omdb","key":"YOUR_OMDB_KEY","label":"omdb-key-1"}'
```

**TMDB keys already active:** `69dc4008...` and `d078f97b...` (2 keys rotating).

---

## LOCAL MEDIA SCREEN

"My Files" tab (index 3) lets users play their own video files:
- File picker for any format
- Auto-scans `/sdcard/Download`, `/sdcard/Movies` etc.
- Recently played list with swipe-to-remove
- ALL formats via media_kit

**Android 13+ permission needed:**
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
```

---

## PUSH TO GITHUB / ORACLE

```bash
# GitHub
bash push_to_github.sh

# Oracle (92.4.95.252)
bash push_to_oracle.sh
```

---

## STARTING FRESH NEXT SESSION

Tell the AI agent:

```
Continue JazzMAX development. Read JAZZMAX_MASTER.md and HANDOFF.md first.
Current version: 1.5.0
[Then describe what you want to build next]
```

The AI will orient itself from these two files.

---

## COMMON ERRORS & FIXES

| Error | Fix |
|---|---|
| `flutter: package not found: crypto` | Run `flutter pub get` in `jazzmax_flutter/` |
| `No such table: local_media_history` | DB version bump was missed — check `local_db.dart` version is 7 |
| Profile not opening (index 3 used) | Update nav handler — Profile is now index 4 |
| `jd_db_update_url not configured` | Upload db_update.json to JazzDrive, set URL via API |
| TMDB posters not loading | Replace `TMDB_API_KEY` placeholder in `poster_service.dart` |
| file_picker permission denied | Add `READ_MEDIA_VIDEO` permission to AndroidManifest.xml |
| `media_kit EAC3 not playing` | It works — make sure you have `media_kit_libs_android_video` in pubspec |
