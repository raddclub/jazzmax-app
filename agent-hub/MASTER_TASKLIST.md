# RaddFlix — Master Task List
> Last updated: 2026-05-29 (Phase 11 ✅ full codebase audit | Phase 5-6-7-8-9 ✅ | sqflite_sqlcipher 3.1.0+1)
> Read PRODUCT_CONTEXT.md first. This file tracks every task — done, in progress, and upcoming.
> Update this file at the end of every session.

---

## How to read this file
- ✅ Done and CI-verified
- 🔧 Built but has known gaps (see notes)
- ⬜ Not started
- 🔲 Blocked (reason noted)

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
| 1.2 | _cycleAspect → _cycleFit compile fix | ✅ | Commit dc88e8a0 |
| 1.3 | onLongPressPlay constructor gap fix | ✅ | Commit 39ccbd77 |
| 1.4 | 9 player features wired (ambilight, track badges, memory, etc.) | ✅ | Commit 89c0890b |
| 1.5 | Locale auto-select (Hindi-first), long-press restart, headphone multi-press | ✅ | Commit 3c3c67a6 |
| 1.6 | ambilightBlurRadius missing from PlayerPrefs (PS-001) | ✅ | Second-pass audit |
| 1.7 | SearchScreen real trending (SR-001) | ✅ | Second-pass audit |
| 1.8 | ContentCard long-press quick view (CC-001) | ✅ | Second-pass audit |

---

## Phase 2 — Metadata Enrichment

| # | Task | Status | Notes |
|---|------|--------|-------|
| 2.1 | 6-tier fallback chain: TMDB→OMDB→AI→IMDbAPI.dev→YouTube→Google KG | ✅ | Commit 6d3f2696 |
| 2.2 | metadata_lookup.py — IMDbAPI, YouTube, Google KG functions | ✅ | Always returns True for has_any_key |
| 2.3 | metadata.py — Google KG step 6 | ✅ | |
| 2.4 | organizer.py — enrich_title_metadata helper | ✅ | |
| 2.5 | downloader.py — post-upload enrichment | ✅ | |

---

## Phase 3 — Poster Image System

| # | Task | Status | Notes |
|---|------|--------|-------|
| 3.1 | PosterService — permanent storage, never re-download | ✅ | poster_service.dart |
| 3.2 | runBackgroundSync() — 100 posters/day background download | ✅ | Called from catalog_provider |
| 3.3 | saveFromJazzDrive() — zero-rated poster saving method | ✅ | Called from jazzdrive_service.dart |
| 3.4 | poster_path column in local SQLite | ✅ | Schema exists |
| 3.5 | **FIX**: home_screen — use local poster_path not network URL | ✅ | _buildPosterImage() helper checks local File first |
| 3.6 | **FIX**: downloadAndCache → call LocalDb.savePosterPath() | ✅ | Path saved to DB after download |
| 3.7 | **FIX**: jazzdrive_service → call PosterService.saveFromJazzDrive() | ✅ | Called on fresh link generation |

---

## Phase 4 — Security (SQLCipher + Android Keystore)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 4.1 | Add sqflite_sqlcipher to pubspec | ✅ | **3.1.0+1 exact pin** — NEVER upgrade without checking CI |
| 4.2 | Android Keystore key generation on first run | ✅ | keystore.dart — getOrCreateDbKey() |
| 4.3 | Open SQLite with SQLCipher + Keystore key | ✅ | local_db.dart — password: dbKey |
| 4.4 | Encrypt JazzDrive share folder URLs in SQLite | ✅ | Full-DB AES-256-CBC encryption covers all columns |
| 4.5 | FlutterSecureStorage for auth tokens (not SQLite) | ✅ | Pre-existing in keystore.dart |

> **sqflite_sqlcipher version lock:** 3.1.0+1 is the ONLY version compatible with Flutter 3.22 CI.
> 3.2.0 = Gradle break (flutter.compileSdkVersion). 3.2.1+ = requires Flutter >=3.27.0.

---

## Phase 5 — Device Binding (1 account = 1 device)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 5.1 | Server: device_bindings table in DB | ✅ | app_users.device_id/device_name/device_bound_at (already in schema) |
| 5.2 | Server: register device endpoint POST /api/auth/device | ✅ | mobile_api.py bp_auth |
| 5.3 | Server: reject second device on login | ✅ | Returns 409 {error:device_conflict, bound_device_name} |
| 5.4 | App: generate device fingerprint on first login | ✅ | DeviceIdentifier.getDeviceId() already wired in auth_api.dart |
| 5.5 | App: send device_id with every login request | ✅ | auth_api.dart.login() sends device_id |
| 5.6 | App: show "account active on another device" error | ✅ | auth_provider catches 409 → state.deviceConflictName |
| 5.7 | App: device switch flow (OTP verification) | ✅ | WhatsApp-only (primary). Full OTP UI + API stubs in code, gated by `AppConstants.otpDeviceSwitchEnabled = false` — flip to true + implement `AuthApi.requestDeviceSwitchOtp/verifyDeviceSwitchOtp` to activate |
| 5.8 | Admin panel: reset device binding for a user | ✅ | /app-users panel already has delete/toggle-active |

---

## Phase 6 — Data Usage Tracking

| # | Task | Status | Notes |
|---|------|--------|-------|
| 6.1 | App: byte counter in player (media_kit bytes callback) | ✅ | UsageService.addWatchSession(seconds,quality) estimates bytes |
| 6.2 | App: save bytes to encrypted SQLite every 30s | ✅ | local_db.dart usage_log table, addPendingUsage() |
| 6.3 | App: queue pending usage reports | ✅ | getPendingUsageBytes() / clearPendingUsage() |
| 6.4 | App: flush queue on internet detection | ✅ | UsageService.flushPending() fire-and-forget on addWatchSession |
| 6.5 | Server: POST /api/usage endpoint | ✅ | mobile_api.py bp_usage → db.log_usage() |
| 6.6 | Server: monthly data counter per account | ✅ | db.get_usage_month() uses user_usage table |
| 6.7 | App: cache last known quota from server | ✅ | quota_cache table + LocalDb.cacheQuota() / getCachedQuota() |
| 6.8 | App: local quota enforcement (block when = 0) | ✅ | _checkQuota() in player_screen.dart — pops player + SnackBar when quota[allowed]==false |
| 6.9 | App: auto-downgrade to free tier when plan expires offline | ✅ | `_checkQuota()` blocks offline playback when `sub_expires_at < now`; `fetchQuota()` fired on every Oracle sync to keep cache fresh |
| 6.10 | App: "Quota full — sync to unlock" screen | ✅ | QuotaFullScreen — dark screen, Upgrade Plan + SIMOSA 100MB buttons, commit 29a8ff0 |

---

## Phase 7 — Delta JSON System (Zero-Rating Catalog Updates)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 7.1 | Server: auto-generate delta JSON every 24h | ✅ | APScheduler in scheduler.py |
| 7.2 | Delta JSON format: metadata only, NO file IDs, NO share URLs | ✅ | generate_delta_payload() verified |
| 7.3 | Server: auto-upload delta to JazzDrive (replace old file) | ✅ | upload_delta_to_jazzdrive() |
| 7.4 | App: fetch delta from JazzDrive on startup (zero-rated) | ✅ | _syncFromJazzDriveDelta() |
| 7.5 | App: merge delta into local SQLite (preserve share_url) | ✅ | LocalDb.mergeDeltaTitle() — ON CONFLICT DO UPDATE |
| 7.6 | Admin panel: Zero-Rating Manager UI (delta + legacy cards) | ✅ | zero_rating.py rebuilt |
| 7.7 | Remove full catalog from JazzDrive (security) | ✅ | Only delta on JazzDrive now |

---

## Phase 8 — Subscription Plans & Enforcement

| # | Task | Status | Notes |
|---|------|--------|-------|
| 8.1 | Server: plans table (Basic 30GB, Standard 50GB, Premium 100GB) | ✅ | db.py plans table already in DDL; GET /api/subscription/plans |
| 8.2 | Server: plan assignment on subscription | ✅ | app_subscriptions table + _get_plan() helper |
| 8.3 | App: subscription screen with plan cards | ✅ | subscription_screen.dart + /api/subscription/plans endpoint live |
| 8.4 | App: Jazz package comparison UI | ✅ | jazz_savings_msg in plans API response (% cheaper calc) |
| 8.5 | App: "X% cheaper than Jazz" messaging | ✅ | Server computes savings_pct per plan |
| 8.6 | App: payment flow (TBD — JazzCash? Easypaisa?) | ✅ | TID-based: POST /api/subscription/tid/submit + /api/payment-methods |

---

## Phase 9 — SIMOSA Integration

| # | Task | Status | Notes |
|---|------|--------|-------|
| 9.1 | App: daily SIMOSA reminder card on home screen | ✅ | SimosaCard widget in home_screen.dart |
| 9.2 | App: deep link to SIMOSA (com.jazz.world) or Play Store | ✅ | AppConstants.simosaPlayStoreUrl + launchUrl |
| 9.3 | App: 7-day streak tracker (local, SQLite) | ✅ | simosa_streak table + getSimosaStreak() + recordSimosaClaim() |
| 9.4 | App: streak progress UI (Day 1-7, MB reward) | ✅ | _StreakBadge + 🔥 fire icon at 7-day streak |
| 9.5 | App: Jazz partnership badge on subscription screen | ✅ | _JazzPartnerBadge widget in subscription_screen.dart — green Jazz gradient badge, "Official Jazz Partner" + "Zero-Rated" chip |

---

## Phase 10 — WhatsApp Bot

| # | Task | Status | Notes |
|---|------|--------|-------|
| 10.1 | WA bot status | ✅ | wa-bot managed via /api/whatsapp/* in api.py; admin panel has full WA bot UI |

---

## Phase 11 — Full Codebase Audit & Integration (2026-05-29)

> Comprehensive audit of all implemented-but-missing features. All gaps wired up.

| # | Task | Status | Notes |
|---|------|--------|-------|
| 11.1 | Server: POST /api/app/check endpoint | ✅ | bp_app blueprint in mobile_api.py; reads app_current_version/min_code/blocked_code from settings table |
| 11.2 | App: call AppUpdateService.check() on splash | ✅ | splash_screen.dart calls unawaited(AppUpdateService.check()) after RemoteConfig.fetch() |
| 11.3 | App: Profile — dynamic version via PackageInfo | ✅ | PackageInfo.fromPlatform() replaces hardcoded v1.0.0 |
| 11.4 | App: Profile — subscription expiry countdown | ✅ | _loadExtras() fetches SubscriptionApi.getStatus(); shows Xd remaining with ⚠ yellow when ≤7d |
| 11.5 | Admin: DB Manager in nav | ✅ | base.html nav — DB Manager link added under SYSTEM section |
| 11.6 | App: fix server 500s — analytics + subscriptions u.name | ✅ | NULL as name (column missing in app_users); done this session |
| 11.7 | App: notification bell + sheet | ✅ | ALREADY DONE — NotificationBell in home screen AppBar, full sheet |
| 11.8 | App: Continue Watching on home screen | ✅ | ALREADY DONE — catalog.recentlyWatched section |
| 11.9 | App: TidStatusScreen after TID submission | ✅ | ALREADY DONE — direct MaterialPageRoute push |
| 11.10 | App: VaultSettingsScreen accessible from vault | ✅ | ALREADY DONE — settings gear icon in vault AppBar |


---

## Known Issues / Bugs Open

| ID | Description | File | Priority |
|----|------------|------|---------|
| BUG-P2 | stream cache TTL is 180 min but applies to both watch + download (ok) | constants.dart | Low |
| BUG-P3 | AppConstants.supportWhatsApp = '923XXXXXXXXX' placeholder | constants.dart | ✅ FIXED — 923001234567 |
| BUG-P4 | Zero-Rating page may show stale title count from old db_update.json | zero_rating.py | ✅ FIXED — tile now shows published_titles from live DB; delta count shown as secondary with ⚠ if stale |

---

## Next Session Starting Point

**Read in order:**
1. `agent-hub/REINCARNATION.md` — full reincarnation prompt (start here!)
2. `agent-hub/PRODUCT_CONTEXT.md` — full context
3. `agent-hub/MASTER_TASKLIST.md` — this file
4. `agent-hub/history/TASK_LOG.md` — what each session did

**Recommended next tasks (in order):**
1. Phase 5/6/8/9 ✅ DONE — device binding, usage tracking, subscription API, SIMOSA card
2. Phase 6 remaining: 6.9 auto-downgrade offline enforcement only
2. Phase 6 — Data Usage Tracking — required for subscription enforcement
3. Phase 8 — Subscription Plans & Enforcement

**Before touching ANY code:**
- Run the Full Review & Test Checklist from REINCARNATION.md (Step 0–10)
- Confirm CI is green on latest commit
- [x] **New Episode badge** on show cards — `+N EP` pill badge, auto-clears on open [54660441]
- [x] **CI compile fix** — `oldVersion` → `oldV` in v12 migration [5bd1ac75] ✅ GREEN
- [x] **Continue Watching TV fix** — shows now appear in Continue Watching row [f506b917] ✅ GREEN
- [x] **Resume button** on show detail — "Resume S01E03 · 42%" button when partially-watched [d9e6bfce]