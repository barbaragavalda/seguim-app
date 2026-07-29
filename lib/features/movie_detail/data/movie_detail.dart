class MovieDetail {
  const MovieDetail({
    required this.tvdbId,
    required this.name,
    required this.slug,
    this.overview,
    this.imageUrl,
    this.backgroundUrl,
    this.year,
    this.runtime,
    this.status,
  });

  final String tvdbId;
  final String name;
  final String slug;
  final String? overview;
  final String? imageUrl;
  final String? backgroundUrl;
  final String? year;
  final int? runtime;
  final String? status;

  // TheTVDB translation for the app's language may not exist yet - fall
  // back to a title built from the slug rather than showing a blank header,
  // same as SeriesDetail.displayTitle
  String get displayTitle {
    if (name.isNotEmpty) return name;
    return slug
        .split('-')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  factory MovieDetail.fromJson(Map<String, dynamic> json) {
    return MovieDetail(
      tvdbId: '${json['tvdb_id']}',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      overview: json['overview'] as String?,
      imageUrl: json['image'] as String?,
      backgroundUrl: json['background'] as String?,
      year: json['year'] as String?,
      runtime: (json['runtime'] as num?)?.toInt(),
      status: json['status'] as String?,
    );
  }
}
