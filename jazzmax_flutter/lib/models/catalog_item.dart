// Safely parse a bool/int/null value from JSON (handles Python bool → JSON true/false).
bool _parseBool(dynamic val) {
  if (val == null) return false;
  if (val is bool) return val;
  if (val is int) return val == 1;
  return false;
}

class CatalogItem {
  final int id;
  final String title;
  final int? year;
  final String mediaType;
  final String? description;
  final double? rating;
  final String? genres;
  final String? posterUrl;
  final bool isFree;
  final int dbVersion;
  final List<Map<String, dynamic>> episodes;
  final String? fileId;
  // New fields
  final String? language;
  final bool? isNew;
  final double? watchProgress; // 0.0 - 1.0
  final bool? isUploading;    // admin: currently being uploaded to JazzDrive
  final String? status;       // 'released' | 'ongoing' | 'completed' | 'cancelled'
  final bool? isOngoing;      // convenience flag synced with status=='ongoing'

  const CatalogItem({
    required this.id,
    required this.title,
    this.year,
    required this.mediaType,
    this.description,
    this.rating,
    this.genres,
    this.posterUrl,
    this.isFree = false,
    this.dbVersion = 0,
    this.episodes = const [],
    this.fileId,
    this.language,
    this.isNew,
    this.watchProgress,
    this.isUploading,
    this.status,
    this.isOngoing,
  });

  bool get isMovie      => mediaType == 'movie';
  bool get isShow       => mediaType == 'show' || mediaType == 'series' || mediaType == 'tv';
  bool get isOngoingNow => isOngoing == true || status == 'ongoing';
  bool get isCompleted  => status == 'completed';
  String get statusLabel {
    switch (status) {
      case 'ongoing':   return 'ONGOING';
      case 'completed': return 'COMPLETED';
      case 'cancelled': return 'CANCELLED';
      default:          return '';
    }
  }

  String get displayYear   => year != null ? year.toString() : '';
  String get displayRating => rating != null ? rating!.toStringAsFixed(1) : '';

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    final episodesRaw = json['episodes'] as List<dynamic>? ?? [];
    return CatalogItem(
      id:          json['id'] as int,
      title:       json['title'] as String? ?? '',
      year:        json['year'] as int?,
      mediaType:   json['media_type'] as String? ?? 'movie',
      description: json['description'] as String? ?? json['plot'] as String?,
      rating:      (json['rating'] as num?)?.toDouble(),
      genres:      json['genres'] is String
          ? json['genres'] as String
          : json['genres']?.toString(),
      posterUrl:   json['poster'] as String? ?? json['poster_url'] as String?,
      isFree:      _parseBool(json['is_free']),
      dbVersion:   json['db_version'] as int? ?? 0,
      episodes:    episodesRaw.cast<Map<String, dynamic>>(),
      fileId:      json['file_id']?.toString(),
      language:    json['language'] as String?,
      isNew:       json['is_new'] as bool?,
      watchProgress: (json['watch_progress'] as num?)?.toDouble(),
      isUploading: json['is_uploading'] as bool?,
      status:      json['status'] as String?,
      isOngoing:   (json['is_ongoing'] == 1 || json['is_ongoing'] == true || json['status'] == 'ongoing'),
    );
  }

  CatalogItem copyWith({double? watchProgress, bool? isUploading, String? status, bool? isOngoing}) => CatalogItem(
    id: id, title: title, year: year, mediaType: mediaType,
    description: description, rating: rating, genres: genres,
    posterUrl: posterUrl, isFree: isFree, dbVersion: dbVersion,
    episodes: episodes, fileId: fileId, language: language, isNew: isNew,
    watchProgress: watchProgress ?? this.watchProgress,
    isUploading: isUploading ?? this.isUploading,
    status: status ?? this.status,
    isOngoing: isOngoing ?? this.isOngoing,
  );

  /// Returns a new CatalogItem with episodes replaced (used by CatalogNotifier).
  CatalogItem copyWithEpisodes(List<Map<String, dynamic>> eps) => CatalogItem(
    id: id, title: title, year: year, mediaType: mediaType,
    description: description, rating: rating, genres: genres,
    posterUrl: posterUrl, isFree: isFree, dbVersion: dbVersion,
    episodes: eps, fileId: fileId, language: language, isNew: isNew,
    watchProgress: watchProgress,
    isUploading: isUploading,
    status: status,
    isOngoing: isOngoing,
  );
}
