# RaddFlix — CODE MAP (Full File Reference)
> Generated: 2026-05-30 — Full codebase audit
> **Use this file before touching any source file.** Each entry tells you what a file does,
> its key functions, and any known bugs/stubs/unwired code. No need to re-read source.

---

## HOW TO USE THIS FILE

1. Find the file you're about to touch in the index below
2. Read its entry: purpose, functions, known issues
3. Check the BUG-AXX IDs against REINCARNATION.md for fix details
4. Only then open the source file

---

## FLUTTER APP — `raddflix_flutter/lib/`

---

### `lib/main.dart`
**Purpose:** App entry point. Wraps everything in `ProviderScope` (Riverpod).
**Key Functions:** `main()` — calls `runApp(ProviderScope(child: RaddFlixApp()))`
**Known Issues:** None critical.

---

### `lib/app.dart`
**Purpose:** MaterialApp, route table, `_ForceUpdateGuard`.
**Key Functions:**
- Route table: 18 named routes + `onGenerateRoute` for player/showDetail/vaultLock
- `_ForceUpdateGuard` — wraps entire app; if `AppUpdateService.lastResult.blocked` or `.forceUpdate` = true, shows `_ForceUpdateScreen`
**Known Issues:**
- `'/player-settings'` hardcoded string instead of `AppRoutes.playerSettings` constant — still works but inconsistent
- Material Design 2 only — `useMaterial3: true` not set (BUG-A33)
- No light theme variant

---

### `lib/core/constants.dart`
**Purpose:** ALL app-wide constants: API paths, routes, feature flags, app settings.
**Key Constants:**
- `AppRoutes.*` — all named routes
- `ApiPaths.*` — all API endpoint paths
- `AppConstants.otpDeviceSwitchEnabled = false` — OTP device switch is DISABLED
- `AppConstants.supportWhatsApp = '923001234567'` — support number
- `AppConstants.simosaPlayStoreUrl` — SIMOSA deep link
- `catalogDbVersion = 13` — current SQLite DB schema version
- `ApiPaths.deviceSwitchOtpRequest` / `deviceSwitchOtpVerify` — defined but server endpoints DO NOT EXIST
**Known Issues:**
- OTP paths defined for non-existent server endpoints (BUG-A07 related)
- `otpDeviceSwitchEnabled = false` — OTP UI hidden (intentional for now)

---

### `lib/core/api/api_client.dart`
**Purpose:** Singleton Dio HTTP client. Auto-attaches JWT Bearer token from Keystore. Handles 401 refresh.
**Key Functions:**
- `ApiClient.instance` — singleton getter
- `_authInterceptor` — reads token from Keystore, attaches header
- `_refreshIfNeeded()` — calls `/api/auth/refresh` on 401
**Known Issues:** None found in audit.

---

### `lib/core/api/auth_api.dart`
**Purpose:** Auth operations — login, register, guest, device binding, OTP stubs.
**Key Functions:**
- `login({phone, password, deviceId})` — POST /api/auth/login; handles 409 device_conflict
- `register({phone, password})` — POST /api/auth/register
- `loginAsGuest()` — POST /api/auth/guest
- `bindDevice({deviceId, deviceName})` — **DEAD CODE** — binding already done inside `login()`. Never called (BUG-A27)
- `requestDeviceSwitchOtp({phone})` — **STUB** throws `UnimplementedError`. TODO(OTP) comment
- `verifyDeviceSwitchOtp({phone, otpCode})` — **STUB** throws `UnimplementedError`. TODO(OTP) comment
**Known Issues:**
- `bindDevice()` is orphaned dead code (BUG-A27)
- OTP stubs throw UnimplementedError — activate after server endpoints built

---

### `lib/core/api/catalog_api.dart`
**Purpose:** Catalog sync — fetch version, delta sync, share URLs.
**Key Functions:**
- `fetchVersion()` — GET /api/catalog/version → returns `{version, count}`
- `syncDelta({since})` — GET /api/catalog/sync?since= → returns titles + episodes JSON
- `fileShareUrl(fileId)` — GET /api/catalog/share_url?file_id=
**Known Issues:** None found. Matches server implementation.

---

### `lib/core/api/subscription_api.dart`
**Purpose:** Subscription management API calls.
**Key Functions:**
- `getPlans()` — GET /api/subscription/plans
- `getStatus()` — GET /api/subscription/status
- `submitTid({tid, plan, paymentMethod, phone})` — POST /api/subscription/tid/submit
- `getTidStatus()` — GET /api/subscription/tid/status
**Known Issues:**
- No `HistoryApi` class in this directory — watch history never synced (BUG-A19)
- Payment method verification partially stubbed

---

### `lib/core/db/local_db.dart`
**Purpose:** All SQLite operations. Schema creation, migrations, queries for every feature.
**Key Functions:**
- `_createAll(db)` — creates all tables fresh (v13 schema)
- `_migrate(db, oldV, newV)` — handles upgrades; **MUST use `oldV` not `oldVersion`**
- `mergeDeltaTitle(item)` — upserts catalog from delta sync
- `searchTitles(query)` — FTS5 MATCH with LIKE fallback
- `rebuildFtsIndex()` — rebuilds `catalog_fts` virtual table
- `addPendingUsage(bytes)` / `getPendingUsageBytes()` / `clearPendingUsage()` — usage queue
- `cacheQuota(json)` / `getCachedQuota()` — quota cache
- `getSimosaStreak()` / `recordSimosaClaim()` — SIMOSA streak
- `getNewEpisodeCounts(showIds)` — batch query for new-episode badges
- `markEpisodesSeen(showId, count)` — clears badge on show open
- `clearPosition(fileId)` — **NEVER CALLED** from any UI (BUG-A22)
- `addWatchPosition` / `getWatchPositions` — local progress tracking
**Known Issues:**
- `mergeDeltaTitle` uses `ON CONFLICT(id) DO UPDATE SET` — SQLite 3.24+ only. Crashes Android 8 (BUG-A04)
- `clearPosition(fileId)` defined but never called from UI (BUG-A22)
- **`_migrate` parameter MUST be `oldV`** — never rename (broke CI twice)

---

### `lib/core/db/sync_service.dart`
**Purpose:** Orchestrates catalog sync — fetches delta from JazzDrive/server, merges into SQLite.
**Key Functions:**
- `sync()` — main sync entry point; calls CatalogApi.syncDelta + LocalDb.mergeDeltaTitle
- `_syncFromJazzDriveDelta()` — zero-rated sync path
**Known Issues:** None critical found.

---

### `lib/core/player/ab_loop_controller.dart`
**Purpose:** A-B point looping logic for the video player.
**Key Functions:** `setA()`, `setB()`, `clearLoop()`, `checkLoop(position)`
**Known Issues:** Needs confirmation it's actively triggered in `player_screen.dart` (all player controller files need UI entry point verification).

---

### `lib/core/player/ambilight_controller.dart`
**Purpose:** Samples frame edges of video to compute ambient color for the glow border.
**Key Functions:** `sampleFrame(imageBytes)`, `computeEdgeColor()`
**Known Issues:** CPU-intensive sampling — needs throttle verification in player_screen.

---

### `lib/core/player/binge_guard_controller.dart`
**Purpose:** Tracks cumulative watch time, triggers binge warning after threshold.
**Key Functions:** `tick(seconds)`, `shouldWarn` getter, `reset()`
**Known Issues:** No confirmed interrupt point in player_screen.dart (BUG-A24)

---

### `lib/core/player/player_prefs.dart`
**Purpose:** Persistent player preference models (quality, subtitle size, ambilight toggle, etc.).
**Key Functions:**
- `PlayerPrefs.fromJson()` / `toJson()` — serialization
- `PlayerPrefs.reset()` — **NEVER CALLED** — no UI button to reset player settings (BUG-A21)
**Known Issues:** `reset()` is dead code — no "Reset Player Settings" button in any screen.

---

### `lib/core/player/player_prefs_provider.dart`
**Purpose:** Riverpod StateNotifier for PlayerPrefs.
**Key Functions:** `PlayerPrefsNotifier` — load/save/update prefs
**Known Issues:** None.

---

### `lib/core/player/scene_bookmark_store.dart`
**Purpose:** SQLite persistence for user-added scene bookmarks (timestamps with labels).
**Key Functions:**
- `add(fileId, positionMs, label)` — save bookmark
- `getAll(fileId)` — fetch for current media
- `delete(id)` — remove one
- `deleteAll(fileId)` — **NEVER CALLED** — clears all bookmarks for a file. No UI button (BUG-A23)
**Known Issues:** `deleteAll()` is dead code.

---

### `lib/core/player/smart_intro_store.dart`
**Purpose:** Persists "Skip Intro" timestamp per episode for smart auto-skip.
**Key Functions:** `save(fileId, introStart, introEnd)`, `get(fileId)`
**Known Issues:** Needs confirmation it's triggered in `player_screen.dart`.

---

### `lib/core/remote_config.dart`
**Purpose:** Fetches base server URL at app startup from hardcoded IP.
**Key Functions:** `RemoteConfig.fetch()` — hits `http://92.4.95.252/api/config`
**Known Issues:** Hardcoded IP — if Oracle IP changes, all installed apps break permanently (BUG-A30)

---

### `lib/core/security/device_id.dart`
**Purpose:** Generates stable unique device fingerprint.
**Key Functions:** `DeviceIdentifier.getDeviceId()` — uses platform-specific IDs
**Known Issues:** None.

---

### `lib/core/security/keystore.dart`
**Purpose:** Encrypted storage via `flutter_secure_storage` for JWT tokens and SQLCipher DB key.
**Key Functions:**
- `getOrCreateDbKey()` — generates/retrieves AES key for SQLCipher (Android Keystore bound)
- `saveToken(token)` / `getToken()` — JWT storage
**Known Issues:** None.

---

### `lib/core/services/app_update_service.dart`
**Purpose:** Checks server for forced updates via `/api/app/check`.
**Key Functions:** `AppUpdateService.check()`, `lastResult` static getter
**Known Issues:** Server returns wrong package ID `pk.jazzmax.app` (BUG-A07) — check never matches.

---

### `lib/core/services/jazzdrive_service.dart`
**Purpose:** Resolves JazzDrive share URLs to direct CDN streaming links. Zero-rated path.
**Key Functions:**
- `getStreamLink(shareUrl)` — resolves CDN link, caches in `stream_cache` (6h TTL)
- `resolveFileId(fileId)` — gets share_url from SQLite then resolves
**Known Issues:** None in this file specifically.

---

### `lib/core/services/notification_service.dart`
**Purpose:** Polls server for notifications, shows in-app banner/sheet.
**Key Functions:**
- `fetchNotifications()` — GET /api/notifications/
- `markRead(ids)` — POST /api/notifications/read (server ignores IDs — marks all read, BUG-A09)
- `startPolling()` — polls every 5 minutes
**Known Issues:**
- Server ignores the `ids` array in markRead (BUG-A09)
- Notification images never fetched — server has `GET /api/notifications/image/<id>` unused

---

### `lib/core/services/poster_service.dart`
**Purpose:** Manages on-device poster image caching. Background sync of 100 posters/day.
**Key Functions:**
- `downloadAndCache(url, titleId)` — saves poster locally, calls `LocalDb.savePosterPath()`
- `runBackgroundSync()` — background batch download
- `saveFromJazzDrive(shareUrl, titleId)` — zero-rated poster saving
**Known Issues:**
- `runBackgroundSync()` existence needs confirmation it's called from main.dart or splash_screen (BUG-A20)
- `_isOnlineSource` heuristic may fail for non-TMDB/OMDB URLs

---

### `lib/core/services/usage_service.dart`
**Purpose:** Tracks data consumption, logs to SQLite, syncs to server.
**Key Functions:**
- `addWatchSession(seconds, quality)` — estimates bytes, flushes to server
- `flushPending()` — sends queued bytes to POST /api/usage
- `fetchQuota()` — GET /api/usage/quota, updates cache
**Known Issues:** Server enforces quota at stream start only — no mid-stream cutoff (BUG-A29)

---

### `lib/core/theme/app_theme.dart`
**Purpose:** ThemeData definitions for the app.
**Key Functions:** `AppTheme.dark` — returns dark ThemeData
**Known Issues:** Only dark theme exists. No `AppTheme.light`. Light mode toggle in profile exists but has nothing to switch to (BUG-A33).

---

### `lib/core/theme/radd_colors.dart`
**Purpose:** Brand color constants.
**Key Constants:** Primary red, surface blacks, accent colors, gradient definitions
**Known Issues:** All hardcoded — no `ColorScheme.fromSeed` or Material 3 dynamic color.

---

### `lib/core/theme/theme_provider.dart`
**Purpose:** Riverpod provider for theme mode.
**Key Functions:** `ThemeNotifier` — toggle dark/light
**Known Issues:** `AppTheme.light` doesn't exist — switching to light crashes.

---

### `lib/models/catalog_item.dart`
**Purpose:** Data model for movies/shows from SQLite/API.
**Key Fields:** `id`, `title`, `year` (int?), `mediaType`, `isFree`, `posterUrl`, `posterPath`, `fileId`, `episodes`, `newEpisodeCount`
**Key Functions:**
- `CatalogItem.fromJson(json)` — maps API/DB JSON to model
- `copyWith(...)` — immutable update
- `copyWithEpisodes(eps)` — add episode list to show item
**Known Issues:**
- Server returns `year` as TEXT string → `int?` cast returns null (BUG-A01). `fromJson` needs `int.tryParse(json['year']?.toString())`.
- Server returns `media_type` as `"tv"/"series"` not `"show"` (BUG-A02)

---

### `lib/models/user.dart`
**Purpose:** User profile and subscription status models.
**Key Fields:** `AppUser.isActive` (bool), `UserSubscription.isActive`
**Known Issues:**
- Server returns `is_active` as Python bool (true/false JSON). Model may expect 1/0 int. Check `fromJson` logic (BUG-A03).

---

### `lib/models/subscription.dart`
**Purpose:** Subscription plan details model.
**Known Issues:** None critical.

---

### `lib/models/local_video.dart`
**Purpose:** Model for locally scanned video files (Local Media feature).
**Known Issues:** None.

---

### `lib/providers/auth_provider.dart`
**Purpose:** Riverpod StateNotifier for auth state (login, logout, register, guest).
**Key Functions:** `login()`, `register()`, `loginAsGuest()`, `logout()`, `refreshUser()`
**Known Issues:**
- `state.isDeviceConflict` getter — set when 409 received from login. Works correctly.

---

### `lib/providers/catalog_provider.dart`
**Purpose:** Riverpod provider for the full content catalog. Manages sync, search, filtering, Continue Watching.
**Key Functions:**
- `_loadFromDb()` — loads catalog from SQLite, triggers FTS rebuild
- `_loadRecentlyWatched()` — handles both movies (fileId) and shows (iterates episodes)
- `syncCatalog()` — triggers delta sync
- `search(query)` — calls `LocalDb.searchTitles()`
**Known Issues:**
- `_staticTrending` is in `search_screen.dart` — hardcoded list, not from catalog provider (BUG-A15)

---

### `lib/providers/downloads_provider.dart`
**Purpose:** Manages download queue and completed downloads.
**Key Functions:** `startDownload()`, `deleteDownload()`, `getDownloads()`
**Known Issues:** `_bulkDelete()` in `downloads_screen.dart` calls `deleteDownload()` one at a time — slow for many files.

---

### `lib/providers/subscription_provider.dart`
**Purpose:** Riverpod provider for subscription state.
**Key Functions:** `loadSubscription()`, `refreshStatus()`
**Known Issues:** None critical.

---

### `lib/screens/splash_screen.dart`
**Purpose:** App startup screen. Fetches remote config, checks app update, navigates to onboarding/login/home.
**Key Flow:**
1. `RemoteConfig.fetch()` → gets server URL
2. `unawaited(AppUpdateService.check())` — non-blocking update check
3. Check `SharedPreferences` for onboarding seen
4. Check `authProvider` for existing session
5. Navigate accordingly
**Known Issues:** `PosterService.runBackgroundSync()` — need to confirm it's called here or in home_screen (BUG-A20).

---

### `lib/screens/onboarding_screen.dart`
**Purpose:** First-run onboarding flow with PageView.
**Data:** Hardcoded `_pages` static list. Sets `onboardingSeenKey` in SharedPreferences.
**Known Issues:** None.

---

### `lib/screens/login_screen.dart`
**Purpose:** Login form + device conflict panel.
**Key Features:**
- `_DeviceConflictPanel` (StatefulWidget) — shows when login returns 409
- WhatsApp support button (always visible in conflict panel)
- OTP section (hidden behind `AppConstants.otpDeviceSwitchEnabled = false`)
**Known Issues:**
- `backgroundColor: null` on Scaffold — may show white flash on some devices
- OTP methods `_requestOtp`/`_verifyOtp` exist but call stub `AuthApi` methods that throw (intentional until server built)

---

### `lib/screens/register_screen.dart`
**Purpose:** New account registration.
**Known Issues:**
- `backgroundColor: null` on Scaffold (same as login)
- Phone validation only checks length < 11 — no Pakistani prefix validation (BUG-A13)

---

### `lib/screens/home_screen.dart`
**Purpose:** Main home feed — hero spotlight, categories, content grid, Continue Watching.
**Key Features:**
- `SimosaCard` after category chips
- `NotificationBell` in AppBar
- `_HeroSpotlight` for featured content
- Continue Watching row (works for both movies and TV shows)
**Known Issues:**
- "Dramas" category logic matches any title containing "drama" in any field — may over-categorize
- `_staticTrending` in SearchScreen is hardcoded (BUG-A15) — not related to home but noted here

---

### `lib/screens/search_screen.dart`
**Purpose:** Full-text search with FTS5, filters (type/genre/year), search history.
**Key Features:**
- FTS5 search via `catalogProvider.search()`
- `_extractGenres()` builds genre filter chips
- `_staticTrending` — hardcoded list (BUG-A15)
- `_HistoryPill` — search history from SharedPreferences
**Known Issues:**
- `_extractGenres` doesn't trim whitespace in map key — duplicate genre chips (BUG-A16)
- `_staticTrending` is static fake data (BUG-A15)

---

### `lib/screens/show_detail_screen.dart`
**Purpose:** Show detail page with season tabs, episode list, Resume button.
**Key Features:**
- `_resumeEpisodeIndex` — finds most-recently-watched episode (3%–95% progress)
- Resume button shows "Resume S01E03 · 42%", navigates directly
- Multi-season tab switching
- `markEpisodesSeen()` called in `_loadEpisodes()` — clears new-episode badge
**Known Issues:** None critical found.

---

### `lib/screens/player_screen.dart`
**Purpose:** Full video player (media_kit/MPV). The largest file in the app.
**Key Features:** Streaming + offline, all 12 overlay widgets, gesture controls, JazzDrive resolution, quota check, watch position save, usage logging.
**Key Functions:**
- `_checkQuota()` — blocks offline playback when quota exceeded or plan expired; navigates to QuotaFullScreen or PlanExpiredScreen
- `_logWatchSession()` — calls `UsageService.addWatchSession()` on playback end
- `_savePosition()` — saves watch progress to SQLite
**Known Issues:**
- `_isLocalPath` — called as helper; verify it's defined in scope
- `FIX-SLEEP: -1 = pause at end` comment — legacy TODO may indicate incomplete sleep timer
- Frame-step buttons exist but may have no visible UI trigger in current layout
- All 12 `widgets/player/*.dart` imports need individual verification they're actually rendered (not just imported)

---

### `lib/screens/player_settings_screen.dart`
**Purpose:** Tabbed settings screen for player preferences.
**Data:** `playerPrefsProvider` (Riverpod)
**Known Issues:** No "Reset to Defaults" button wired to `PlayerPrefs.reset()` (BUG-A21)

---

### `lib/screens/profile_screen.dart`
**Purpose:** User profile, subscription status, settings, vault access, theme toggle.
**Key Features:**
- Subscription expiry countdown (⚠ yellow when ≤7 days)
- Dynamic version from `PackageInfo`
- Theme picker bottom sheet
- Admin queue access (admin users only)
**Known Issues:**
- `_loadExtras()` catches ALL exceptions silently (BUG-A14) — API failures invisible to user
- Light theme toggle exists but `AppTheme.light` doesn't exist (BUG-A33)

---

### `lib/screens/subscription_screen.dart`
**Purpose:** Subscription plan cards, Jazz partnership badge, TID payment flow.
**Key Features:**
- `_PlanCard` — per-plan card with savings vs Jazz data cost
- `_JazzPartnerBadge` — green gradient Jazz badge
- `_PayMethodCard` — JazzCash / EasyPaisa cards
- Fallback hardcoded methods if API returns empty
**Known Issues:**
- Fallback payment methods have placeholder `03xxxxxxxxx` numbers (BUG-A12)
- Navigation to TidStatusScreen exists

---

### `lib/screens/tid_status_screen.dart`
**Purpose:** Polls TID payment verification status every 20s.
**Key Features:** Timeline step UI, polling `GET /api/subscription/tid/check_by_phone`
**Known Issues:** None found.

---

### `lib/screens/downloads_screen.dart`
**Purpose:** Shows active downloads and completed offline content.
**Known Issues:** `_bulkDelete()` deletes one at a time — slow for many files.

---

### `lib/screens/vault_screen.dart`
**Purpose:** Encrypted private media vault.
**Known Issues:**
- `pushReplacementNamed(AppRoutes.vaultLock)` on app resume may corrupt nav stack if fired multiple times
- No "Create Vault" button visible — setup mode only triggers when vault has no PIN

---

### `lib/screens/vault_lock_screen.dart`
**Purpose:** PIN + biometric lock for vault access.
**Known Issues:**
- `_expectedPinLength` hardcoded to 6 but `_submit` allows 4 during setup (BUG-A05) — user creates 4-digit PIN, 6-digit lock never accepts it

---

### `lib/screens/vault_settings_screen.dart`
**Purpose:** Vault PIN change, biometric toggle.
**Known Issues:** None critical.

---

### `lib/screens/quota_full_screen.dart`
**Purpose:** Shown when daily data quota is exceeded.
**Features:** "Upgrade Plan" → subscription screen, "Get 100MB via SIMOSA" → deep link, "Go Back"
**Known Issues:** None.

---

### `lib/screens/plan_expired_screen.dart`
**Purpose:** Shown when offline plan has expired (blocks downloaded content).
**Features:** Lock icon, "Renew Plan" → subscription, "Go Back"
**Known Issues:** None.

---

### `lib/screens/local_media_screen.dart`
**Purpose:** Browse local video files on device storage.
**Data:** `local_media_service.dart`
**Known Issues:** None critical.

---

### `lib/screens/local_folder_screen.dart`
**Purpose:** Drill-down folder view for local media.
**Known Issues:** None critical.

---

### `lib/screens/admin_queue_screen.dart`
**Purpose:** Shows server-side task queue for admin users.
**Known Issues:** Only accessible to admin-flagged users.

---

### `lib/widgets/bottom_nav.dart`
**Purpose:** Bottom navigation bar (Home, Local Media, Downloads, Profile tabs).
**Known Issues:** None.

---

### `lib/widgets/content_card.dart`
**Purpose:** Reusable content card for movies/shows. Shows poster, title, badges.
**Key Features:**
- FREE / NEW / ONGOING / COMPLETED badges (top-left)
- Star rating (top-right)
- Language badge (bottom-left)
- `_NewEpBadge` "+N EP" pill (bottom-right, DB v12)
- Long-press quick view
**Known Issues:** Year never shown because server sends TEXT not INTEGER (BUG-A01).

---

### `lib/widgets/loading_overlay.dart`
**Purpose:** Overlay with spinner for blocking loading states.
**Known Issues:** None.

---

### `lib/widgets/notification_banner.dart`
**Purpose:** In-app notification bell icon + bottom sheet for notification list.
**Key Functions:** `NotificationBell` widget, `_NotificationSheet` modal
**Known Issues:** Mark-read sends IDs but server ignores them (BUG-A09).

---

### `lib/widgets/radd_text_field.dart`
**Purpose:** Styled text field used across login/register/forms.
**Known Issues:** None.

---

### `lib/widgets/simosa_card.dart`
**Purpose:** Daily SIMOSA reminder card with streak badge.
**Features:** Pulse animation CTA, 🔥 at 7-day streak, dismissible per-session
**Known Issues:** None.

---

### `lib/widgets/player/*.dart` (12 overlay widgets)
**Files:** `ab_loop_panel.dart`, `ambilight_glow_border.dart`, `cinematic_overlay.dart`, `eq_panel.dart`, `playback_info_overlay.dart`, `quick_settings_panel.dart`, `scene_bookmarks_panel.dart`, `subtitle_overlay.dart`, `sync_panel.dart`, `track_badges.dart`, `transparent_player_layer.dart`, `video_enhance_panel.dart`
**Purpose:** Each is a specialized player UI overlay — all imported in `player_screen.dart`.
**Known Issues:** All exist in GitHub. Need individual verification they are actually rendered (not just imported). Audit found imports present but could not verify rendering in all paths.

---

### `lib/services/cast_service.dart`
**Purpose:** Google Cast / Chromecast integration.
**Known Issues:** Used in `player_screen.dart` — no entry point verification done.

---

### `lib/services/local_media_service.dart`
**Purpose:** Scans device storage for video files.
**Known Issues:** Requires `READ_EXTERNAL_STORAGE` / `MANAGE_EXTERNAL_STORAGE` permissions.

---

### `lib/services/thumb_service.dart`
**Purpose:** Generates thumbnails for downloaded/local videos.
**Known Issues:** None.

---

### `lib/services/vault_service.dart`
**Purpose:** Encrypted file storage management for the vault feature.
**Key Functions:** PIN verify, biometric verify, encrypt/decrypt file operations
**Known Issues:** None critical.

---

## BACKEND — `radd-hub/hub/`

---

### `hub/app.py`
**Purpose:** Flask app factory. Registers all blueprints. Starts background threads.
**Key Functions:**
- `create_app()` — main factory
- `download_proxy()` — proxies download progress
- `_startup_refresh()` — fires on startup
**Background Threads Started:** scheduler, mirror-retry, upload-watcher, download-queue, keepalive, self-heal, domain-doctor, quality-upgrade, bulk-link-engine
**Known Issues:**
- **BUG-A06:** `session_err` used in `download_proxy()` but never defined — runtime NameError crash

---

### `hub/db.py`
**Purpose:** Central SQLite interface. Schema DDL (25+ tables), all server-side queries.
**Tables Defined:** titles, files, accounts, keys, mirror_log, queue, scan_log, users, settings, recommendation_cache, quality_upgrade_subscriptions, bot_status_index, rate_limit_log, stream_links, plans, user_subscriptions, user_usage, app_users, app_subscriptions, tid_payments, app_refresh_tokens, turbo_cache, media_index, watch_history, notifications, payment_methods
**Key Functions:** `conn()`, `init_db()`, `upsert_title()`, `upsert_file()`, `setting()`, `set_setting()`, `log_usage()`, `check_quota()`
**Known Issues:**
- `titles.year` stored as TEXT — Flutter's int? cast returns null (BUG-A01) — needs `year INTEGER`
- `watch_history` and `notifications` tables created in DDL but no push delivery mechanism
- `migrate_from_v2()` requires `radd_flix.db` + `radd_media.db` to exist in DATA_DIR

---

### `hub/auth.py`
**Purpose:** Admin login, CSRF protection, bot-key validation.
**Key Functions:** `login_required`, `csrf_protect`, `validate_csrf`
**Config Keys Read:** `RADD_ADMIN_USER`, `RADD_ADMIN_PASS`, `BOT_API_KEY`, `JAZZBUZZ_KEY`
**Known Issues:** None critical.

---

### `hub/config.py`
**Purpose:** Environment variable loading, directory setup, first-run bootstrap.
**Key Functions:** `ensure_dirs()`, `load_env()`, `first_run_bootstrap()`
**Known Issues:**
- `FLASK_SECRET_KEY` auto-generated on first run — server restart invalidates all JWTs (BUG-A32)

---

### `hub/routes/mobile_api.py`
**Purpose:** ALL mobile API endpoints. Auth, subscriptions, usage, notifications, history, app check.
**Blueprints:** bp_auth (/api/auth), bp_sub (/api/subscription), bp_usage (/api/usage), bp_pay (/api/payment-methods), bp_notif (/api/notifications), bp_hist (/api/history), bp_app (/api/app)
**All Endpoints:**
- `POST /api/auth/register` — new user
- `POST /api/auth/login` — login with device binding; 409 on device conflict
- `POST /api/auth/guest` — guest JWT
- `POST /api/auth/refresh` — token refresh
- `POST /api/auth/logout` — revoke refresh token
- `GET /api/auth/me` — user profile + subscription
- `POST /api/auth/device` — bind device (CRASHES with guest token — BUG-A10)
- `GET /api/subscription/plans` — list plans
- `GET /api/subscription/status` — user's current subscription
- `POST /api/subscription/tid/submit` — TID payment
- `GET /api/subscription/tid/status` — check TID status
- `POST /api/usage` — log bytes used
- `GET /api/usage/quota` — get quota + today/month breakdown
- `GET /api/payment-methods` — payment gateways from DB (falls back to hardcoded if empty)
- `GET /api/notifications/` — fetch notification list
- `POST /api/notifications/read` — mark read (IGNORES ids array — marks ALL read, BUG-A09)
- `GET /api/notifications/image/<id>` — notification image redirect (NEVER CALLED by Flutter)
- `GET /api/history` — fetch watch history list (NEVER CALLED by Flutter — BUG-A19)
- `POST /api/history/<file_id>` — save watch position (NEVER CALLED by Flutter — BUG-A19)
- `POST /api/app/check` — version check (RETURNS WRONG PACKAGE ID — BUG-A07)
**Known Issues:**
- BUG-A07: `/api/app/check` returns `pk.jazzmax.app` not `com.raddflix.app`
- BUG-A09: `/api/notifications/read` ignores IDs
- BUG-A10: `POST /api/auth/device` crashes with guest token
- BUG-A03: `is_active` returned as Python bool not int
- BUG-A19: History endpoints implemented but Flutter never calls them
- OTP device switch endpoints (`/api/auth/device-switch/request` and `/verify`) DO NOT EXIST

---

### `hub/routes/library.py`
**Purpose:** Catalog endpoints — search, filter, delta JSON generation.
**Key Endpoints:**
- `GET /api/catalog/version` — current delta version
- `GET /api/catalog/sync` — full/delta sync payload
- `POST /api/library/generate` — regenerate delta JSON
**Known Issues:**
- **BUG-A02:** `media_type` returns `"tv"` or `"series"` instead of `"show"` — TV shows invisible in Flutter

---

### `hub/routes/api.py`
**Purpose:** JazzDrive OTP, metadata autofix, download queue status, system health.
**Key Endpoints:** `/api/jazzdrive/otp`, `/api/meta/autofix`, `/api/queue/status`, `/api/status`
**Known Issues:** Large file with many responsibilities — works but needs cleanup.


**Changes 2026-05-30:** Scraper search renamed `/search` → `/scraper/search` (unblocks Flutter). Old JSON-file catalog routes removed (replaced by catalog_api.py).
---

### `hub/routes/catalog_api.py` ← NEW 2026-05-30
**Purpose:** Flutter app catalog sync API. Migrated from `_watch_prototype`. Live SQLite data.
**Blueprint:** `bp` at url_prefix `/api/catalog`
**Key Endpoints:**
- `GET /api/catalog/version` — `{version, count}` — Flutter checks before sync
- `GET /api/catalog/db_update/version` — lightweight version check
- `GET /api/catalog/sync?since=<ts>` — full or delta sync; returns titles + episodes
- `GET /api/catalog/posters` — list of all poster URLs for pre-caching
- `GET /api/catalog/db_update` — full catalog as downloadable db_update.json
**Known Issues:** None. Replaces old JSON-file catalog routes that were in api.py.

---

### `hub/routes/search_api.py` ← NEW 2026-05-30
**Purpose:** Flutter app title search. Migrated from `_watch_prototype`. No auth required.
**Blueprint:** `bp` at url_prefix `/api/search`
**Key Endpoints:**
- `GET /api/search?q=<term>&type=all|movie|tv&limit=30` — search by title, plot, genre, language
**Known Issues:** None. The old `api.py /api/search` (scraper search) was renamed to `/api/scraper/search` to unblock this.

---

### `hub/routes/poster_proxy.py` ← NEW 2026-05-30
**Purpose:** Server-side poster lookup with TMDB/OMDB/IMDbAPI key rotation + 30-day SQLite cache.
**Blueprint:** `poster_proxy_bp` (no prefix — routes defined with full `/api/poster/` paths)
**Key Endpoints:**
- `GET /api/poster/search?title=&year=&media_type=` — single poster lookup
- `POST /api/poster/batch` — batch poster lookup (up to 50 titles)
- `GET /api/poster/keys` — show active key counts (masked)
- `POST /api/poster/add_key` — add TMDB/OMDB key
**Data:** Uses `radd_hub.db` keys table + `poster_cache.db` (auto-created in data dir).
**Known Issues:** Keys stored as plaintext in DB (no Fernet). Keys starting with `gAAAAA` are skipped (old encrypted format).


---

### `hub/routes/analytics.py`
**Purpose:** Admin analytics dashboard data.
**Known Issues:** `u.name` column bug previously (NULL as name fix applied). Watch for `COUNT(wh.id)` vs `COUNT(*)` — `watch_history` may have no `id` column.

---

### `hub/routes/admin.py`
**Purpose:** Admin panel authentication and user management.
**Known Issues:** None critical.

---

### `hub/routes/bots.py`
**Purpose:** WhatsApp and Telegram bot management API + UI.
**Key Endpoints:** `/bots/api/whatsapp/*`, `/bots/api/telegram/*`
**Known Issues:**
- Telegram bot backend is a skeleton — no real Telegram message handling
- WA bot files expected at `../bots/whatsapp/index.js` relative to radd-hub

---

### `hub/routes/settings.py`
**Purpose:** Admin settings panel — proxy management, API keys, config.
**Known Issues:** None critical.

---

### `hub/routes/zero_rating.py`
**Purpose:** Zero-Rating Manager admin UI — delta file status, published titles count.
**Fixed:** Shows live `published_titles` count from DB (not stale delta count). Stale delta shown as secondary with ⚠ warning.
**Known Issues:** None (BUG-P4 fixed).

---

### `hub/routes/payment_gateway.py`
**Purpose:** Admin UI for configuring payment gateways (JazzCash, EasyPaisa).
**Known Issues:** If `payment_methods` table is empty, Flutter falls back to hardcoded placeholder numbers (BUG-A12).

---

### `hub/jazzdrive.py`
**Purpose:** JazzDrive (SAPI) wrapper — session management, direct link generation.
**Key Functions:**
- `refresh_session()` — renews JazzDrive session token
- `generate_direct_link(shareUrl)` — converts share URL to CDN streaming URL
- `android_refresh_session()` — mobile-specific session refresh
**Known Issues:**
- **BUG-A17:** `jazzdrive_login`, `list_folders`, `create_folder`, `delete_file` lines 27–45 are **empty stubs** — accept args, do nothing. Any code path hitting these silently fails.

---

### `hub/scheduler.py`
**Purpose:** APScheduler recurring tasks.
**Jobs:**
- `rescan_ongoing_titles` — every 24h — rescans ongoing shows via scraper
- `run_scheduled_downloads` — custom interval from DB settings
- `run_delta_generation` — every 24h — regenerates catalog delta
**Tables Used:** `scheduled_downloads`
**Known Issues:** None.

---

### `hub/sync.py`
**Purpose:** Syncs local DB to GitHub JSON and Google Sheets.
**Key Functions:** `sync_all()`, `pull_from_github()`
**Known Issues:**
- **BUG-A18:** GSheets sync uses `_legacy` import that may be missing — `ImportError` at runtime
- `_build_db_snapshot` uses `limit=10_000` — silently truncates if library > 10k files

---

### `hub/radd_recommend.py`
**Purpose:** Generates personalized + trending content recommendations.
**Known Issues:**
- Full engine exists but **no API endpoint exposes it to Flutter** (BUG-A26)
- Recommendation data never reaches the app

---

### `hub/domain_doctor.py`
**Purpose:** Background thread that probes pirate streaming domains for active mirrors.
**Known Issues:** Findings are never surfaced in admin panel UI — background-only.

---

### `hub/self_heal.py`
**Purpose:** Maintenance loop — checks thread health, disk space, missing config.
**Key Functions:** `_db_doctor()`, `_fs_doctor()`, `_config_doctor()`
**Known Issues:** None.

---

### `hub/downloader.py`
**Purpose:** Background download manager using aria2 or urllib.
**Key Functions:** `queue_loop()`, `_process_job()`, `download_file()`
**Known Issues:** None.

---

### `hub/bulk_link_engine.py`
**Purpose:** Proactively generates direct JazzDrive links for all catalog entries.
**Interval:** Every 10 minutes.
**Known Issues:** Status/progress not visible in admin panel.

---

### `hub/templates/base.html`
**Purpose:** Base Jinja2 template with navigation sidebar.
**Nav Links:** Home, Library, Stream, Upload, Organizer, Scan, Analytics, App Users, Plans, TID Payments, Subscriptions, Bots, Broadcast, Settings, DB Manager, Zero-Rating
**Known Issues:** None after DB Manager was added (Phase 11.5).

---

### `hub/templates/*.html` (all admin pages)
**Endpoints Called via JS fetch:**
- `library.html` → `/api/library/scan`, `/api/library/delete`
- `settings.html` → `/settings/api/proxies`, `/settings/api/proxy-test`
- `scan.html` → `/api/scan/start`, `/api/scan/status`
- `stream.html` → `/api/stream/url/<fileId>`
- `upload.html` → `/api/upload/chunk`, `/api/upload/complete`
- `organizer.html` → `/api/organizer/move`, `/api/organizer/rename`
- `bots.html` → `/bots/api/whatsapp/qr`, `/bots/api/whatsapp/pair`
- `db_mgmt.html` → `/api/db_mgmt/tables`, `/api/db_mgmt/query`, `/api/db_mgmt/export`
**All verified against route definitions** — all endpoints exist.

---

## LEGACY / PROTOTYPE

---

### `_watch_prototype/`
**Purpose:** Original prototype API — **DECOMMISSIONED 2026-05-30**. Catalog/search/poster migrated to radd-hub. Supervisor service removed.
**Status:** Dead code. Safe to delete after confirming nothing imports from it.
**Known Issues:**
- `_watch_prototype/routes/app_version.py` returns `pk.jazzmax.app` — this is origin of BUG-A07 (copy-paste into mobile_api.py)
- Still in repo taking up space

---

## BOTS

---

### `radd-hub/bots/whatsapp/`
**Purpose:** Node.js WhatsApp bot using Baileys library.
**Status:** Files exist on Oracle server. **NOT in Replit environment.**
**Key Commands:** movies search, series, popular, trending, account, admin
**Known Issues:** Bot files path expected at `../bots/whatsapp/` relative to radd-hub

---

### `radd-hub/bots/telegram/index.js`
**Purpose:** Telegram bot.
**Status:** Backend handler in `routes/bots.py` is a skeleton. No real message processing.
**Known Issues:** Effectively non-functional.

---

## CI / CONFIG

---

### `.github/workflows/build-apk.yml`
**Purpose:** Builds Flutter APK. Includes Gradle namespace auto-patch for legacy packages.
**Known Issues:** CI test server points to `92.4.95.252` directly (live production).

---

### `.github/workflows/ci-tests.yml`
**Purpose:** Flutter analysis + live API health checks.
**Known Issues:** Tests against live production Oracle server — test runs hit real server.

---

### `raddflix_flutter/pubspec.yaml`
**Key Packages:** `media_kit`, `sqflite_sqlcipher: 3.1.0+1` (pinned), `flutter_secure_storage`, `dio`, `riverpod`, `flutter_animate`, `smooth_page_indicator`, `connectivity_plus`, `package_info_plus`, `local_auth`, `wakelock_plus`
**CRITICAL:** `sqflite_sqlcipher` must stay at `3.1.0+1` — see Phase 4 notes.

---

### `raddflix_flutter/android/app/src/main/AndroidManifest.xml`
**Permissions Needed By Code:**
- `INTERNET` — Dio API calls
- `READ_EXTERNAL_STORAGE` / `MANAGE_EXTERNAL_STORAGE` — local media scanning
- `USE_BIOMETRIC` / `USE_FINGERPRINT` — vault biometric unlock
- `WAKE_LOCK` — player prevents screen sleep

---

### `radd-hub/.env.example`
**Required Environment Variables:**
- `GITHUB_TOKEN` — for sync to GitHub
- `SESSION_SECRET` — JWT signing key
- `VAULT_MASTER_KEY` — API key encryption
- `TMDB_KEY`, `OMDB_KEY` — metadata providers
- `GROQ_API_KEY` / `GEMINI_API_KEY` — AI enrichment
- `RADD_ADMIN_USER`, `RADD_ADMIN_PASS` — admin panel login

---

*End of CODE_MAP — Last Updated: 2026-05-30*
