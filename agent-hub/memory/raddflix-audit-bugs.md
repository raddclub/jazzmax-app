---
name: RaddFlix Full Audit Bugs
description: 34 bugs found in 2026-05-30 full codebase audit, tracked as BUG-A01..A34 in Phase 13
---

## Critical Bugs (breaks functionality)

| ID | File | Bug | Status |
|----|------|-----|--------|
| BUG-A01 | catalog_item.dart | year stored as TEXT → `as int?` returns null | ✅ FIXED: `int.tryParse(json['year'].toString())` |
| BUG-A02 | library.py | media_type "tv"/"series" not normalized → TV shows invisible | ✅ FIXED: `_normalize_media_type()` helper added |
| BUG-A03 | mobile_api.py | is_active returned as Python bool not int (1/0) | ✅ FIXED: all `is_active` fields now return 1 or 0 |
| BUG-A04 | local_db.dart | ON CONFLICT DO UPDATE = SQLite 3.24+, crashes Android 8 | ⬜ TODO: use INSERT OR REPLACE |
| BUG-A05 | vault_lock_screen.dart | subtitle said "4–6 digit" but setup always required 6 | ✅ FIXED: subtitle → "Choose a 6-digit PIN" |
| BUG-A06 | app.py | session_err undefined in download_proxy() → NameError crash | ✅ FIXED: initialized None; captured from jazzdrive error |
| BUG-A07 | mobile_api.py | /api/app/check returns pk.jazzmax.app package ID | ⬜ TODO (may be stale — verify) |
| BUG-A10 | mobile_api.py | POST /api/auth/device crashes 500 with guest token | ✅ FIXED: returns 403 for guest |
| BUG-A19 | lib/core/api/ | No HistoryApi class — /api/history endpoints unused | ⬜ TODO: create history_api.dart |

## Data/Logic Bugs

| ID | Bug | Status |
|----|-----|--------|
| BUG-A09 | /api/notifications/read ignores ids, marks all read | ✅ FIXED: selective by IDs when provided |
| BUG-A11 | Server history = seconds, Flutter = ms → 1000x mismatch | ⬜ TODO |
| BUG-A12 | payment_methods fallback had 03xxxxxxxxx placeholder numbers | ✅ FIXED: empty string + support message |
| BUG-A14 | profile_screen._loadExtras() swallows all exceptions silently | ⬜ TODO |
| BUG-A15 | _staticTrending in search_screen is hardcoded fake data | ⬜ TODO |
| BUG-A16 | _extractGenres() doesn't trim → duplicate genre chips | ⬜ TODO |
| BUG-A17 | jazzdrive.py: jazzdrive_login/list_folders etc are empty stubs | ⬜ TODO |
| BUG-A18 | sync.py GSheets uses _legacy import that may not exist | ⬜ TODO |

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
- BUG-A30: Hardcoded IP 92.4.95.252 in remote_config.dart
- BUG-A31: No SSL on Oracle server
- BUG-A32: FLASK_SECRET_KEY regenerated on restart → all JWTs invalidated
- BUG-A33: Material Design 2 only — no MD3, no light theme
- BUG-A34: _watch_prototype/ is dead legacy code still in repo

**Why:** Full code-logic audit 2026-05-30, 363 files, 7 parallel subagents.
**How to apply:** Next priority is BUG-A04 (Android 8 crash) and BUG-A32 (JWT invalidation on restart).
