import 'dart:convert';

class CatalogItem {
  final int id;
  final String title;
  final int? year;
  final String mediaType; // 'movie' or 'show'
  final String? description;
  final double? rating;
  final String? genres; // JSON string e.g. '["Drama","History"]'
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

    // isFree: server may return bool (true/false) or int (1/0)
    final isFreeRaw = json['is_free'];
    final isFree = isFreeRaw == true ||
        isFreeRaw == 1 ||
        (isFreeRaw is int && isFreeRaw != 0);

    // year: server may return String '2023' or int 2023
    int? year;
    final yearRaw = json['year'];
    if (yearRaw is int) {
      year = yearRaw;
    } else if (yearRaw != null) {
      year = int.tryParse(yearRaw.toString());
    }

    // genres: server may return List ['Drama','History'] or JSON string
    String? genres;
    final genresRaw = json['genres'];
    if (genresRaw is List) {
      genres = jsonEncode(genresRaw);
    } else if (genresRaw is String && genresRaw.isNotEmpty) {
      genres = genresRaw;
    }

    // posterUrl: server returns 'poster_url' from sync, 'poster' from watch api
    final posterUrl = json['poster_url'] as String? ??
        json['poster'] as String?;

    // fileId: server returns 'file_id' for movies
    final fileId = json['file_id']?.toString();

    return CatalogItem(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      year: year,
      mediaType: json['media_type'] as String? ?? 'movie',
      description: json['description'] as String? ??
          json['plot'] as String? ??
          json['overview'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      genres: genres,
      posterUrl: (posterUrl != null && posterUrl.isNotEmpty) ? posterUrl : null,
      isFree: isFree,
      dbVersion: json['db_version'] as int? ?? 0,
      episodes: episodesRaw.cast<Map<String, dynamic>>(),
      fileId: fileId,
    );
  }
}
