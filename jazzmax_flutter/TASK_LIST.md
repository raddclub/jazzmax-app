# ZENO — Complete Overhaul Task List
> App renamed from JazzMAX → ZENO | Brand: ZENO Red #E8002D → Orange #FF6B00 → White | Tagline: "Sab Dekho, Dil Khol Ke"

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
- [x] ✅ main.dart — PosterService + JazzDriveService boot calls wrapped in try/catch
- [x] ✅ APK crash fixes — startup services safe, assets/brand/ folder, package ID com.zeno.app
- [x] ✅ build-apk.yml — ZENO APK naming, GitHub Actions workflow fixed

---

## PHASE 1: BRAND IDENTITY — ZENO
- [x] ✅ App renamed: JazzMAX → ZENO
- [x] ✅ Primary color: #E8002D ZENO Red (NOT violet) + Orange #FF6B00 accent
- [x] ✅ Letter icons: Z=Play🔴 E=Eye🔵 N=Lightning⚡ O=People🟢
- [x] ✅ Tagline: "Sab Dekho, Dil Khol Ke"
- [x] ✅ constants.dart — full ZENO Red/Orange brand colors, pure dark backgrounds
- [x] ✅ splash_screen.dart — animated ZENO logo reveal with particle field
- [x] ✅ onboarding_screen.dart — ZENO branded, icon-based pages
- [x] ✅ app.dart — ZENO title, ForceUpdate screen updated, violet→red colors
- [x] ✅ pubspec.yaml — name: zeno
- [x] ✅ ZENO Brand Kit (10 assets) generated + BRAND_GUIDELINES.md

---

## PHASE 2: HOME SCREEN — Netflix Style ✅ COMPLETE
- [x] ✅ Hero banner with auto-rotating featured content (290dp height, 5s interval)
- [x] ✅ Hero: title, year, genres, description, Watch Now + More Info buttons
- [x] ✅ Hero: FREE badge on free content, rating badge top-right
- [x] ✅ Continue Watching row (from watch history)
- [x] ✅ Trending Now row with rank number badges (1-10)
- [x] ✅ Free to Watch dedicated row (all is_free titles)
- [x] ✅ Movies row + TV Shows & Dramas row
- [x] ✅ Category filter chips (Movies/Shows/Dramas/Urdu/Punjabi/English)
- [x] ✅ Category grid view for filtered content (3 columns)
- [x] ✅ Shimmer skeleton while loading (290dp hero + 6 card shimmer)
- [x] ✅ Sticky top bar with ZENO logo (red→orange gradient) + search icon + notifications
- [x] ✅ Pull-to-refresh syncs catalog from server
- [x] ✅ ZENO logo: red→orange→warm white ShaderMask gradient
- [x] ✅ Category chips: red/orange gradient when active
- [x] ✅ Content rows: 210dp tall, icon-labeled section headers
- [x] ✅ Empty state: icon + message + debug hint (tap logo 5× for debug panel)
- [x] ✅ Debug panel: 5-tap logo secret, log viewer, copy + share buttons

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
- [ ] Move JWT_SECRET + SMS_KEY from SQLite → env

---

## PHASE 8: SUBSCRIPTION FLOW
- [ ] Plans screen UI
- [ ] TID (Transaction ID) submission
- [ ] Status polling

---

## PHASE 9: APK BUILD & DISTRIBUTION 🔄 IN PROGRESS
- [x] ✅ build-apk.yml — GitHub Actions workflow, ZENO-X.X.X APK naming
- [x] ✅ emulator_test.yml — fixed package ID com.zeno.app
- [ ] Upload APK to JazzDrive for OTA distribution
- [ ] jazzmax_config.json pointing to production Oracle server
