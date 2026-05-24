import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../core/constants.dart';

/// Smart Poster Service — server-proxied, multi-key, local-cache-first.
///
/// KEY DESIGN: API keys (TMDB / OMDB) NEVER live in the Flutter app.
/// They live in the Radd Hub key vault on the server, which rotates them
/// automatically (least-recently-used, exhaustion tracking, 3 TMDB + 2 OMDB keys).
///
/// Loading priority (fastest/cheapest → slowest):
///   1. Local hidden cache  → instant, zero data, zero API calls
///   2. Server poster proxy → server calls TMDB→OMDB with auto-rotation
///   3. JazzDrive URL       → zero-rated, last resort when offline
///
/// Cache location: appSupportDir/.jazzmax_posters/<md5(titleId)>.jpg
/// Posters are cached for 30 days and loaded lazily per widget.
class PosterService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static Directory? _cacheDir;

  static Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/.jazzmax_posters');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  /// Build a lazy-loading smart poster widget for [titleId].
  ///
  /// [jazzDrivePosterUrl] is used only if server lookup fails and device is offline.
  static Widget buildPoster({
    required String titleId,
    required String titleName,
    required int year,
    String? mediaType,
    String? jazzDrivePosterUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    BorderRadius? borderRadius,
  }) {
    return _SmartPosterWidget(
      titleId: titleId,
      titleName: titleName,
      year: year,
      mediaType: mediaType ?? 'movie',
      jazzDrivePosterUrl: jazzDrivePosterUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder,
      borderRadius: borderRadius,
    );
  }

  /// Returns local cached poster file path, or null if not cached yet.
  static Future<String?> getCachedPosterPath(String titleId) async {
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/${_safeId(titleId)}.jpg');
      if (file.existsSync() && file.lengthSync() > 512) return file.path;
    } catch (_) {}
    return null;
  }

  /// Fetch poster URL from server (server handles TMDB→OMDB rotation).
  /// Returns null on any failure.
  static Future<String?> fetchFromServer(
      String title, int year, String mediaType) async {
    try {
      final response = await _dio.get(
        '${AppConstants.apiBaseUrl}/api/poster/search',
        queryParameters: {
          'title': title,
          'year': year,
          'media_type': mediaType,
        },
      );
      if (response.statusCode == 200) {
        final url = response.data['poster_url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
    } catch (_) {}
    return null;
  }

  /// Download a poster from [url] and cache it locally.
  /// Returns local file path on success, null on failure.
  static Future<String?> downloadAndCache(String titleId, String url) async {
    try {
      final dir = await _getCacheDir();
      final filePath = '${dir.path}/${_safeId(titleId)}.jpg';
      final file = File(filePath);

      if (file.existsSync() && file.lengthSync() > 512) return filePath;

      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200 && response.data != null) {
        await file.writeAsBytes(response.data!);
        return filePath;
      }
    } catch (_) {}
    return null;
  }

  /// MD5 of titleId — safe filename with no special chars.
  static String _safeId(String id) =>
      md5.convert(utf8.encode(id)).toString();

  /// Prune posters older than 30 days to save storage.
  static Future<void> pruneOldCache() async {
    try {
      final dir = await _getCacheDir();
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final files = dir.listSync();
      for (final f in files) {
        if (f is File) {
          final stat = f.statSync();
          if (stat.modified.isBefore(cutoff)) {
            try { f.deleteSync(); } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}

/// Internal lazy-loading poster widget with full fallback chain.
class _SmartPosterWidget extends StatefulWidget {
  final String titleId;
  final String titleName;
  final int year;
  final String mediaType;
  final String? jazzDrivePosterUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final BorderRadius? borderRadius;

  const _SmartPosterWidget({
    required this.titleId,
    required this.titleName,
    required this.year,
    required this.mediaType,
    this.jazzDrivePosterUrl,
    this.width,
    this.height,
    required this.fit,
    this.placeholder,
    this.borderRadius,
  });

  @override
  State<_SmartPosterWidget> createState() => _SmartPosterWidgetState();
}

class _SmartPosterWidgetState extends State<_SmartPosterWidget> {
  String? _localPath;    // local cached file (highest priority, fastest)
  String? _remoteUrl;    // remote URL to display (if no local file yet)
  bool _resolved = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    // Step 1 — local cache (instant, zero data)
    final cached = await PosterService.getCachedPosterPath(widget.titleId);
    if (cached != null) {
      if (mounted) setState(() { _localPath = cached; _resolved = true; });
      return;
    }

    // Step 2 — server proxy (TMDB → OMDB auto-rotation, server-side cache)
    final serverUrl = await PosterService.fetchFromServer(
        widget.titleName, widget.year, widget.mediaType);

    if (serverUrl != null) {
      // Download and cache locally for future offline use
      final localPath = await PosterService.downloadAndCache(
          widget.titleId, serverUrl);
      if (localPath != null) {
        if (mounted) setState(() { _localPath = localPath; _resolved = true; });
        return;
      }
      // Download failed — still show from remote URL
      if (mounted) setState(() { _remoteUrl = serverUrl; _resolved = true; });
      return;
    }

    // Step 3 — JazzDrive URL (zero-rated, last resort for offline users)
    if (widget.jazzDrivePosterUrl != null &&
        widget.jazzDrivePosterUrl!.isNotEmpty) {
      if (mounted) {
        setState(() { _remoteUrl = widget.jazzDrivePosterUrl; _resolved = true; });
      }
      return;
    }

    // Step 4 — no poster found
    if (mounted) setState(() { _resolved = true; _failed = true; });
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (!_resolved) {
      child = _placeholder();
    } else if (_failed || (_localPath == null && _remoteUrl == null)) {
      child = _fallback();
    } else if (_localPath != null) {
      child = Image.file(
        File(_localPath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else {
      child = Image.network(
        _remoteUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (_, c, prog) => prog == null ? c : _placeholder(),
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return child;
  }

  Widget _placeholder() {
    if (widget.placeholder != null) return widget.placeholder!;
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            strokeWidth: 2,
            backgroundColor: Colors.white12,
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF141422),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C1C35), Color(0xFF0E0E1C)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_filter_rounded,
              color: Color(0xFF333355), size: 28),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              widget.titleName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF444466),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
