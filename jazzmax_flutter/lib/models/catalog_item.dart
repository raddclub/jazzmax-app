class CatalogItem {
  final int id;
  final String title;
  final int? year;
  final String mediaType; // 'movie' or 'show'
  final String? description;
  final double? rating;
  final String? genres; // JSON string
  final String? posterUrl;
  final bool isFree;
  final int dbVersion;
  final List<Map<String, dynamic>> episodes;

  // For movies — the direct file_id for playback
  final String? fileId;

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
  });

  bool get isMovie => mediaType == 'movie';
  bool get isShow => mediaType == 'show';

  String get displayYear => year != null ? year.toString() : '';
  String get displayRating =>
      rating != null ? rating!.toStringAsFixed(1) : '';

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    final episodesRaw = json['episodes'] as List<dynamic>? ?? [];

    return CatalogItem(
      // id may come as int or string from server
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title'] as String? ?? '',
      // year comes as String from server ("2023") — parse safely
      year: json['year'] is int
          ? json['year'] as int
          : int.tryParse((json['year'] as String?) ?? ''),
      mediaType: json['media_type'] as String? ?? 'movie',
      description: json['description'] as String? ?? json['plot'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      // genres comes as List from server — convert to comma-separated string
      genres: json['genres'] is String
          ? json['genres'] as String
          : json['genres'] is List
              ? (json['genres'] as List).join(', ')
              : json['genres']?.toString(),
      posterUrl: json['poster'] as String? ?? json['poster_url'] as String?,
      // Server returns Python bool (true/false) or int (1/0) — handle both
      isFree: json['is_free'] == true || json['is_free'] == 1,
      // db_version may be int or string
      dbVersion: json['db_version'] is int
          ? json['db_version'] as int
          : int.tryParse(json['db_version']?.toString() ?? '') ?? 0,
      episodes: episodesRaw.cast<Map<String, dynamic>>(),
      fileId: json['file_id']?.toString(),
    );
  }
}
