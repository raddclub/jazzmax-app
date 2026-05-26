import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'app.dart';
import 'core/remote_config.dart';
import 'core/services/app_update_service.dart';
import 'core/services/jazzdrive_service.dart';
import 'core/services/poster_service.dart';
import 'core/db/local_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  MediaKit.ensureInitialized();

  // Fetch remote server URL — falls back to hardcoded if network fails
  try { await RemoteConfig.fetch(); } catch (_) {}

  // Check for forced updates — non-fatal
  try { await AppUpdateService.check(); } catch (_) {}

  // Boot zero-rated services — all non-fatal, app works without them
  try { await PosterService.init(); } catch (_) {}
  try { await JazzDriveService.loadCacheFromDb(); } catch (_) {}
  try { await LocalDb.cleanExpiredStreamCache(); } catch (_) {}

  runApp(
    const ProviderScope(
      child: ZenoApp(),
    ),
  );
}
