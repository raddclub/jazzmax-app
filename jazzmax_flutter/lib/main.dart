import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'app.dart';
import 'core/remote_config.dart';
import 'core/services/app_update_service.dart';
import 'core/debug/debug_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Debug logger — must be first so all errors are captured ──────────────
  await DebugLogger.init();
  DebugLogger.log('APP', 'Cold start');

  // Capture all Flutter widget-layer errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    DebugLogger.logCrash(
        'FlutterError', details.exception, details.stack);
  };

  // Capture all uncaught Dart async / platform errors
  ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    DebugLogger.logCrash('PlatformDispatcher', error, stack);
    return true;
  };

  // Log device hardware info (model, Android version, etc.)
  await DebugLogger.logDeviceInfo();

  // Lock to portrait (player screen overrides to landscape when needed)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  DebugLogger.log('APP', 'Orientation locked to portrait');

  // Initialize media_kit video engine
  MediaKit.ensureInitialized();
  DebugLogger.log('APP', 'MediaKit initialized');

  // Fetch server URL from GitHub config — no APK rebuild needed when server changes.
  // Falls back to hardcoded AppConstants.apiBaseUrl if network/parse fails.
  DebugLogger.log('APP', 'Fetching RemoteConfig...');
  await RemoteConfig.fetch();

  // Check for forced app updates / blocked APK on every cold start
  await AppUpdateService.check();
  DebugLogger.log('APP', 'AppUpdateService check done');

  DebugLogger.log('APP', 'Starting Flutter runApp');
  runApp(
    const ProviderScope(
      child: JazzMaxApp(),
    ),
  );
}
