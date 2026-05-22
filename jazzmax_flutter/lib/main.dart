import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'app.dart';
import 'core/remote_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait (player screen overrides to landscape when needed)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize media_kit video engine
  MediaKit.ensureInitialized();

  // Fetch server URL from GitHub config — no APK rebuild needed when server changes.
  // Falls back to hardcoded AppConstants.apiBaseUrl if network/parse fails.
  await RemoteConfig.fetch();

  runApp(
    const ProviderScope(
      child: JazzMaxApp(),
    ),
  );
}
