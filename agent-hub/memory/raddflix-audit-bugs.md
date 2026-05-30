---
name: RaddFlix Full Audit Bugs
description: 34 bugs found in 2026-05-30 full codebase audit, tracked as BUG-A01..A34 in Phase 13
---

## Critical Bugs (breaks functionality)

| ID | File | Bug | Status |
|----|------|-----|--------|
| BUG-A01 | catalog_item.dart | year stored as TEXT → `as int?` returns null | ✅ FIXED commit 48680c66 |
| BUG-A02 | library.py | media_type "tv"/"series" not normalized → TV shows invisible | ✅ FIXED commit 48680c66 |
| BUG-A03 | mobile_api.py | is_active returned as Python bool not int (1/0) | ✅ FIXED commit 48680c66 |
| BUG-A04 | local_db.dart | ON CONFLICT DO UPDATE = SQLite 3.24+, crashes Android 8 | ✅ FIXED commit 2833a37: SELECT+UPDATE/INSERT in mergeDeltaTitle() |
| BUG-A05 | vault_lock_screen.dart | subtitle said "4–6 digit" but setup always required 6 | ✅ FIXED commit 48680c66 |
| BUG-A06 | app.py | session_err undefined in download_proxy() → NameError crash | ✅ FIXED commit 48680c66 |
| BUG-A07 | mobile_api.py | /api/app/check returns pk.jazzmax.app package ID | 🚫 FALSE POSITIVE — AppUpdateService reads package ID from PackageInfo.fromPlatform(), server doesn't return package_id at all |
| BUG-A08/A19 | lib/core/api/ | No HistoryApi class — /api/history endpoints unused | ✅ FIXED commit 2833a37: history_api.dart created + wired in player |
| BUG-A10 | mobile_api.py | POST /api/auth/device crashes 500 with guest token | ✅ FIXED commit 48680c66 |

## Data/Logic Bugs

| ID | Bug | Status |
|----|-----|--------|
| BUG-A09 | /api/notifications/read ignores ids, marks all read | ✅ FIXED commit 48680c66 |
| BUG-A11 | Server history = seconds, Flutter = ms → 1000x mismatch | ✅ FIXED commit 2833a37: HistoryApi.watchedAtToDateTime() multiplies by 1000 |
| BUG-A12 | payment_methods fallback had 03xxxxxxxxx placeholder numbers | ✅ FIXED commit 48680c66 |
| BUG-A14 | profile_screen._loadExtras() swallows all exceptions silently | ✅ FIXED commit 7474b47e: catch(e)+debugPrint in both catch blocks |
| BUG-A15 | _staticTrending in search_screen is hardcoded fake data | ✅ FIXED commit 7474b47e: replaced with real catalog items fallback |
| BUG-A16 | _extractGenres() JSON array format not parsed → bracket chars in genre chips | ✅ FIXED commit 7474b47e: detects JSON array vs CSV, strips brackets+quotes |
| BUG-A17 | jazzdrive.py: jazzdrive_login/list_folders etc are empty stubs | 🚫 FALSE POSITIVE — functions delegate to _scanner()._legacy module, not empty stubs |
| BUG-A18 | sync.py GSheets uses _legacy import that may not exist | 🚫 FALSE POSITIVE — sync.py never imports _legacy; the only mention is a docstring comment |
| BUG-A32 | FLASK_SECRET_KEY regenerated on restart → all JWTs invalidated | ✅ FIXED commit 2833a37: _secret() persists key to DB settings table |

## Unwired Features
- BUG-A20: PosterService.runBackgroundSync() — not confirmed started on splash
- BUG-A21: PlayerPrefs.reset() — no UI button
- BUG-A22: LocalDb.clearPosition() — never called from UI
- BUG-A23: SceneBookmarkStore.deleteAll() — never called
- BUG-A24: BingeGuardController — no confirmed interrupt point in player
- BUG-A25: SmartIntroStore — needs confirm triggered in player_screen
- BUG-A26: radd_recommend.py — no API endpoint exposes it to Flutter
- BUG-A27: AuthApi.bindDevice() — orphaned dead code (binding done in login())
- BUG-A28: Download quota not returned by server, not enforced
- BUG-A29: Mid-stream cutoff doesn't exist

## Infrastructure
- BUG-A30: Hardcoded IP 92.4.95.252 in constants.dart → ✅ FIXED commit [BATCH4]: jazzDriveDeltaUrl + jazzDriveDbUpdateUrl now static String getters derived from mutable apiBaseUrl
- BUG-A31: No SSL on Oracle server
- BUG-A33: Material Design 2 only — no MD3, no light theme
- BUG-A34: _watch_prototype/ is dead legacy code still in repo → ✅ FIXED commit [BATCH4]: all 17 files deleted from repo

**Why:** Full code-logic audit 2026-05-30, 363 files, 7 parallel subagents.
**How to apply:** Remaining: A20–A29, A31, A33. See table above for status of all bugs.

## IMPORTANT — BUG-A32 deploy note
After commit 2833a37 is deployed to Oracle, the server will generate a new JWT secret and
store it in the settings table. All existing mobile sessions will be invalidated ONCE.
Users need to log in once. This is expected and correct behaviour.


## Phase 13 false positives
A07, A17, A18 — verified not present in codebase as of 2026-05-30.
