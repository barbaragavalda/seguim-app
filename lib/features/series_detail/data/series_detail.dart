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

  Episode copyWith({bool? watched}) {
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
    );
  }
}
