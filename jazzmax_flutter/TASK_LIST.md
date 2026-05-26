# ZENO — Complete Overhaul Task List
> App renamed from JazzMAX → ZENO | Brand color: #7B2FFF Electric Violet | Tagline: "Sub Dekho, Dil Kholke"

## STATUS LEGEND: ⬜ TODO | 🔄 IN PROGRESS | ✅ DONE

---

## PHASE 0: CRITICAL FIXES
- [x] ✅ Fix _openMedia bug (player was passing JSON API URL to video player)
- [x] ✅ Fix catalog sync — TV episodes now parsed from server response
- [x] ✅ JazzDriveService.dart — on-device zero-rated link generation
- [x] ✅ PosterService.dart — smart poster caching (TMDB → JazzDrive fallback)
- [x] ✅ local_db.dart v10 — stream_cache table, share_url columns
- [x] ✅ sync_service.dart — JazzDrive fallback sync (zero-rated catalog)
- [x] ✅ app_catalog.py — share_url in /sync and /db_update responses
- [x] ✅ jazzdrive_db.py — fixed broken generate_db_update SQL
- [x] ✅ show_detail_screen.dart — download buttons on every episode + movie
- [x] ✅ main.dart — PosterService + JazzDriveService boot calls

---

## PHASE 1: BRAND IDENTITY — ZENO
- [x] ✅ App renamed: JazzMAX → ZENO
- [x] ✅ Primary color: #7B2FFF (Electric Violet) — own brand, not Jazz red
- [x] ✅ Letter icons: Z=Play🔴 E=Eye🔵 N=Lightning⚡ O=People🟢
- [x] ✅ Tagline: "Sub Dekho, Dil Kholke"
- [x] ✅ constants.dart — full ZENO brand colors + StorageKeys
- [x] ✅ splash_screen.dart — animated ZENO logo reveal with particle field
- [x] ✅ onboarding_screen.dart — ZENO branded, icon-based pages
- [x] ✅ app.dart — ZENO title, ForceUpdate screen updated
- [x] ✅ pubspec.yaml — name: zeno

---

## PHASE 2: HOME SCREEN — Netflix Style
- [ ] Hero banner with auto-rotating featured content
- [ ] Continue Watching row (from watch history)
- [ ] Trending Now row
- [ ] Category filter chips (Movies/Shows/Dramas/Anime/Urdu/Punjabi)
- [ ] Shimmer skeleton while loading
- [ ] Sticky top bar with ZENO logo + search icon
- [ ] Pull-to-refresh animation

---

## PHASE 3: VIDEO PLAYER — MX Player Standard
- [ ] Double-tap ±15s seek with ripple animation
- [ ] Swipe left = brightness | right = volume
- [ ] Long press = 2× speed
- [ ] Pinch to zoom
- [ ] PiP (Picture-in-Picture)
- [ ] Skip intro button (t=85s)
- [ ] Next episode countdown card
- [ ] Sleep timer circular picker
- [ ] Speed sheet (0.25×–4×)
- [ ] Audio track sheet
- [ ] Subtitle sheet
- [ ] Aspect ratio sheet
- [ ] Battery + time in controls

---

## PHASE 4: SEARCH SCREEN
- [ ] Full-screen animated search
- [ ] Recent search history (local)
- [ ] Live results with shimmer
- [ ] Filter chips: Genre / Year / Type

---

## PHASE 5: DOWNLOADS SCREEN
- [ ] Folder-based: Movies / Shows / Other
- [ ] Storage bar at top
- [ ] Progress ring animation
- [ ] Swipe to delete
- [ ] Multi-select bulk delete

---

## PHASE 6: PROFILE SCREEN
- [ ] Avatar with initials + gradient
- [ ] Subscription countdown
- [ ] Watch stats (hours, titles)
- [ ] Theme selector (Dark/AMOLED/Light)
- [ ] App version + about

---

## PHASE 7: SECURITY CLEANUP
- [ ] Close port 8000 (currently public, bypasses Nginx)
- [ ] Move JWT_SECRET + SMS_KEY from SQLite → env vars

---

## PHASE 8: ZERO-RATED CATALOG SYNC
- [ ] Upload db_update.json to JazzDrive
- [ ] Set jazzDriveDbUpdateUrl in constants.dart
- [ ] Test zero-rated sync on Jazz SIM with zero balance

---

## PHASE 9: GITHUB + APK BUILD
- [ ] Push all ZENO files to GitHub
- [ ] Trigger GitHub Actions APK build
- [ ] Test APK on device — verify: login ✓ catalog ✓ video plays ✓
- [ ] Update Android app label to "ZENO" in AndroidManifest.xml
