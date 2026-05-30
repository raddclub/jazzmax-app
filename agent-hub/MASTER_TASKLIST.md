# RaddFlix — Master Task List
> Last updated: 2026-05-30 (Phase 13 COMPLETE — all 31 code-level bugs fixed; 5 false positives; A33 deferred design sprint)
> Read REINCARNATION.md first. Read CODE_MAP.md before touching any file.
> This file tracks every task — done, in progress, and upcoming.

---

## How to read this file
- ✅ Done and CI-verified
- 🔧 Built but has known gaps (see notes)
- ⬜ Not started
- 🔲 Blocked (reason noted)
- 🐛 Known bug — needs fix

---

## Phase 0 — Infrastructure & CI

| # | Task | Status | Notes |
|---|------|--------|-------|
| 0.1 | GitHub Actions CI (build-apk.yml + ci-tests.yml) | ✅ | Running, Node.js 24, Java 17, Flutter 3.22.x |
| 0.2 | Oracle server running (Flask admin + Watch API) | ✅ | Supervisor managed |
| 0.3 | SSH from Replit to Oracle | 🔲 Blocked | Port 22 unreachable from Replit. Use GitHub API for all file changes. |

---

## Phase 1 — Player (MX Player UI)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1.1 | MX Player exact layout (no right strip, clean top bar) | ✅ | Commit 20fda619 |
| 1.2 | _cycleAspect → _cycleFit compile fix | ✅ | |
| 1.3 | onLongPressPlay constructor gap fix | ✅ | |
| 1.4 | 9 player features wired (ambilight, track badges, memory, etc.) | ✅ | |
| 1.5 | Locale auto-select (Hindi-first), long-press restart, headphone multi-press | ✅ | |
| 1.6 | ambilightBlurRadius missing from PlayerPrefs (PS-001) | ✅ | |
| 1.7 | SearchScreen real trending (SR-001) | ✅ | Phase 1 — but BUG-A15 found: still hardcoded in search_screen |
| 1.8 | ContentCard long-press quick view (CC-001) | ✅ | |

---

## Phase 2 — Metadata Enrichment

| # | Task | Status | Notes |
|---|------|--------|-------|
| 2.1 | 6-tier fallback chain: TMDB→OMDB→AI→IMDbAPI.dev→YouTube→Google KG | ✅ | |
| 2.2 | metadata_lookup.py — IMDbAPI, YouTube, Google KG functions | ✅ | |
| 2.3 | metadata.py — Google KG step 6 | ✅ | |
| 2.4 | organizer.py — enrich_title_metadata helper | ✅ | |
| 2.5 | downloader.py — post-upload enrichment | ✅ | |

---

## Phase 3 — Poster Image System

| # | Task | Status | Notes |
|---|------|--------|-------|
| 3.1 | PosterService — permanent storage, never re-download | ✅ | |
| 3.2 | runBackgroundSync() — 100 posters/day background download | ✅ | Called from catalog_provider — confirm start from splash (BUG-A20) |
| 3.3 | saveFromJazzDrive() — zero-rated poster saving method | ✅ | |
| 3.4 | poster_path column in local SQLite | ✅ | |
| 3.5 | FIX: home_screen — use local poster_path not network URL | ✅ | |
| 3.6 | FIX: downloadAndCache → call LocalDb.savePosterPath() | ✅ | |
| 3.7 | FIX: jazzdrive_service → call PosterService.saveFromJazzDrive() | ✅ | |

---

## Phase 4 — Security (SQLCipher + Android Keystore)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 4.1 | Add sqflite_sqlcipher to pubspec | ✅ | **3.1.0+1 exact pin** — NEVER upgrade without checking CI |
| 4.2 | Android Keystore key generation on first run | ✅ | |
| 4.3 | Open SQLite with SQLCipher + Keystore key | ✅ | |
| 4.4 | Encrypt JazzDrive share folder URLs in SQLite | ✅ | |
| 4.5 | FlutterSecureStorage for auth tokens (not SQLite) | ✅ | |

> **sqflite_sqlcipher version lock:** 3.1.0+1. Never upgrade until CI is on Flutter 3.27+.

---

## Phase 5 — Device Binding

| # | Task | Status | Notes |
|---|------|--------|-------|
| 5.1 | Server: device_bindings table | ✅ | app_users.device_id/device_name/device_bound_at |
| 5.2 | Server: register device endpoint POST /api/auth/device | ✅ | Crashes with guest token — see BUG-A10 |
| 5.3 | Server: reject second device on login (409) | ✅ | |
| 5.4 | App: generate device fingerprint | ✅ | |
| 5.5 | App: send device_id with login | ✅ | |
| 5.6 | App: show device conflict error | ✅ | |
| 5.7 | App: device switch flow (OTP hook) | ✅ | WhatsApp primary. OTP UI gated by `otpDeviceSwitchEnabled=false`. Server OTP endpoints DO NOT EXIST. |
| 5.8 | Admin panel: reset device binding | ✅ | |

---

## Phase 6 — Data Usage Tracking

| # | Task | Status | Notes |
|---|------|--------|-------|
| 6.1 | App: byte counter in player | ✅ | |
| 6.2 | App: save bytes to SQLite every 30s | ✅ | |
| 6.3 | App: queue pending usage reports | ✅ | |
| 6.4 | App: flush queue on internet detection | ✅ | |
| 6.5 | Server: POST /api/usage endpoint | ✅ | |
| 6.6 | Server: monthly data counter | ✅ | |
| 6.7 | App: cache last known quota | ✅ | |
| 6.8 | App: local quota enforcement at stream start | ✅ | |
| 6.9 | App: auto-downgrade offline when plan expires | ✅ | |
| 6.10 | App: "Quota full" screen | ✅ | QuotaFullScreen — commit 29a8ff0 |

---

## Phase 7 — Delta JSON System

| # | Task | Status | Notes |
|---|------|--------|-------|
| 7.1 | Server: auto-generate delta JSON every 24h | ✅ | |
| 7.2 | Delta JSON format: metadata only | ✅ | |
| 7.3 | Server: auto-upload delta to JazzDrive | ✅ | |
| 7.4 | App: fetch delta from JazzDrive on startup | ✅ | |
| 7.5 | App: merge delta into local SQLite | ✅ | Uses ON CONFLICT — SQLite 3.24+ only (BUG-A04) |
| 7.6 | Admin panel: Zero-Rating Manager UI | ✅ | |
| 7.7 | Remove full catalog from JazzDrive | ✅ | |

---

## Phase 8 — Subscription Plans

| # | Task | Status | Notes |
|---|------|--------|-------|
| 8.1 | Server: plans table | ✅ | |
| 8.2 | Server: plan assignment on subscription | ✅ | |
| 8.3 | App: subscription screen | ✅ | |
| 8.4 | App: Jazz package comparison UI | ✅ | |
| 8.5 | App: "X% cheaper than Jazz" messaging | ✅ | |
| 8.6 | App: payment flow (TID) | ✅ | Hardcoded fallback numbers if DB empty (BUG-A12) |

---

## Phase 9 — SIMOSA Integration

| # | Task | Status | Notes |
|---|------|--------|-------|
| 9.1 | App: daily SIMOSA reminder card | ✅ | |
| 9.2 | App: deep link to SIMOSA | ✅ | |
| 9.3 | App: 7-day streak tracker | ✅ | |
| 9.4 | App: streak progress UI | ✅ | |
| 9.5 | App: Jazz partnership badge | ✅ | _JazzPartnerBadge in subscription_screen.dart |

---

## Phase 10 — WhatsApp Bot

| # | Task | Status | Notes |
|---|------|--------|-------|
| 10.1 | WA bot status | ✅ | Managed via /api/whatsapp/* in api.py |
| 10.2 | Telegram bot | 🐛 | Backend is skeleton — no real message handling |

---

## Phase 11 — Full Integration Audit (2026-05-29)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 11.1 | Server: POST /api/app/check endpoint | ✅ | Returns wrong package ID — BUG-A07 |
| 11.2 | App: call AppUpdateService.check() on splash | ✅ | |
| 11.3 | App: Profile — dynamic version via PackageInfo | ✅ | |
| 11.4 | App: Profile — subscription expiry countdown | ✅ | |
| 11.5 | Admin: DB Manager in nav | ✅ | |
| 11.6 | Fix server 500s — analytics + subscriptions u.name | ✅ | NULL as name fix applied |
| 11.7–11.10 | Notification bell, Continue Watching, TidStatus, VaultSettings | ✅ | All confirmed done |

---

## Phase 12 — FTS5 Full-Text Search

| # | Task | Status | Notes |
|---|------|--------|-------|
| 12.1 | catalogDbVersion 12 → 13 | ✅ | |
| 12.2 | CREATE VIRTUAL TABLE catalog_fts USING fts5 | ✅ | |
| 12.3 | rebuildFtsIndex() — called after catalog load | ✅ | |
| 12.4 | searchTitles() — FTS5 MATCH + LIKE fallback | ✅ | |

---

## Phase 13 — Audit Fixes (2026-05-30) — CURRENT PHASE

> These bugs were found during the full deep audit on 2026-05-30.
> Fix in priority order. See REINCARNATION.md for full bug details.

### 🔴 Critical — Breaks Functionality

| ID | Task | Status | File to Fix | Priority |
|----|------|--------|-------------|----------|
| BUG-A02 | Normalize `media_type` to `"show"` for TV series in library.py delta output | ✅ | `radd-hub/hub/routes/library.py` | P1 — TV shows invisible |
| BUG-A01 | Change `year` to `INTEGER` in db.py DDL + fix `fromJson` in catalog_item.dart | ✅ | `hub/db.py` + `lib/models/catalog_item.dart` | P1 — year never shown |
| BUG-A03 | Fix `is_active` serialization — return `1`/`0` int not bool in `/api/auth/me` | ✅ | `hub/routes/mobile_api.py` | P2 — subscription status unreliable |
| BUG-A19 | Create `HistoryApi` class in Flutter + wire to server history endpoints | ✅ | New file: `lib/core/api/history_api.dart` | P2 — history lost on reinstall |
| BUG-A05 | Fix vault PIN length: align `_expectedPinLength` (6) with setup mode (4) | ✅ | `lib/screens/vault_lock_screen.dart` | P2 — vault unusable after 4-digit setup |
| BUG-A06 | Fix `session_err` NameError in `app.py` `download_proxy()` | ✅ | `radd-hub/hub/app.py` | P2 — download proxy crashes |
| BUG-A07 | Fix `/api/app/check` package ID — verified false positive, no fix needed | 🚫 N/A | `hub/routes/mobile_api.py` | P2 — force update never works |
| BUG-A04 | Replace `ON CONFLICT(id) DO UPDATE` with compatible INSERT OR REPLACE or version check | ✅ | `lib/core/db/local_db.dart` | P3 — crashes Android 8 |

### 🟠 Data / Logic Errors

| ID | Task | Status | File to Fix | Priority |
|----|------|--------|-------------|----------|
| BUG-A11 | Add seconds↔milliseconds conversion in history sync (server=sec, Flutter=ms) | ✅ | `lib/core/api/history_api.dart` (when created) | P2 — implement alongside BUG-A19 |
| BUG-A09 | Fix `/api/notifications/read` to actually filter by IDs from request body | ✅ | `hub/routes/mobile_api.py` | P3 |
| BUG-A10 | Fix `POST /api/auth/device` crash (HTTP 500) when called with guest token | ✅ | `hub/routes/mobile_api.py` | P2 |
| BUG-A12 | Replace `03xxxxxxxxx` placeholder payment numbers in subscription_screen.dart | ✅ | `lib/screens/subscription_screen.dart` | P2 |
| BUG-A14 | Fix silent error swallowing in `profile_screen.dart` `_loadExtras()` | ✅ | `lib/screens/profile_screen.dart` | P3 |
| BUG-A15 | Replace `_staticTrending` with real data from catalog (top-rated or most-watched) | ✅ | `lib/screens/search_screen.dart` | P3 |
| BUG-A16 | Fix genre chip duplication: trim whitespace in `_extractGenres()` | ✅ | `lib/screens/search_screen.dart` | P3 |
| BUG-A13 | Add Pakistani phone prefix validation to register_screen | ✅ | `lib/screens/register_screen.dart` | P4 |
| BUG-A17 | `jazzdrive_login`, `list_folders` etc — verified false positive, delegate to _legacy | 🚫 N/A | `radd-hub/hub/jazzdrive.py` | P3 |
| BUG-A18 | GSheets `_legacy` import — verified false positive, not present in sync.py | 🚫 N/A | `radd-hub/hub/sync.py` | P4 |

### 🟡 Missing / Unwired Features

| ID | Task | Status | Notes | Priority |
|----|------|--------|-------|----------|
| BUG-A21 | Add "Reset Player Settings" button in player_settings_screen | ✅ | Wire to `PlayerPrefs.reset()` | P4 |
| BUG-A22 | Add "Clear Watch Progress" option to history UI | ✅ | Wire to `LocalDb.clearPosition(fileId)` | P4 |
| BUG-A23 | Add "Clear Bookmarks" to scene bookmarks panel | ✅ | Wire to `SceneBookmarkStore.deleteAll(fileId)` | P4 |
| BUG-A24 | `BingeGuardController` — verified false positive, already wired in player | 🚫 N/A | Check player_screen.dart | P3 |
| BUG-A25 | `SmartIntroStore` — verified false positive, already wired in player | 🚫 N/A | Check player_screen.dart | P3 |
| BUG-A26 | Expose recommendation engine via API endpoint | ✅ | Add `/api/catalog/recommended` in mobile_api.py | P4 |
| BUG-A27 | Remove orphaned `AuthApi.bindDevice()` dead code | ✅ | `lib/core/api/auth_api.dart` | P5 (cleanup) |
| BUG-A20 | Confirm `PosterService.runBackgroundSync()` called from splash | ✅ | `lib/screens/splash_screen.dart` | P3 |
| BUG-A28 | Implement download quota: server returns `downloads_used_today` | ✅ | `hub/routes/mobile_api.py` | P4 |
| BUG-A29 | Mid-stream usage cutoff (check quota every N minutes during playback) | ✅ | `lib/screens/player_screen.dart` | P4 |

### 🔵 Infrastructure / Config

| ID | Task | Status | Notes | Priority |
|----|------|--------|-------|----------|
| BUG-A30 | Replace hardcoded IP in `remote_config.dart` with domain name | ✅ | Needs DNS setup for Oracle | P3 |
| BUG-A31 | Add SSL to Oracle server — self-signed cert + nginx HTTPS on port 443 | ✅ | Nginx + Let's Encrypt or Cloudflare | P2 |
| BUG-A32 | Persist `FLASK_SECRET_KEY` across server restarts | ✅ | Save generated key to .env, don't regenerate | P2 |
| BUG-A33 | Upgrade to Material Design 3 + add light theme | ⬜ Deferred — full design sprint | `lib/app.dart` + `lib/core/theme/` | P4 |
| BUG-A34 | Remove `_watch_prototype/` directory (dead legacy code) | ✅ | — | P5 (cleanup) |

---

## Previously Fixed Bugs

| ID | Description | Fixed In |
|----|------------|---------|
| BUG-P3 | AppConstants.supportWhatsApp placeholder | Phase 11 |
| BUG-P4 | Zero-rating page stale count | Phase 11 |
| CI compile | `oldVersion` → `oldV` in v12 migration | Commit 5bd1ac75 |
| Continue Watching TV | Shows now match via episodes list | Commit f506b917 |

---

## Phase 13 — COMPLETE

All 34 audit bugs resolved:
- ✅ Fixed via code: 26 bugs
- 🚫 False positives: 5 bugs (A07, A17, A18, A24, A25)
- ⬜ Deferred: A33 (MD3/light theme — design sprint)

## Phase 14 — Next Tasks

| # | Task | Priority |
|---|------|----------|
| 14.1 | Upgrade to Material Design 3 + add light theme | P4 |
| 14.2 | Oracle git conflict resolution (needs manual SSH from server or user action) | P3 |
| 14.3 | When domain is available: replace self-signed cert with Let's Encrypt | P2 |
| 14.4 | Set `AppConstants.supportWhatsApp` to real number before production release | P1 |

**Confirm CI is still green before any new code changes.**

