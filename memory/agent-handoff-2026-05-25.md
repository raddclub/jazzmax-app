# JazzMAX Agent Handoff — 2026-05-25

## Quick-Start Checklist for Next Agent
1. SSH: `ssh -i ~/.ssh/oracle_key ubuntu@92.4.95.252`
2. Repo root: `/opt/jazzmax/`  — git remote: `raddclub/jazzmax-app`
3. Push to `main` -> GitHub Actions builds TWO APKs automatically
4. **Shell quoting gotcha**: Never use `python3 -c "..."` with parens/quotes in string.
   Always use SSH heredoc pattern: `ssh ... 'python3 << 'PYEOF' ... PYEOF'`
5. Read `memory/jazzmax-arch.md` for architecture overview

---

## Completed This Session (2026-05-25)

### Buffered Seek Bar (player_screen.dart)
- Added `Duration _bufferedPosition = Duration.zero;` state var
- Subscribes to `_player.stream.buffer` -> updates `_bufferedPosition`
- `_ControlsOverlay` accepts `bufferedFraction` (double 0-1)
- Seek bar is a Stack: gray LinearProgressIndicator behind red Slider
- Inactive slider track set to `Colors.transparent` so buffer bar shows through

### Seek Buttons 10s -> 15s (player_screen.dart)
- `onSeekBack: () => _seekRelative(-15)` (was -10)
- `onSeekForward: () => _seekRelative(15)` (was 10)
- NOTE: Icons still show replay_10/forward_10 — Flutter has no replay_15 icon.
  Cosmetic only; behavior is correct at 15s.

### Sleep Timer Double-Fire Fixed (player_screen.dart)
- Position stream had a redundant sleep-seconds-check that conflicted with _sleepTimer
- Removed; sleep is now handled solely by the dedicated Periodic _sleepTimer

### Urdu Filter Bug Fixed (search_screen.dart, home_screen.dart)
- Bug: `_applyFilter` matched Urdu content OR content with EMPTY language field
- Fix: Removed `|| (i.language ?? ).isEmpty` — now only genuine Urdu content matches

### Profile Theme Display Reactive (profile_screen.dart)
- `ref.read(themeProvider.notifier).displayName` -> `ref.watch(...)` 
- Theme list tile now updates immediately when theme changes

### See-All Button Fixed (home_screen.dart)
- Was: `TextButton(onPressed: () {})` — completely dead
- Now: navigates to `AppRoutes.search`

---

## Known Remaining Bugs

### [CRITICAL] Light Theme Broken Everywhere
Root cause: Every screen uses `AppColors.*` constants which are `static const Color`.
Screens override ThemeData with hardcoded dark values:
  - `Scaffold(backgroundColor: AppColors.background)` overrides scaffoldBackgroundColor
  - `TextStyle(color: AppColors.textPrimary)` always renders white text

Why it is hard to fix: constants are used in `const` widget constructors everywhere.
Making them non-const getters breaks compile-time const assertions on ~200+ widgets.

Recommended fix approach:
1. Add a BuildContext extension in `lib/core/theme/jazz_colors.dart`:
     extension JazzColors on BuildContext {
       bool get isDark => Theme.of(this).brightness == Brightness.dark;
       Color get jazzBg => isDark ? AppColors.background : const Color(0xFFF0F0F7);
       Color get jazzText => isDark ? AppColors.textPrimary : const Color(0xFF0A0A1A);
       Color get jazzSurface => isDark ? AppColors.surface : Colors.white;
     }
2. In each screen, replace `AppColors.background` -> `context.jazzBg` in Scaffold backgroundColor
3. Replace `const TextStyle(color: AppColors.textPrimary)` -> `TextStyle(color: context.jazzText)`
   (must remove `const` keyword from those TextStyle constructors)
4. Affects ~10 screens, ~200+ TextStyle usages

Quick-win partial fix (makes backgrounds switch, text still white in light mode):
  Change `backgroundColor: AppColors.background` -> `backgroundColor: null` in each Scaffold.
  Screens: home, search, show_detail, downloads, profile, subscription, login, register

### [MEDIUM] PIN Dots Always Show 6 (vault_lock_screen.dart)
`_PinDots` always renders 6 circles but vault can use 4-digit PINs.
Fix: Pass expected PIN length to _PinDots.

### [MEDIUM] Seek Button Icons Show "10" But Seek Is 15s
Flutter Material has no replay_15 icon. Fix: custom Stack(Icon + Text("15")) in _SeekBtn.

### [MEDIUM] Downloads Folder Heuristic Unreliable (downloads_screen.dart)
`_folderFor(item)` guesses category by string-matching show name.
Fix: Store contentType on DownloadRecord at download time.

### [LOW] heroGradient Always Fades to Dark (constants.dart)
`AppColors.heroGradient` hardcodes `Color(0xFF08080E)` as the end color.
In light mode this creates a visible dark seam under the hero image.
Fix: Make it a BuildContext method using context.jazzBg.

### [LOW] See-All Sections Dont Pre-Filter
See-All buttons now navigate to Search but do not pass genre/category context.
Fix: Pass a filter/query param via GoRouter extras.

---

## Architecture Summary

### Flutter App (jazzmax_flutter/)
  main.dart              Entry point, ProviderScope
  app.dart               JazzMaxApp with GoRouter, watches themeProvider
  core/
    constants.dart       AppColors, AppSpacing, AppRadius (all static const)
    theme/app_theme.dart JazzThemeData.build(mode) — correct ThemeData for dark/light
    router.dart          GoRouter, AppRoutes.* constants
    providers.dart       Global Riverpod providers
  models/
    catalog_item.dart    CatalogItem with isMovie/isShow/isLocal/isDownloaded getters
    user_profile.dart    UserProfile
  services/
    api_service.dart     HTTP to Flask backend
    auth_service.dart    Login/register/session
    player_service.dart  media_kit Player wrapper
    download_service.dart File downloads
    vault_service.dart   Secure PIN storage
  screens/               14 screens (all ConsumerStatefulWidget or ConsumerWidget)
  widgets/               content_card.dart, episode_tile.dart, loading.dart etc.

### Backend (Flask on Oracle Cloud)
  Server:  ubuntu@92.4.95.252
  Service: sudo systemctl status jazzmax-api
  Port:    5000 (internal), nginx proxies 80/443
  Logs:    sudo journalctl -u jazzmax-api -f
  Code:    /opt/jazzmax/backend/

### GitHub Actions (APK Build)
  build-apk.yml  — Flutter 3.22.x / Dart 3.4.4  <-- prefer this
  build_apk.yml  — Flutter 3.19.6 (legacy)
  SDK constraint: sdk: >=3.0.0 <4.0.0  — do NOT change package versions

---

## Session History
  Pre-2026-05-25  Kotlin MainActivity.kt fix (string literals) -> APK builds OK
  2026-05-25      Buffered seek bar, seek 15s, Urdu filter, sleep timer, profile, See-All

---

## Common Gotchas
1. Shell quoting: parens in Python strings break bash -c. Use SSH heredoc always.
2. const AppColors: Cannot be changed to dynamic getters without breaking const widgets.
3. Two build workflows: if one fails check the other (different Flutter versions).
4. Git push auth: use env = {**os.environ, "GIT_TERMINAL_PROMPT": "0"} in subprocess.
5. Backend port 5000: if down, sudo systemctl restart jazzmax-api
