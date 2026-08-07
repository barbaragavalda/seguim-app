import '../../movie_detail/data/movie_detail.dart' show MovieGenre, MovieTrailer;

class SeriesDetail {
  const SeriesDetail({
    required this.tvdbId,
    required this.name,
    required this.slug,
    this.overview,
    this.imageUrl,
    this.backgroundUrl,
    this.yearStart,
    this.yearEnd,
    this.status,
    this.seasonCount,
    this.averageRuntime,
    this.genres = const [],
    this.trailer,
  });

  final String tvdbId;
  final String name;
  final String slug;
  final String? overview;
  final String? imageUrl;
  final String? backgroundUrl;
  final String? yearStart;
  final String? yearEnd;
  final String? status;
  final int? seasonCount;
  final int? averageRuntime;
  // MovieGenre/MovieTrailer: genres and trailers share the same shape
  // between series and movies in TheTVDB's data.
  final List<MovieGenre> genres;
  final MovieTrailer? trailer;

  // TheTVDB translation for the app's language may not exist yet - fall
  // back to a title built from the slug rather than showing a blank header
  String get displayTitle {
    if (name.isNotEmpty) return name;
    return slug
        .split('-')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  factory SeriesDetail.fromJson(Map<String, dynamic> json) {
    return SeriesDetail(
      tvdbId: '${json['tvdb_id']}',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      overview: json['overview'] as String?,
      imageUrl: json['image'] as String?,
      backgroundUrl: json['background'] as String?,
      yearStart: json['year_start'] as String?,
      yearEnd: json['year_end'] as String?,
      status: json['status'] as String?,
      seasonCount: (json['season_count'] as num?)?.toInt(),
      averageRuntime: (json['average_runtime'] as num?)?.toInt(),
      genres: (json['genres'] as List<dynamic>? ?? [])
          .map((g) => MovieGenre.fromJson(g as Map<String, dynamic>))
          .toList(),
      trailer: json['trailer'] != null
          ? MovieTrailer.fromJson(json['trailer'] as Map<String, dynamic>)
          : null,
    );
  }
}

class Episode {
  const Episode({
    required this.tvdbId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.name,
    this.overview,
    this.aired,
    this.imageUrl,
    this.runtime,
    this.watched = false,
    this.watchCount = 0,
  });

  final String tvdbId;
  final int seasonNumber;
  final int episodeNumber;
  final String? name;
  final String? overview;
  final String? aired;
  final String? imageUrl;
  final int? runtime;
  final bool watched;
  // 0 when unwatched, 1 for a plain watch, 2+ once rewatched
  final int watchCount;

  /// null or a still-future date both count as "not yet aired".
  bool get hasAired {
    if (aired == null) return false;
    final date = DateTime.tryParse(aired!);
    return date != null && !date.isAfter(DateTime.now());
  }

  Episode copyWith({bool? watched, int? watchCount}) {
    return Episode(
      tvdbId: tvdbId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      name: name,
      overview: overview,
      aired: aired,
      imageUrl: imageUrl,
      runtime: runtime,
      watched: watched ?? this.watched,
      watchCount: watchCount ?? this.watchCount,
    );
  }

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      tvdbId: '${json['tvdb_id']}',
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      overview: json['overview'] as String?,
      aired: json['aired'] as String?,
      imageUrl: json['image'] as String?,
      runtime: (json['runtime'] as num?)?.toInt(),
      watched: json['watched'] as bool? ?? false,
      watchCount: (json['watch_count'] as num?)?.toInt() ?? 0,
    );
  }
}
