# RaddFlix Task Log

## Session 2026-05-31 — Phase 18: Full System Verification

### Summary
Deep audit and full pipeline verification session. Fixed remaining server bugs, verified all API endpoints, ran live scanner integration test, seeded subscription plans DB, and confirmed the entire end-to-end stack is working.

### Bugs Fixed

#### BUG-C01 — `delta()` poster_jd_url always empty
- **File**: `radd-hub/hub/routes/catalog_api.py`
- **Root cause**: `delta()` was returning `"poster_jd_url": psu` (which is empty string when poster_share_url is NULL) instead of calling `_poster_jd_url(r["id"], psu)` like sync() does.
- **Fix**: Changed to `"poster_jd_url": _poster_jd_url(r["id"], psu)` — consistent with sync endpoint.
- **Commit**: Part of Phase 18 push.

#### BUG-C02 — Plans DB table empty (seeding)
- **File**: Oracle DB direct insert
- **Root cause**: `plans` table had 0 rows; API was serving hardcoded fallback values on each call.
- **Fix**: Inserted 3 real plans into DB: Basic (Rs.149, 30GB), Standard (Rs.249, 50GB), Premium (Rs.399, 100GB).
- **Status**: API now reads from DB, fallback still works if DB cleared.

#### BUG-C03 — Posters not on JazzDrive
- **Action**: Triggered `POST /api/catalog/poster-push/bulk` (admin Basic auth).
- **Result**: All 6 published titles now have `poster_share_url` populated with real JazzDrive URLs.
- **Verified**: `/api/catalog/poster-push/status` → `6/6 has_jd_poster`.

### Verifications Completed

**API Endpoints (20 tested, all passing):**
- /healthz, /api/ping, /api/catalog/version, /api/catalog/sync, /api/catalog/delta ✅
- /api/catalog/posters, /api/catalog/poster-push/status, /api/catalog/play, /api/catalog/share_url ✅
- /api/catalog/poster/<id> (302 redirect), /api/search, /api/auth/guest ✅
- /api/subscription/plans, /api/app/check, /api/payment-methods/ ✅
- /api/recommend (requires Bearer — correct), /api/usage (POST-only), /api/usage/quota ✅
- /api/history, /api/notifications ✅

**Scanner Integration:**
- `POST /scan/api/accounts/2/scan` → 200 OK, scan running
- Discovered 59 files across 15 titles from JazzDrive account 2
- New unpublished titles (is_ready=1): Interstellar, Dune: Part Two, Animal, The Ninth Gate, Inuyashiki, Super Mario Galaxy Movie, Inception, Oppenheimer, + duplicates
- TMDB lookups working live: matched Inception ✅, Oppenheimer ✅, The Super Mario Galaxy Movie ✅
- TMDB misses (filename issues): The Dark Knight, Avatar Fire And Ash, The Wonderfools, Mithde, Sarvam Maya

**Stream Pipeline:**
- `jazzdrive.generate_direct_link()` tested on Off Campus S01E01 + Salaar → both OK
- stream_links table has 18 valid cached links
- Uploader: account 2 active, 15 files done, 8.8GB total

**Organizer:**
- `organizer._get_magic_root_id(2)` → 1719700 (JazzDrive folder ID confirmed)

**Flutter Bug Fixes (confirmed from previous sessions):**
- BUG-A20: `PosterService.runBackgroundSync()` called from home_screen (CatalogStatus.ready) ✅
- BUG-A22–A29: All previously fixed ✅
- BUG-C01 delta endpoint: now synced to GitHub

### Phase 17 Tasks Status Update
| Task | Previous | Now |
|------|----------|-----|
| T006: Flix JazzDrive account | [ ] open | ✅ Account 2 (role='flix') already exists |
| T007: Re-scan | [ ] open | ✅ Triggered, 59 files discovered |
| T008: Orphan files | [ ] open | ✅ All 15 upload jobs are "done" — no orphans |
| T010: Vegamovies scorer | [ ] open | ✅ Already fixed (commit cd8707b) |
| T011: Subscription plans | [ ] open | ✅ 3 plans seeded into DB |
| T012: Off Campus S01 publish | [ ] open | ✅ is_published=1 already |

### Still Open
- T005: wa-bot WA delivery (needs WA session — blocked)
- T009: rogmovies.blog DNS dead (domain owner action needed)
- REVIEW: 9 new titles discovered by scanner — admin to review and publish via admin panel
- TMDB misses for 5 filenames — need manual title mapping or filename cleanup
