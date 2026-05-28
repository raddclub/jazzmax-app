# RaddFlix Flutter App

Flutter mobile app for the RaddFlix streaming platform.

**Package ID:** `com.raddflix.app`
**Min Android SDK:** 21
**Server path (Oracle):** `/opt/jazzmax/raddflix_flutter/`

## Build (on dev machine with Flutter SDK)

```bash
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

## Key Folders

```
lib/
├── core/
│   ├── api/          ← HTTP client (Dio)
│   ├── db/           ← Local SQLite cache + sync
│   ├── services/     ← JazzDrive, notifications, updates
│   ├── security/     ← Device ID, keystore
│   └── theme/        ← radd_colors.dart (dark/light theme)
├── screens/          ← All app screens
└── widgets/          ← Shared UI widgets (radd_text_field, etc.)
android/
├── app/build.gradle  ← Signing config (uses KEYSTORE_* env vars)
└── app/src/main/res/xml/network_security_config.xml
```

→ Full documentation: [`agent-hub/projects/flutter-app.md`](../agent-hub/projects/flutter-app.md)

  ## Recent Changes (2026-05-28)

  - **MX Player-style UI** — `player_screen.dart` `_ControlsOverlay` fully redesigned: right-side vertical strip, large red circle play/pause, circular seek buttons, clean bottom bar
  - **Bug fix** — Error popup no longer fires during active playback on slow streams
  - **Bug fix** — Movie "Play Now" button now shows a friendly error instead of silently doing nothing
  