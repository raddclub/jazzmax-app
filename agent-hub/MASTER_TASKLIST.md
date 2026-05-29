# RaddFlix — Master Task List
> Last updated: 2026-05-29 (Phase 7 complete)
> Read PRODUCT_CONTEXT.md first. This file tracks every task — done, in progress, and upcoming.
> Update this file at the end of every session.

---

## How to read this file
- ✅ Done and verified
- 🔧 Built but has known gaps (see notes)
- ⬜ Not started
- 🔲 Blocked (reason noted)

---

## Phase 0 — Infrastructure & CI

| # | Task | Status | Notes |
|---|------|--------|-------|
| 0.1 | GitHub Actions CI (build-apk.yml + ci-tests.yml) | ✅ | Running, Node.js 24 env var added |
| 0.2 | Oracle server running (Flask admin + Watch API) | ✅ | Supervisor managed |
| 0.3 | SSH from Replit to Oracle | 🔲 Blocked | Port 22 unreachable from Replit container. Use GitHub API for all file changes. |

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
| 3.3 | saveFromJazzDrive() — zero-rated poster saving method | 🔧 Built | **Gap 3: never called from jazzdrive_service.dart** |
| 3.4 | poster_path column in local SQLite | ✅ | Schema exists |
| 3.5 | **FIX**: home_screen — use local poster_path not network URL | ✅ | CachedNetworkImage ignores local file |
| 3.6 | **FIX**: downloadAndCache → call LocalDb.savePosterPath() | ✅ | Path never saved to DB after download |
| 3.7 | **FIX**: jazzdrive_service → call PosterService.saveFromJazzDrive() | ✅ | Method exists but nothing calls it |

---

## Phase 4 — Security (SQLCipher + Android Keystore)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 4.1 | Add sqflite_sqlcipher to pubspec | ✅ | Replaces sqflite |
| 4.2 | Android Keystore key generation on first run | ✅ | keystore.dart exists, wire it to DB open |
| 4.3 | Open SQLite with SQLCipher + Keystore key | ✅ | local_db.dart openDatabase call |
| 4.4 | Encrypt JazzDrive share folder URLs in SQLite | ✅ | Most critical field to protect |
| 4.5 | FlutterSecureStorage for auth tokens (not SQLite) | ✅ | Check if already done |

---

## Phase 5 — Device Binding (1 account = 1 device)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 5.1 | Server: device_bindings table in DB | ⬜ | user_id, device_id, device_model, bound_at |
| 5.2 | Server: register device endpoint POST /api/auth/bind-device | ⬜ | |
| 5.3 | Server: reject second device on login | ⬜ | |
| 5.4 | App: generate device fingerprint on first login | ⬜ | device_id.dart exists, check if wired |
| 5.5 | App: send device_id with every login request | ⬜ | |
| 5.6 | App: show "account active on another device" error | ⬜ | |
| 5.7 | App: device switch flow (OTP verification) | ⬜ | |
| 5.8 | Admin panel: reset device binding for a user | ⬜ | |

---

## Phase 6 — Data Usage Tracking

| # | Task | Status | Notes |
|---|------|--------|-------|
| 6.1 | App: byte counter in player (media_player bytes callback) | ⬜ | Count every chunk streamed |
| 6.2 | App: save bytes to encrypted SQLite every 30s | ⬜ | usage_log table |
| 6.3 | App: queue pending usage reports | ⬜ | pending_usage_bytes in SQLite |
| 6.4 | App: flush queue on internet detection | ⬜ | connectivity_plus package |
| 6.5 | Server: POST /api/usage endpoint | ⬜ | Add to server + sync to DB |
| 6.6 | Server: monthly data counter per account | ⬜ | data_used_bytes, data_limit_bytes |
| 6.7 | App: cache last known quota from server | ⬜ | remaining_gb, plan_limit_gb |
| 6.8 | App: local quota enforcement (block when = 0) | ⬜ | Even zero-rated streaming blocked |
| 6.9 | App: auto-downgrade to free tier when plan expires offline | ⬜ | Check plan_expires_at locally |
| 6.10 | App: "Quota full — sync to unlock" screen | ⬜ | |

---

## Phase 7 — Delta JSON System (Zero-Rating Catalog Updates)

| # | Task | Status | Notes |
|---|------|--------|-------|
| 7.1 | Server: auto-generate delta JSON every 24h | ✅ | Cron job or APScheduler |
| 7.2 | Delta JSON format: metadata only, NO file IDs, NO share URLs | ✅ | id, title, year, description, poster_url, genres, is_free |
| 7.3 | Server: auto-upload delta to JazzDrive (replace old file) | ✅ | Use jazzdrive.py upload |
| 7.4 | App: fetch delta from JazzDrive on startup (zero-rated) | ✅ | jazzdrive_service.dart |
| 7.5 | App: merge delta into local SQLite (INSERT OR IGNORE) | ✅ | catalog_provider.dart |
| 7.6 | Admin panel: Zero-Rating Manager UI update (show delta not full catalog) | ✅ | zero_rating.py |
| 7.7 | Remove full catalog from JazzDrive (security) | ✅ | Only delta should be on JazzDrive |

---

## Phase 8 — Subscription Plans & Enforcement

| # | Task | Status | Notes |
|---|------|--------|-------|
| 8.1 | Server: plans table (Basic 30GB, Standard 50GB, Premium 100GB) | ⬜ | |
| 8.2 | Server: plan assignment on subscription | ⬜ | |
| 8.3 | App: subscription screen with plan cards | ⬜ | subscription_screen.dart exists |
| 8.4 | App: Jazz package comparison UI | ⬜ | Show Rs. savings vs buying Jazz data alone |
| 8.5 | App: "X% cheaper than Jazz" messaging | ⬜ | |
| 8.6 | App: payment flow (what gateway? TBD) | ⬜ | Decide: JazzCash? Easypaisa? |

---

## Phase 9 — SIMOSA Integration

| # | Task | Status | Notes |
|---|------|--------|-------|
| 9.1 | App: daily SIMOSA reminder card on home screen | ⬜ | Show only once per day |
| 9.2 | App: deep link to SIMOSA (com.jazz.world) or Play Store | ⬜ | url_launcher package |
| 9.3 | App: 7-day streak tracker (local, SQLite) | ⬜ | Track daily taps |
| 9.4 | App: streak progress UI (Day 1-7, MB reward) | ⬜ | |
| 9.5 | App: Jazz partnership badge on subscription screen | ⬜ | "Powered by Jazz zero-rating ⚡" |

---

## Phase 10 — WhatsApp Bot

| # | Task | Status | Notes |
|---|------|--------|-------|
| 10.1 | WA bot status | ⬜ | See wa-bot/. Node.js 20, wa-web.js |

---

## Known Issues / Bugs Open

| ID | Description | File | Priority |
|----|------------|------|---------|
| ~~BUG-P1~~ | ~~Poster system 3 gaps~~ | ~~Fixed (2026-05-29)~~ | ~~High~~ |
| BUG-P2 | stream cache TTL is 180 min but applies to both watch + download (ok) | constants.dart | Low |
| BUG-P3 | AppConstants.supportWhatsApp = '923XXXXXXXXX' placeholder | constants.dart | Pre-launch |
| BUG-P4 | Zero-Rating page shows stale 69 titles (old db_update.json, May 26) | zero_rating.py | Low |
| ~~BUG-P5~~ | ~~Full catalog currently on JazzDrive~~ | ~~zero_rating.py~~ | ~~High~~ |

---

## Next Session Starting Point

**Read in order:**
1. `agent-hub/PRODUCT_CONTEXT.md` — full context
2. `agent-hub/MASTER_TASKLIST.md` — this file, check what's ⬜
3. `agent-hub/STREAMING_ARCHITECTURE.md` — streaming rules
4. `agent-hub/history/TASK_LOG.md` — what each session did

**Recommended next tasks (in order):**
1. Phase 3 Tasks 3.5, 3.6, 3.7 — Fix poster system gaps (small, targeted, high impact)
2. Phase 4 — SQLCipher encryption (security foundation, needed before public launch)
3. Phase 7 — Delta JSON system (zero-rating catalog updates)
4. Phase 6 — Data usage tracking (needed for subscription enforcement)

