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
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      year: json['year'] as int?,
      mediaType: json['media_type'] as String? ?? 'movie',
      description: json['description'] as String? ?? json['plot'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      genres: json['genres'] is String
          ? json['genres'] as String
          : json['genres']?.toString(),
      posterUrl: json['poster'] as String? ?? json['poster_url'] as String?,
      isFree: (json['is_free'] as int? ?? 0) == 1,
      dbVersion: json['db_version'] as int? ?? 0,
      episodes: episodesRaw.cast<Map<String, dynamic>>(),
      fileId: json['file_id']?.toString(),
    );
  }
}
