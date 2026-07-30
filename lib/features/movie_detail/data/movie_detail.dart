class MovieDetail {
  const MovieDetail({
    required this.tvdbId,
    required this.name,
    required this.slug,
    this.overview,
    this.imageUrl,
    this.backgroundUrl,
    this.year,
    this.releaseDate,
    this.runtime,
    this.status,
    this.genres = const [],
    this.cast = const [],
    this.contentRating,
    this.trailer,
  });

  final String tvdbId;
  final String name;
  final String slug;
  final String? overview;
  final String? imageUrl;
  final String? backgroundUrl;
  final String? year;
  // ISO 8601 (yyyy-MM-dd) - TheTVDB's own `first_release.date`, its single
  // "global" release date
  final String? releaseDate;
  final int? runtime;
  final String? status;
  final List<MovieGenre> genres;
  final List<MovieCastMember> cast;
  final MovieContentRating? contentRating;
  final MovieTrailer? trailer;

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
      releaseDate: json['release_date'] as String?,
      runtime: (json['runtime'] as num?)?.toInt(),
      status: json['status'] as String?,
      genres: (json['genres'] as List<dynamic>? ?? [])
          .map((g) => MovieGenre.fromJson(g as Map<String, dynamic>))
          .toList(),
      cast: (json['cast'] as List<dynamic>? ?? [])
          .map((c) => MovieCastMember.fromJson(c as Map<String, dynamic>))
          .toList(),
      contentRating: json['content_rating'] != null
          ? MovieContentRating.fromJson(
              json['content_rating'] as Map<String, dynamic>,
            )
          : null,
      trailer: json['trailer'] != null
          ? MovieTrailer.fromJson(json['trailer'] as Map<String, dynamic>)
          : null,
    );
  }
}

class MovieGenre {
  const MovieGenre({required this.slug, required this.name});

  final String slug;
  final String name;

  factory MovieGenre.fromJson(Map<String, dynamic> json) {
    return MovieGenre(
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class MovieCastMember {
  const MovieCastMember({
    required this.personName,
    this.characterName,
    this.imageUrl,
  });

  final String personName;
  final String? characterName;
  final String? imageUrl;

  factory MovieCastMember.fromJson(Map<String, dynamic> json) {
    return MovieCastMember(
      personName: json['person_name'] as String? ?? '',
      characterName: json['character_name'] as String?,
      imageUrl: json['image'] as String?,
    );
  }
}

class MovieContentRating {
  const MovieContentRating({required this.rating, this.description});

  final String rating;
  final String? description;

  factory MovieContentRating.fromJson(Map<String, dynamic> json) {
    return MovieContentRating(
      rating: json['rating'] as String? ?? '',
      description: json['description'] as String?,
    );
  }
}

class MovieTrailer {
  const MovieTrailer({required this.url});

  final String url;

  factory MovieTrailer.fromJson(Map<String, dynamic> json) {
    return MovieTrailer(url: json['url'] as String? ?? '');
  }
}
