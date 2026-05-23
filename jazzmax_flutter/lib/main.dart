import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:workmanager/workmanager.dart';
import 'app.dart';
import 'core/download/background_download_worker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait (player screen overrides to landscape when needed)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize media_kit video engine
  MediaKit.ensureInitialized();

  // Initialize WorkManager for background downloads that survive app kill.
  // The dispatcher function must be top-level (annotated with @pragma).
  await Workmanager().initialize(
    backgroundDownloadDispatcher,
    isInDebugMode: false,
  );

  // RemoteConfig is fetched non-blocking in splash_screen.dart.
  // Do NOT await it here — that blocks runApp() and leaves a blank screen.

  runApp(
    const ProviderScope(
      child: JazzMaxApp(),
    ),
  );
}
