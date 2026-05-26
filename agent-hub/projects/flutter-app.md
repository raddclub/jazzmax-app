# RaddFlix Flutter Mobile App

## What it is
The user-facing streaming app for Android (and eventually iOS). Jazz SIM users stream movies/dramas for free (JazzDrive zero-rating). Non-Jazz users can also subscribe with limited access.

## Location
- **Server:** `/opt/jazzmax/jazzmax_flutter/` (folder name is legacy — internal only)
- **GitHub:** `jazzmax_flutter/` folder in `raddclub/raddflix-app`
- **Build:** Must be done on a development machine with Flutter SDK installed. Not built on the Oracle server.

## Tech Stack
- Flutter / Dart
- Dio (HTTP client)
- SQLite (drift/sqflite — local cache)
- Firebase Cloud Messaging (push notifications)
- FCM channel ID: `raddflix_alerts`

## Package Info
- **App name:** RaddFlix
- **Package ID:** `com.raddflix.app`
- **Version:** 1.0.0+1
- **Min SDK:** 21 (Android 5.0)
- **Target SDK:** 34

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point |
| `lib/app.dart` | Root widget, theme, routing |
| `lib/core/api/api_client.dart` | Dio HTTP client, base URL config |
| `lib/core/services/jazzdrive_service.dart` | JazzDrive stream URL generator (zero-rated) |
| `lib/core/services/notification_service.dart` | FCM push notifications |
| `lib/core/services/app_update_service.dart` | In-app update checker |
| `lib/core/db/local_db.dart` | Local SQLite cache |
| `lib/core/db/sync_service.dart` | Syncs content from server |
| `lib/core/theme/radd_colors.dart` | Theme extension (dark/light mode colors) |
| `lib/core/security/device_id.dart` | Device fingerprinting |
| `lib/core/security/keystore.dart` | Secure credential storage |
| `lib/screens/home_screen.dart` | Main home screen |
| `lib/screens/login_screen.dart` | Login |
| `lib/screens/register_screen.dart` | Registration |
| `lib/screens/splash_screen.dart` | Splash/loading screen |
| `lib/screens/subscription_screen.dart` | Subscription plans |
| `lib/screens/vault_screen.dart` | Downloaded content vault |
| `lib/widgets/radd_text_field.dart` | Shared text input widget |
| `android/app/build.gradle` | Android build config, signing |
| `android/app/google-services.json` | Firebase config |

## Keystore / Signing
- Keystore file: `keystore/raddflix.keystore`
- Key alias: `raddflix`
- Passwords stored in env vars: `KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`
- Fallback values in `build.gradle` use `raddflix` (already rebranded)

## Build Command (on dev machine with Flutter SDK)

```bash
cd jazzmax_flutter
flutter build apk --release
# APK output: build/app/outputs/flutter-apk/app-release.apk
```

## Missing Features (Backlog)
The app is functional but missing many features. Key gaps:
- Download manager UI (backend service exists, no UI)
- Offline playback of downloaded content
- Continue watching / watch history
- Search functionality
- User profile / account settings screen
- Language filter (Urdu/English)
- Rating / review system
- Parental controls
- Picture-in-picture mode
- Chromecast support

## API Connection
The app connects to the Oracle server (watch API on port 6000):
- Base URL configured in `lib/core/api/api_client.dart`
- HTTP cleartext allowed for `92.4.95.252` (configured in `network_security_config.xml`)
