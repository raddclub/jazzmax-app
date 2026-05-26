import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/catalog_item.dart';
import '../constants.dart';

/// Shared local SQLite database for:
/// - Catalog (titles + episodes + share_urls for zero-rated link gen)
/// - Watch history / resume positions
/// - Download metadata
/// - Stream link cache (6h TTL, shared between watch + download)
class LocalDb {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _openDb();
    return _db!;
  }

  static Future<Database> _openDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, AppConstants.catalogDbName);

    return openDatabase(
      path,
      version: AppConstants.catalogDbVersion,
      onCreate: _createAll,
      onUpgrade: _migrate,
    );
  }

  static Future<void> _createAll(Database db, int version) async {
    await db.execute('''
      CREATE TABLE titles (
        id          INTEGER PRIMARY KEY,
        title       TEXT NOT NULL,
        year        INTEGER,
        media_type  TEXT NOT NULL,
        description TEXT,
        rating      REAL,
        genres      TEXT,
        poster_url  TEXT,
        poster_path TEXT,
        share_url   TEXT,
        is_free     INTEGER DEFAULT 0,
        db_version  INTEGER DEFAULT 0,
        language    TEXT,
        status      TEXT,
        is_ongoing  INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE episodes (
        id        INTEGER PRIMARY KEY,
        title_id  INTEGER NOT NULL,
        file_id   TEXT,
        season    INTEGER,
        episode   INTEGER,
        label     TEXT,
        quality   TEXT,
        is_free   INTEGER DEFAULT 0,
        share_url TEXT,
        FOREIGN KEY (title_id) REFERENCES titles(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_meta (
        key   TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE watch_positions (
        file_id     TEXT PRIMARY KEY,
        position_ms INTEGER DEFAULT 0,
        duration_ms INTEGER DEFAULT 0,
        updated_at  INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE downloads (
        file_id       TEXT PRIMARY KEY,
        title_text    TEXT,
        poster_url    TEXT,
        local_path    TEXT,
        status        TEXT DEFAULT 'pending',
        progress      REAL DEFAULT 0.0,
        file_size     INTEGER DEFAULT 0,
        downloaded_at INTEGER DEFAULT 0,
        content_type  TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE stream_cache (
        file_id    TEXT PRIMARY KEY,
        stream_url TEXT NOT NULL,
        poster_url TEXT,
        created_at INTEGER DEFAULT 0,
        expires_at INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_titles_type ON titles(media_type)');
    await db.execute('CREATE INDEX idx_episodes_title ON episodes(title_id)');
    await db.execute('CREATE INDEX idx_stream_cache_expires ON stream_cache(expires_at)');
  }

  static Future<void> _migrate(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS watch_positions (
          file_id     TEXT PRIMARY KEY,
          position_ms INTEGER DEFAULT 0,
          duration_ms INTEGER DEFAULT 0,
          updated_at  INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldV < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS downloads (
          file_id       TEXT PRIMARY KEY,
          title_text    TEXT,
          poster_url    TEXT,
          local_path    TEXT,
          status        TEXT DEFAULT 'pending',
          progress      REAL DEFAULT 0.0,
          file_size     INTEGER DEFAULT 0,
          downloaded_at INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldV < 4) {
      for (final col in ['language TEXT', 'status TEXT', 'is_ongoing INTEGER DEFAULT 0']) {
        try { await db.execute('ALTER TABLE titles ADD COLUMN $col'); } catch (_) {}
      }
    }
    if (oldV < 8) {
      try { await db.execute('ALTER TABLE downloads ADD COLUMN content_type TEXT'); } catch (_) {}
    }
    if (oldV < 9) {
      try {
        await db.execute("UPDATE titles SET media_type = 'show' WHERE media_type IN ('series', 'tv')");
      } catch (_) {}
      try { await db.delete('sync_meta'); } catch (_) {}
    }
    if (oldV < 10) {
      // Add share_url to titles (for movie-level files)
      try { await db.execute('ALTER TABLE titles ADD COLUMN share_url TEXT'); } catch (_) {}
      // Add share_url to episodes
      try { await db.execute('ALTER TABLE episodes ADD COLUMN share_url TEXT'); } catch (_) {}
      // Add local poster path to titles
      try { await db.execute('ALTER TABLE titles ADD COLUMN poster_path TEXT'); } catch (_) {}
      // Stream link cache table (6h TTL, shared for watch + download)
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS stream_cache (
            file_id    TEXT PRIMARY KEY,
            stream_url TEXT NOT NULL,
            poster_url TEXT,
            created_at INTEGER DEFAULT 0,
            expires_at INTEGER DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_stream_cache_expires ON stream_cache(expires_at)',
        );
      } catch (_) {}
    }
  }

  // ── Titles ────────────────────────────────────────────────────────────────

  static Future<List<CatalogItem>> getMovies() async {
    final db = await instance;
    final rows = await db.query('titles',
        where: 'media_type = ?', whereArgs: ['movie'], orderBy: 'title ASC');
    return rows.map(_rowToItem).toList();
  }

  static Future<List<CatalogItem>> getShows() async {
    final db = await instance;
    final rows = await db.query('titles',
        where: 'media_type = ?', whereArgs: ['show'], orderBy: 'title ASC');
    return rows.map(_rowToItem).toList();
  }

  static Future<List<CatalogItem>> searchTitles(String query) async {
    final db = await instance;
    final rows = await db.query('titles',
        where: 'title LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'title ASC',
        limit: 50);
    return rows.map(_rowToItem).toList();
  }

  static Future<void> upsertTitle(CatalogItem item) async {
    final db = await instance;
    await db.insert(
      'titles',
      {
        'id':         item.id,
        'title':      item.title,
        'year':       item.year,
        'media_type': item.mediaType,
        'description': item.description,
        'rating':     item.rating,
        'genres':     item.genres,
        'poster_url': item.posterUrl,
        'share_url':  item.shareUrl,
        'is_free':    item.isFree ? 1 : 0,
        'db_version': item.dbVersion,
        'language':   item.language,
        'status':     item.status,
        'is_ongoing': (item.isOngoing ?? false) ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get the JazzDrive share_url for a file_id.
  /// Checks both episodes (for TV) and titles (for movies) tables.
  static Future<String?> getShareUrl(String fileId) async {
    final db = await instance;
    // Check episodes first
    final epRows = await db.query('episodes',
        where: 'file_id = ?', whereArgs: [fileId], limit: 1);
    if (epRows.isNotEmpty) {
      final url = epRows.first['share_url'] as String?;
      if (url != null && url.isNotEmpty) return url;
    }
    // Check titles (for movie-level file_ids stored in titles table)
    final titleRows = await db.rawQuery(
      'SELECT share_url FROM titles WHERE id = ? LIMIT 1',
      [int.tryParse(fileId) ?? -1],
    );
    if (titleRows.isNotEmpty) {
      return titleRows.first['share_url'] as String?;
    }
    return null;
  }

  /// Save the local poster path for a title (after permanent download).
  static Future<void> savePosterPath(int titleId, String localPath) async {
    final db = await instance;
    await db.update(
      'titles',
      {'poster_path': localPath},
      where: 'id = ?',
      whereArgs: [titleId],
    );
  }

  // ── Episodes ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getEpisodes(int titleId) async {
    final db = await instance;
    return db.query('episodes',
        where: 'title_id = ?',
        whereArgs: [titleId],
        orderBy: 'season ASC, episode ASC');
  }

  static Future<void> upsertEpisode(Map<String, dynamic> ep) async {
    final db = await instance;
    await db.insert('episodes', ep,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── Stream Cache ──────────────────────────────────────────────────────────

  /// Get a cached stream link for [fileId]. Returns null if not cached or expired.
  static Future<Map<String, dynamic>?> getStreamCache(String fileId) async {
    final db = await instance;
    final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final rows = await db.query('stream_cache',
        where: 'file_id = ? AND expires_at > ?',
        whereArgs: [fileId, nowTs],
        limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Get all non-expired stream cache entries (for loading into memory on start).
  static Future<List<Map<String, dynamic>>> getValidStreamCache() async {
    final db = await instance;
    final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return db.query('stream_cache',
        where: 'expires_at > ?', whereArgs: [nowTs]);
  }

  /// Save a stream link to cache.
  static Future<void> saveStreamCache({
    required String fileId,
    required String streamUrl,
    String? posterUrl,
    required int expiresAt,
  }) async {
    final db = await instance;
    await db.insert(
      'stream_cache',
      {
        'file_id':    fileId,
        'stream_url': streamUrl,
        'poster_url': posterUrl,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'expires_at': expiresAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete a specific stream cache entry (force refresh on next play).
  static Future<void> deleteStreamCache(String fileId) async {
    final db = await instance;
    await db.delete('stream_cache', where: 'file_id = ?', whereArgs: [fileId]);
  }

  /// Remove all expired stream cache entries. Call once per day on app start.
  static Future<void> cleanExpiredStreamCache() async {
    final db = await instance;
    final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final deleted = await db.delete('stream_cache',
        where: 'expires_at <= ?', whereArgs: [nowTs]);
    if (deleted > 0) {
      // ignore: avoid_print
      print('[LocalDb] Cleaned $deleted expired stream cache entries');
    }
  }

  // ── Sync metadata ─────────────────────────────────────────────────────────

  static Future<int> getLastSyncVersion() async {
    final db = await instance;
    final rows = await db.query('sync_meta',
        where: 'key = ?', whereArgs: ['last_version']);
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['value'] as String? ?? '0') ?? 0;
  }

  static Future<void> setLastSyncVersion(int version) async {
    final db = await instance;
    await db.insert('sync_meta',
        {'key': 'last_version', 'value': version.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<int> getLastSyncTimestamp() async {
    final db = await instance;
    final rows = await db.query('sync_meta',
        where: 'key = ?', whereArgs: ['last_sync_ts']);
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['value'] as String? ?? '0') ?? 0;
  }

  static Future<void> setLastSyncTimestamp(int ts) async {
    final db = await instance;
    await db.insert('sync_meta',
        {'key': 'last_sync_ts', 'value': ts.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<int> getTotalCount() async {
    final db = await instance;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM titles');
    return (result.first['c'] as int?) ?? 0;
  }

  // ── Watch Positions ───────────────────────────────────────────────────────

  static Future<int> getSavedPosition(String fileId) async {
    final db = await instance;
    final rows = await db.query('watch_positions',
        where: 'file_id = ?', whereArgs: [fileId]);
    if (rows.isEmpty) return 0;
    return rows.first['position_ms'] as int? ?? 0;
  }

  static Future<void> savePosition(String fileId, int positionMs,
      {int durationMs = 0}) async {
    final db = await instance;
    await db.insert(
      'watch_positions',
      {
        'file_id':     fileId,
        'position_ms': positionMs,
        'duration_ms': durationMs,
        'updated_at':  DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> clearPosition(String fileId) async {
    final db = await instance;
    await db.delete('watch_positions',
        where: 'file_id = ?', whereArgs: [fileId]);
  }

  static Future<List<Map<String, dynamic>>> getWatchPositions() async {
    final db = await instance;
    return db.query('watch_positions',
        orderBy: 'updated_at DESC', limit: 20);
  }

  static Future<void> saveWatchPosition({
    required String fileId,
    required int positionMs,
    required int durationMs,
  }) async {
    await savePosition(fileId, positionMs, durationMs: durationMs);
  }

  // ── Downloads ─────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getDownloads() async {
    final db = await instance;
    return db.query('downloads', orderBy: 'downloaded_at DESC');
  }

  static Future<void> insertDownload({
    required String fileId,
    required String titleText,
    String? posterUrl,
    required String localPath,
    String? contentType,
  }) async {
    final db = await instance;
    await db.insert(
      'downloads',
      {
        'file_id':       fileId,
        'title_text':    titleText,
        'poster_url':    posterUrl,
        'local_path':    localPath,
        'status':        'downloading',
        'progress':      0.0,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
        'content_type':  contentType,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> updateDownloadProgress(
      String fileId, double progress) async {
    final db = await instance;
    await db.update(
      'downloads',
      {'progress': progress},
      where: 'file_id = ?',
      whereArgs: [fileId],
    );
  }

  static Future<void> updateDownloadStatus(
      String fileId, String status, double progress, int fileSize) async {
    final db = await instance;
    await db.update(
      'downloads',
      {'status': status, 'progress': progress, 'file_size': fileSize},
      where: 'file_id = ?',
      whereArgs: [fileId],
    );
  }

  static Future<void> deleteDownload(String fileId) async {
    final db = await instance;
    final rows = await db.query('downloads',
        where: 'file_id = ?', whereArgs: [fileId]);
    if (rows.isNotEmpty) {
      final path = rows.first['local_path'] as String?;
      if (path != null) {
        try { await File(path).delete(); } catch (_) {}
      }
    }
    await db.delete('downloads', where: 'file_id = ?', whereArgs: [fileId]);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static CatalogItem _rowToItem(Map<String, dynamic> row) {
    return CatalogItem(
      id:          row['id'] as int,
      title:       row['title'] as String,
      year:        row['year'] as int?,
      mediaType:   row['media_type'] as String,
      description: row['description'] as String?,
      rating:      (row['rating'] as num?)?.toDouble(),
      genres:      row['genres'] as String?,
      posterUrl:   row['poster_url'] as String?,
      shareUrl:    row['share_url'] as String?,
      isFree:      (row['is_free'] as int? ?? 0) == 1,
      dbVersion:   row['db_version'] as int? ?? 0,
      language:    row['language'] as String?,
      status:      row['status'] as String?,
      isOngoing:   (row['is_ongoing'] as int? ?? 0) == 1,
    );
  }
}
