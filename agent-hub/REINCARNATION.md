# RaddFlix — Reincarnation Prompt (2026-05-29)

> **Give this entire document to the next AI session to fully reincarnate context.**
> Copy everything from the triple-dash below to the end of the file.

---

## Who You Are

You are the AI agent continuing development of **RaddFlix** — a Pakistani streaming platform where Jazz SIM users watch movies and dramas for **free** (zero data cost) via JazzDrive zero-rating. You are working on GitHub repo `raddclub/raddflix-app`. The Oracle server at `92.4.95.252` is SSH-unreachable from Replit — use GitHub API for ALL file operations.

Previous sessions built Phases 1–12. CI is green as of commit `a463913c` (2026-05-30).

---

## CRITICAL RULES — Violate any of these and you break the product

1. **NEVER add a server-side stream URL resolver.** Stream URLs are generated LOCALLY in the app from SQLite. The server never serves or proxies streams. See STREAMING_ARCHITECTURE.md.
2. **NEVER touch `/opt/jazzmax/radd-hub/hub/_legacy/`** — scanner.py imports from there. Deleting it breaks the entire content pipeline.
3. **NEVER force-push** — always `"force": false` in GitHub API PATCH calls.
4. **NEVER write "JazzMAX" or "Zeno"** — the app is **RaddFlix** (capital R, capital F). Dead names.
5. **NEVER put JazzDrive share folder URLs in the delta JSON** — delta is metadata only (id, title, year, description, poster_url, genres, is_free, media_type, language, status, is_ongoing, rating, season_count, episode_count, db_version). NO file_id, NO share_url, NO folder_share_url.
6. **NEVER upgrade `sqflite_sqlcipher` above `3.1.0+1`** — 3.2.0 breaks Gradle on Flutter 3.22 CI (`flutter.compileSdkVersion` not found); 3.2.1+ requires Flutter >=3.27.0. Stay on `3.1.0+1` until CI is upgraded to Flutter 3.27+.
7. **ALWAYS update MASTER_TASKLIST.md** when completing or discovering tasks.
8. **ALWAYS append to TASK_LOG.md** at the end of every session.

---

## GitHub API Commit Pattern (the ONLY way to push — no git commands)

```bash
# 1. Get HEAD SHA
HEAD_SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/raddclub/raddflix-app/git/refs/heads/main" \
  | jq -r '.object.sha')

# 2. Get tree SHA
TREE_SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/raddclub/raddflix-app/git/commits/$HEAD_SHA" \
  | jq -r '.tree.sha')

# 3. Create blobs (for large files >50KB: use base64 + node to write payload)
BLOB=$(curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/raddclub/raddflix-app/git/blobs" \
  -d "{\"encoding\":\"base64\",\"content\":\"$(base64 -w0 /tmp/yourfile)\"}" \
  | jq -r '.sha')

# 4. Create tree (multi-file: add more objects to the array)
NEW_TREE=$(curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/raddclub/raddflix-app/git/trees" \
  -d "{\"base_tree\":\"$TREE_SHA\",\"tree\":[{\"path\":\"path/to/file\",\"mode\":\"100644\",\"type\":\"blob\",\"sha\":\"$BLOB\"}]}" \
  | jq -r '.sha')

# 5. Commit
NEW_COMMIT=$(curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/raddclub/raddflix-app/git/commits" \
  -d "{\"message\":\"your message\",\"tree\":\"$NEW_TREE\",\"parents\":[\"$HEAD_SHA\"]}" \
  | jq -r '.sha')

# 6. Update ref (NEVER force)
curl -s -X PATCH -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/raddclub/raddflix-app/git/refs/heads/main" \
  -d "{\"sha\":\"$NEW_COMMIT\",\"force\":false}"
```

---

## What's Built (Completed Phases)

### Phase 1 — MX Player UI ✅
- Exact MX Player layout (no right strip, clean top bar)
- 9 player features: ambilight, track badges, playback memory, AB loop, subtitle engine, quality badge, pip gesture, long-press speed, bookmarks
- Locale auto-select (Hindi audio first), long-press restart, headphone multi-press
- Player preferences (PlayerPrefs) with ambilightBlurRadius

### Phase 2 — Metadata Enrichment ✅
- 6-tier fallback chain: TMDB → OMDB → AI → IMDbAPI.dev → YouTube → Google KG
- `metadata_lookup.py` — all 6 enrichment functions
- `metadata.py` — Google KG step 6
- `organizer.py` — `enrich_title_metadata` helper
- `downloader.py` — post-upload enrichment

### Phase 3 — Poster Image System ✅
- `poster_service.dart` — permanent local storage, never re-downloads
- `runBackgroundSync()` — 100 posters/day background download
- `saveFromJazzDrive()` — zero-rated poster saving from JazzDrive link generation
- `poster_path` column in local SQLite
- **Gap 3.5 fixed** — home_screen uses local file path first, not always network URL
- **Gap 3.6 fixed** — `downloadAndCache()` now calls `LocalDb.savePosterPath()` after saving
- **Gap 3.7 fixed** — `jazzdrive_service.getStreamLink()` fires `PosterService.saveFromJazzDrive()` on fresh links

### Phase 4 — Security (SQLCipher + Android Keystore) ✅ CI GREEN
- `pubspec.yaml` — `sqflite_sqlcipher: 3.1.0+1` (exact pin — see CRITICAL RULES above)
- `keystore.dart` — `getOrCreateDbKey()` generates 44-char base64url key on first install, stores in Android Keystore via flutter_secure_storage, device-bound
- `local_db.dart` — opens SQLite with `password: dbKey` (AES-256-CBC); migration catch for unencrypted dev DBs
- JazzDrive share_url values are encrypted at rest automatically (full-DB encryption)
- Auth tokens already in flutter_secure_storage (Task 4.5 was pre-existing)

### Phase 7 — Delta JSON System ✅ CI GREEN
- **Server** `zero_rating.py` — `generate_delta_payload()` builds metadata-only JSON, `upload_delta_to_jazzdrive()` uploads to JazzDrive
- **Server** `scheduler.py` — APScheduler job runs delta generation every 24h
- **Server** `api.py` — `GET /api/catalog/delta` endpoint serves delta.json directly
- **App** `local_db.dart` — `mergeDeltaTitle()` uses `ON CONFLICT(id) DO UPDATE SET` — preserves share_url/poster_path from Oracle sync, only overwrites metadata fields
- **App** `sync_service.dart` — `_syncFromJazzDriveDelta()` fetches delta from JazzDrive, calls `mergeDeltaTitle()` for each title, uses version gating to skip if already up to date
- **App** `constants.dart` — `jazzDriveDeltaUrl = 'http://92.4.95.252/api/catalog/delta'`
- **Admin** Zero-Rating Manager UI rebuilt — shows Delta JSON card (count, size, timestamp) + old db_update.json card separately; security note about full catalog

### Phase 12 — Full-Text Search (FTS5) ✅ CI GREEN
- `catalogDbVersion` 13: `catalog_fts` FTS5 virtual table (content='titles')
- `searchTitles()` uses FTS MATCH with prefix terms — handles partial names and Roman Urdu transliterations
- `rebuildFtsIndex()` fired fire-and-forget after every catalog load in catalog_provider
- Falls back to LIKE on fresh install before first sync

### This session also fixed (2026-05-30)
- **CI compile error** (`oldVersion` → `oldV` in v12 migration) — was breaking builds for 2 commits
- **Continue Watching shows** — TV shows now appear; fixed null `fileId` by searching `show.episodes`
- **Resume button** on show detail — "Resume S01E03 · 42%" above episode list

---

## Current CI Status

- Workflow: `build-apk.yml` — Flutter 3.22.x, Java 17, AGP 8, ubuntu-latest
- Last successful commit: `a463913c` (2026-05-30) — all session commits ✅✅
- CI includes Gradle namespace patch for legacy pub packages (auto-patches `flutter.compileSdkVersion` → `34`)

**Always check CI first:**
```bash
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/raddclub/raddflix-app/actions/runs?per_page=3" \
  | jq -r '.workflow_runs[] | "\(.status) \(.conclusion // "running") \(.created_at[0:10]) \(.head_sha[0:8]) \(.head_commit.message | split("\n")[0])"'
```

---

## Recommended Next Tasks (Priority Order)

### Priority 1 — OTP Device Switch (Phase 5.7)
- Flip `AppConstants.otpDeviceSwitchEnabled = true` in constants.dart
- Implement `AuthApi.requestDeviceSwitchOtp()` and `verifyDeviceSwitchOtp()` pointing to real Oracle OTP endpoint

### Priority 2 — Player Poster Saving on Stream
- `jazzdrive_service.getStreamLink()` — pass `titleId` parameter through, call `PosterService.saveFromJazzDrive()` on fresh link

### Priority 3 — Offline Banner
- Show "Offline — cached content" banner using `connectivity_plus` (already in pubspec)

### Priority 4 — Search Description Search
- FTS already indexes `description` — no DB change needed; update hint text in search bar

---

## Original Recommended Next Tasks (archived — Phases 5–12 now done)

### Option A — Phase 5: Device Binding (1 account = 1 device)
**Server work (via GitHub API → deployed to Oracle):**
- 5.1: Add `device_bindings` table (user_id, device_id, device_model, bound_at)
- 5.2: `POST /api/auth/bind-device` — register device fingerprint on first login
- 5.3: Login endpoint rejects second device (returns 409 with `{"error":"device_conflict"}`)
- 5.4: App `device_id.dart` — verify it's generating fingerprint on first login
- 5.5: App sends `device_id` with every login request
- 5.6: App shows "Account active on another device" error screen
- 5.7: Device switch flow (OTP or admin reset)
- 5.8: Admin panel: reset device binding for a user

### Option B — Phase 6: Data Usage Tracking
**App work (zero server access needed):**
- 6.1: Byte counter in player via media_kit bytes callback
- 6.2: Save bytes to encrypted SQLite every 30s (usage_log table)
- 6.3: Queue pending usage reports in SQLite
- 6.4: Flush queue on internet detection (connectivity_plus)
- 6.5-6.10: Server endpoints + quota enforcement + UI

### Option C — Phase 8: Subscription Plans
- Backend: plans table, plan assignment, subscription screen UI

---

## Full Review & Test Checklist

**Run this before starting any new work to verify all prior phases are correct.**

### Step 0: CI Health
```bash
# Must show "completed success" for latest commit
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/raddclub/raddflix-app/actions/runs?per_page=2" \
  | jq -r '.workflow_runs[] | "\(.status) \(.conclusion) \(.name)"'
```
**Pass criteria:** Both `Build RaddFlix APK` and `RaddFlix CI` show `completed success`.

---

### Step 1: pubspec.yaml Verification
```bash
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/pubspec.yaml" \
  | grep -E "sqflite|sdk:|flutter:"
```
**Must see:**
- `sqflite_sqlcipher: 3.1.0+1` — exact pin, no `^` caret
- `sdk: '>=3.3.0 <4.0.0'`
- `flutter: '>=3.19.0'`
- NO `sqflite:` (plain sqflite must be removed)
- NO `sqflite_sqlcipher: ^3.2` or higher

---

### Step 2: local_db.dart Verification
```bash
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/core/db/local_db.dart" \
  | grep -n "sqflite_sqlcipher\|password\|Keystore\|mergeDeltaTitle\|ON CONFLICT"
```
**Must see:**
- `import 'package:sqflite_sqlcipher/sqflite.dart';` (NOT sqflite)
- `password: dbKey` inside `openDatabase()` call
- `Keystore.getOrCreateDbKey()` called before openDatabase
- `mergeDeltaTitle` method defined
- `ON CONFLICT(id) DO UPDATE SET` in mergeDeltaTitle

```bash
# Verify mergeDeltaTitle does NOT overwrite share_url
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/core/db/local_db.dart" \
  | grep -A 30 "mergeDeltaTitle" | grep "share_url"
```
**Must NOT see** `share_url` in the INSERT or UPDATE columns of mergeDeltaTitle — share_url must be preserved only from Oracle sync (upsertTitle).

---

### Step 3: sync_service.dart Verification
```bash
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/core/db/sync_service.dart" \
  | grep -n "_syncFromJazzDriveDelta\|mergeDeltaTitle\|jazzDriveDeltaUrl\|share_url"
```
**Must see:**
- `_syncFromJazzDriveDelta()` method defined
- `LocalDb.mergeDeltaTitle(` called inside it
- `AppConstants.jazzDriveDeltaUrl` referenced
- **Must NOT see** `share_url` being passed to mergeDeltaTitle (delta carries no share_url)

---

### Step 4: Delta JSON Security Check
```bash
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/radd-hub/hub/routes/zero_rating.py" \
  | grep -E "file_id|share_url|folder_share_url|file_url" | head -20
```
**Must NOT see** any of `file_id`, `share_url`, `folder_share_url` in `generate_delta_payload()` output fields. The comment `# NO file_id, NO share_url` should be present.

```bash
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/radd-hub/hub/routes/api.py" \
  | grep -n "catalog/delta\|delta.json"
```
**Must see** the `/api/catalog/delta` route registered.

---

### Step 5: Scheduler Verification
```bash
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/radd-hub/hub/scheduler.py" \
  | grep -E "delta|24|hours|generate_delta"
```
**Must see** a 24-hour scheduled job calling `generate_delta_payload()` or similar.

---

### Step 6: Poster System Verification
```bash
# Gap 3.5 — home_screen uses local file
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/screens/home_screen.dart" \
  | grep -E "posterPath|dart:io|File\(|_buildPosterImage" | head -5
```
**Must see** `posterPath` check and `dart:io` import (for local File) in home_screen.

```bash
# Gap 3.6 — savePosterPath called after download
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/core/services/poster_service.dart" \
  | grep -E "savePosterPath|LocalDb\." | head -5
```
**Must see** `LocalDb.savePosterPath(` called in poster_service.dart.

```bash
# Gap 3.7 — saveFromJazzDrive called on stream link generation
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/core/services/jazzdrive_service.dart" \
  | grep -E "saveFromJazzDrive|PosterService\." | head -5
```
**Must see** `PosterService.saveFromJazzDrive(` called in jazzdrive_service.dart.

---

### Step 7: Keystore Verification
```bash
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/core/security/keystore.dart" \
  | grep -E "getOrCreateDbKey|dart:math|dart:convert|base64" | head -10
```
**Must see** `getOrCreateDbKey()` method, `dart:math` (for Random.secure()), `dart:convert` (for base64url encoding).

---

### Step 8: Constants Verification
```bash
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/core/constants.dart" \
  | grep -E "jazzDriveDelta|92.4.95.252|supportWhatsApp"
```
**Must see:**
- `jazzDriveDeltaUrl` pointing to `http://92.4.95.252/api/catalog/delta`
- `supportWhatsApp` — verify if still placeholder `923XXXXXXXXX` (BUG-P3, pre-launch fix)

---

### Step 9: Open Bugs Check
```bash
# BUG-P2: stream_cache TTL — acceptable
# BUG-P3: supportWhatsApp placeholder
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/core/constants.dart" \
  | grep -i "whatsapp"

# BUG-P4: zero_rating page showing stale title count
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/radd-hub/hub/routes/zero_rating.py" \
  | grep -E "69|stale|db_update_info" | head -5
```

---

### Step 10: Full Architecture Sanity Check
```bash
# Confirm no server-side stream resolver exists
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/core/db/sync_service.dart" \
  | grep -E "streamUrl.*server|getStreamLink.*server|stream.*92\.4" | wc -l
```
**Must return `0`** — no server calls for stream URLs anywhere in sync_service.

```bash
# Confirm JazzDrive service generates streams locally (no server call in getStreamLink)
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/core/services/jazzdrive_service.dart" \
  | grep -B2 -A5 "getStreamLink" | head -30
```
**Must see** stream link generated from local share_url, not from a server API call.

---

### Step 11: FTS5 Search Verification
```bash
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/core/db/local_db.dart" \
  | grep -E "catalog_fts|fts5|rebuildFtsIndex|MATCH"
```
**Must see:**
- `CREATE VIRTUAL TABLE IF NOT EXISTS catalog_fts`
- `USING fts5(title, description, content='titles', content_rowid='id')`
- `rebuildFtsIndex()` method defined
- `catalog_fts MATCH` in searchTitles

```bash
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/core/constants.dart" \
  | grep "catalogDbVersion"
```
**Must see:** `catalogDbVersion = 13` (not 12).

---

### Step 12: Continue Watching + Resume Button Verification
```bash
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/providers/catalog_provider.dart" \
  | grep -E "show.episodes|seenIds|outer:"
```
**Must see:** `show.episodes` iteration in `_loadRecentlyWatched`.

```bash
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/raddflix_flutter/lib/screens/show_detail_screen.dart" \
  | grep -E "_resumeEpisodeIndex|Resume S"
```
**Must see:** `_resumeEpisodeIndex` field and `Resume S` button text.

---

## Key File Locations (current as of 2026-05-30)

```
raddflix_flutter/
├── pubspec.yaml                             ← sqflite_sqlcipher: 3.1.0+1 (exact)
├── lib/core/
│   ├── constants.dart                       ← jazzDriveDeltaUrl, AppConstants
│   ├── db/
│   │   ├── local_db.dart                    ← SQLCipher open, mergeDeltaTitle, FTS5 search, all DB ops
│   │   └── sync_service.dart                ← Oracle + JazzDrive delta sync
│   ├── security/
│   │   ├── keystore.dart                    ← getOrCreateDbKey() + auth token storage
│   │   └── device_id.dart                   ← device fingerprint (wired?)
│   └── services/
│       ├── jazzdrive_service.dart           ← stream link generation, poster saving
│       └── poster_service.dart              ← poster download, savePosterPath
└── lib/screens/
    ├── player_screen.dart                   ← 3400+ lines MX Player UI
    └── home_screen.dart                     ← uses local posterPath before network URL

radd-hub/hub/
├── routes/
│   ├── zero_rating.py                       ← Delta JSON generation + upload, admin UI
│   └── api.py                               ← /api/catalog/delta endpoint
├── scheduler.py                             ← 24h delta auto-generation
├── metadata_lookup.py                       ← 6-tier enrichment functions
└── _legacy/                                 ← DO NOT DELETE (scanner.py imports)

agent-hub/
├── REINCARNATION.md                         ← this file
├── MASTER_TASKLIST.md                       ← task status (read before coding)
├── PRODUCT_CONTEXT.md                       ← full product context
├── STREAMING_ARCHITECTURE.md               ← streaming rules (immutable)
└── history/TASK_LOG.md                     ← session log
```

---

## Technical Notes (hard-won, don't repeat these mistakes)

### sqflite_sqlcipher version (CRITICAL)
| Version | Status | Reason |
|---------|--------|--------|
| 3.1.0+1 | ✅ USE THIS | Last version before Gradle break |
| 3.2.0   | ❌ BROKEN | build.gradle uses `flutter.compileSdkVersion` — fails on Flutter 3.22 CI |
| 3.2.1   | ❌ BROKEN | Requires Flutter >=3.27.0 — pub version solving fails on 3.22 |
| 3.3.0+  | ❌ BROKEN | Same as 3.2.1 |

When CI upgrades to Flutter 3.27+, you can re-evaluate. Until then: **exact pin `3.1.0+1`**.

### CI Gradle Namespace Patch
The `build-apk.yml` has an auto-patch step that fixes legacy pub packages using `flutter.compileSdkVersion` in their `build.gradle`. This runs after `flutter pub get` and before the Gradle build. Do not remove it — several packages (`saver_gallery`, `gal`, `image_gallery_saver`) need it.

### mergeDeltaTitle vs upsertTitle
- `upsertTitle` — ConflictAlgorithm.replace (overwrites ALL columns including share_url). Use only for Oracle sync (trusted source).
- `mergeDeltaTitle` — ON CONFLICT DO UPDATE SET (preserves share_url, poster_path). Use only for JazzDrive delta (untrusted, metadata-only).
- NEVER swap these — doing so would wipe share_urls on delta sync.

### Large file commits via GitHub API
For files >50KB (player_screen.dart is ~3400 lines), use `base64 -w0` for the blob content. For files >100KB, write the JSON payload to disk and use `--data-binary @/tmp/payload.json` with curl to avoid shell argument limits.

### Oracle SSH
Port 22 is unreachable from Replit containers. All server file changes must go through GitHub API. The Oracle server has a deployment mechanism (auto-pull or manual) — check with the user how server deploys happen.

### FTS5 Search — DB v13 (2026-05-30)
- `catalog_fts` virtual table: `USING fts5(title, description, content='titles', content_rowid='id')`
- Must call `INSERT INTO catalog_fts(catalog_fts) VALUES('rebuild')` after bulk inserts — wrapped in `LocalDb.rebuildFtsIndex()`, fired fire-and-forget in `catalog_provider._loadFromDb()`
- Query: `"word*"` prefix terms AND'd together. Falls back to LIKE if FTS throws (safe on fresh install)
- `_migrate` block: `if (oldV < 13)` — creates table + rebuilds on DB upgrade
- **CRITICAL**: `_migrate(Database db, int oldV, int newV)` — param is `oldV`, NOT `oldVersion`. Wrong name = compile error.

---

## Secrets in Replit
- `GITHUB_TOKEN` — GitHub PAT for raddclub org (all GitHub API calls)
- `SESSION_SECRET` — Flask session secret for Radd Hub
- `ORACLE_SSH_KEY` — SSH private key (not usable from Replit container)

---

## The 30-Second Summary for Any AI

RaddFlix is a Pakistani streaming app. Jazz SIM users watch movies/dramas for free because video lives on JazzDrive (zero-rated by Jazz). The app reads JazzDrive share folder URLs from local SQLite, generates stream links locally, no server involved at playback. The most critical secret is those share folder URLs — protected by SQLCipher + Android Keystore. The admin panel (Radd Hub) runs on Oracle, manages content, generates delta JSON (metadata only, no secrets) uploaded to JazzDrive daily for zero-rated catalog updates. CI is green. Phases 5–12 done. Next: OTP device switch (flip flag), player poster saving on stream, offline banner.
