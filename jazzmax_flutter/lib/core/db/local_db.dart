import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/catalog_item.dart';

/// Shared local SQLite database for:
/// - Catalog (titles + episodes)
/// - Watch history / resume positions
/// - Download metadata
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
      version: 3,
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
        db_version  INTEGER DEFAULT 0
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

  // ── Watch Positions (resume) ───────────────────────────────────────────────

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
        'file_id': fileId,
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
    // Delete local file too
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
    );
  }
}
