import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/catalog_item.dart';

/// Shared local SQLite database for:
/// - Catalog (titles + episodes)
/// - Watch history / resume positions
/// - Downloads metadata
/// - Watchlist (saved favorites)
/// Stream URLs are NEVER stored here — always fetched live.
class LocalDb {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _openDb();
    return _db!;
  }

  static Future<Database> _openDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'jazzmax_catalog.db');

    return openDatabase(
      path,
      version: 6,
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
        is_free     INTEGER DEFAULT 0,
        db_version  INTEGER DEFAULT 0,
        file_id     TEXT
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
        title_id    INTEGER,
        title_text  TEXT,
        poster_url  TEXT,
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
        downloaded_at INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE watchlist (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        title_id    INTEGER NOT NULL UNIQUE,
        title       TEXT NOT NULL,
        year        INTEGER,
        media_type  TEXT,
        description TEXT,
        rating      REAL,
        genres      TEXT,
        poster_url  TEXT,
        is_free     INTEGER DEFAULT 0,
        file_id     TEXT,
        added_at    INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE ratings (
        title_id INTEGER PRIMARY KEY,
        rating   INTEGER NOT NULL,
        rated_at INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_titles_type ON titles(media_type)');
    await db.execute('CREATE INDEX idx_episodes_title ON episodes(title_id)');
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
      try {
        await db.execute('ALTER TABLE titles ADD COLUMN file_id TEXT');
      } catch (_) {}
    }
    if (oldV < 5) {
      try { await db.execute('ALTER TABLE watch_positions ADD COLUMN title_id INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE watch_positions ADD COLUMN title_text TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE watch_positions ADD COLUMN poster_url TEXT'); } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS watchlist (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          title_id    INTEGER NOT NULL UNIQUE,
          title       TEXT NOT NULL,
          year        INTEGER,
          media_type  TEXT,
          description TEXT,
          rating      REAL,
          genres      TEXT,
          poster_url  TEXT,
          is_free     INTEGER DEFAULT 0,
          file_id     TEXT,
          added_at    INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldV < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ratings (
          title_id INTEGER PRIMARY KEY,
          rating   INTEGER NOT NULL,
          rated_at INTEGER DEFAULT 0
        )
      ''');
    }
  }

  // ── Titles ────────────────────────────────────────────────────────────────

  static Future<List<CatalogItem>> getMovies() async {
    final db = await instance;
    final rows = await db.query('titles',
        where: 'media_type = ?', whereArgs: ['movie'], orderBy: 'rating DESC, title ASC');
    return rows.map(_rowToItem).toList();
  }

  static Future<List<CatalogItem>> getShows() async {
    final db = await instance;
    final rows = await db.query('titles',
        where: 'media_type = ?', whereArgs: ['show'], orderBy: 'rating DESC, title ASC');
    return rows.map(_rowToItem).toList();
  }

  static Future<List<CatalogItem>> getFreeItems() async {
    final db = await instance;
    final rows = await db.query('titles',
        where: 'is_free = 1', orderBy: 'rating DESC, title ASC', limit: 20);
    return rows.map(_rowToItem).toList();
  }

  static Future<CatalogItem?> getTitle(int id) async {
    final db = await instance;
    final rows = await db.query('titles', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToItem(rows.first);
  }

  static Future<List<CatalogItem>> searchTitles(String query) async {
    final db = await instance;
    final rows = await db.query('titles',
        where: 'title LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'rating DESC, title ASC',
        limit: 50);
    return rows.map(_rowToItem).toList();
  }

  static Future<void> upsertTitle(CatalogItem item) async {
    final db = await instance;
    await db.insert(
      'titles',
      {
        'id': item.id,
        'title': item.title,
        'year': item.year,
        'media_type': item.mediaType,
        'description': item.description,
        'rating': item.rating,
        'genres': item.genres,
        'poster_url': item.posterUrl,
        'is_free': item.isFree ? 1 : 0,
        'db_version': item.dbVersion,
        'file_id': item.fileId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
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

  // ── Watch Positions (resume + history) ────────────────────────────────────

  static Future<int> getSavedPosition(String fileId) async {
    final db = await instance;
    final rows = await db.query('watch_positions',
        where: 'file_id = ?', whereArgs: [fileId]);
    if (rows.isEmpty) return 0;
    return rows.first['position_ms'] as int? ?? 0;
  }

  static Future<void> savePosition(
    String fileId,
    int positionMs, {
    int durationMs = 0,
    int? titleId,
    String? titleText,
    String? posterUrl,
  }) async {
    final db = await instance;
    await db.insert(
      'watch_positions',
      {
        'file_id': fileId,
        'title_id': titleId,
        'title_text': titleText,
        'poster_url': posterUrl,
        'position_ms': positionMs,
        'duration_ms': durationMs,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> clearPosition(String fileId) async {
    final db = await instance;
    await db.delete('watch_positions',
        where: 'file_id = ?', whereArgs: [fileId]);
  }

  static Future<void> clearAllPositions() async {
    final db = await instance;
    await db.delete('watch_positions');
  }

  /// Get watch history sorted by most recent, with title info joined
  static Future<List<Map<String, dynamic>>> getWatchHistory({int limit = 50}) async {
    final db = await instance;
    final rows = await db.rawQuery('''
      SELECT wp.file_id, wp.position_ms, wp.duration_ms, wp.updated_at,
             COALESCE(wp.title_text, t.title) as title,
             COALESCE(wp.poster_url, t.poster_url) as poster_url,
             wp.title_id
      FROM watch_positions wp
      LEFT JOIN titles t ON t.file_id = wp.file_id OR t.id = wp.title_id
      WHERE wp.position_ms > 0
      ORDER BY wp.updated_at DESC
      LIMIT ?
    ''', [limit]);
    return rows;
  }

  /// Get items that have been partially watched (for "Continue Watching")
  static Future<List<Map<String, dynamic>>> getContinueWatching({int limit = 10}) async {
    final db = await instance;
    final rows = await db.rawQuery('''
      SELECT wp.file_id, wp.position_ms, wp.duration_ms, wp.updated_at,
             COALESCE(wp.title_text, t.title) as title,
             COALESCE(wp.poster_url, t.poster_url) as poster_url,
             t.id as title_id, t.media_type, t.year, t.rating, t.genres, t.is_free
      FROM watch_positions wp
      LEFT JOIN titles t ON t.file_id = wp.file_id OR t.id = wp.title_id
      WHERE wp.position_ms > 0
        AND (wp.duration_ms = 0 OR wp.position_ms < wp.duration_ms * 0.95)
      ORDER BY wp.updated_at DESC
      LIMIT ?
    ''', [limit]);
    return rows;
  }

  // ── Watchlist ─────────────────────────────────────────────────────────────

  static Future<List<CatalogItem>> getWatchlist() async {
    final db = await instance;
    final rows = await db.query('watchlist', orderBy: 'added_at DESC');
    return rows.map(_watchlistRowToItem).toList();
  }

  static Future<Set<int>> getWatchlistIds() async {
    final db = await instance;
    final rows = await db.query('watchlist', columns: ['title_id']);
    return rows.map((r) => r['title_id'] as int).toSet();
  }

  static Future<void> addToWatchlist(CatalogItem item) async {
    final db = await instance;
    await db.insert(
      'watchlist',
      {
        'title_id': item.id,
        'title': item.title,
        'year': item.year,
        'media_type': item.mediaType,
        'description': item.description,
        'rating': item.rating,
        'genres': item.genres,
        'poster_url': item.posterUrl,
        'is_free': item.isFree ? 1 : 0,
        'file_id': item.fileId,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> removeFromWatchlist(int titleId) async {
    final db = await instance;
    await db.delete('watchlist', where: 'title_id = ?', whereArgs: [titleId]);
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
  }) async {
    final db = await instance;
    await db.insert(
      'downloads',
      {
        'file_id': fileId,
        'title_text': titleText,
        'poster_url': posterUrl,
        'local_path': localPath,
        'status': 'downloading',
        'progress': 0.0,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
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
        try {
          await File(path).delete();
        } catch (_) {}
      }
    }
    await db.delete('downloads', where: 'file_id = ?', whereArgs: [fileId]);
  }

  // ── Ratings ───────────────────────────────────────────────────────────────

  static Future<void> saveRating(int titleId, int rating) async {
    final db = await instance;
    await db.insert(
      'ratings',
      {
        'title_id': titleId,
        'rating': rating,
        'rated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int?> getRating(int titleId) async {
    final db = await instance;
    final rows = await db.query('ratings', where: 'title_id = ?', whereArgs: [titleId]);
    if (rows.isEmpty) return null;
    return rows.first['rating'] as int?;
  }

  // ── New Releases ──────────────────────────────────────────────────────────

  static Future<List<CatalogItem>> getNewReleases({int limit = 15}) async {
    final db = await instance;
    final rows = await db.query('titles', orderBy: 'id DESC', limit: limit);
    return rows.map(_rowToItem).toList();
  }

  // ── Search with filters ───────────────────────────────────────────────────

  static Future<List<CatalogItem>> searchFiltered({
    String? query,
    String? mediaType,
    String? genre,
    bool freeOnly = false,
    int limit = 60,
  }) async {
    final db = await instance;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (query != null && query.isNotEmpty) {
      conditions.add('title LIKE ?');
      args.add('%$query%');
    }
    if (mediaType != null) {
      conditions.add('media_type = ?');
      args.add(mediaType);
    }
    if (genre != null) {
      conditions.add('genres LIKE ?');
      args.add('%"$genre"%');
    }
    if (freeOnly) {
      conditions.add('is_free = 1');
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final rows = await db.query(
      'titles',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'rating DESC, title ASC',
      limit: limit,
    );
    return rows.map(_rowToItem).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static CatalogItem _rowToItem(Map<String, dynamic> row) {
    return CatalogItem(
      id: row['id'] as int,
      title: row['title'] as String,
      year: row['year'] as int?,
      mediaType: row['media_type'] as String,
      description: row['description'] as String?,
      rating: (row['rating'] as num?)?.toDouble(),
      genres: row['genres'] as String?,
      posterUrl: row['poster_url'] as String?,
      isFree: (row['is_free'] as int? ?? 0) == 1,
      dbVersion: row['db_version'] as int? ?? 0,
      fileId: row['file_id'] as String?,
    );
  }

  static CatalogItem _watchlistRowToItem(Map<String, dynamic> row) {
    return CatalogItem(
      id: row['title_id'] as int,
      title: row['title'] as String,
      year: row['year'] as int?,
      mediaType: row['media_type'] as String? ?? 'movie',
      description: row['description'] as String?,
      rating: (row['rating'] as num?)?.toDouble(),
      genres: row['genres'] as String?,
      posterUrl: row['poster_url'] as String?,
      isFree: (row['is_free'] as int? ?? 0) == 1,
      fileId: row['file_id'] as String?,
    );
  }
}
