class PendingMovieCandidate {
  const PendingMovieCandidate({
    required this.tvdbId,
    required this.name,
    this.year,
    this.imageUrl,
  });

  final int tvdbId;
  final String name;
  final String? year;
  final String? imageUrl;

  factory PendingMovieCandidate.fromJson(Map<String, dynamic> json) {
    return PendingMovieCandidate(
      tvdbId: (json['tvdb_id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      year: json['year'] as String?,
      imageUrl: json['image'] as String?,
    );
  }
}

/// A movie title from a TV Time import that couldn't be confidently matched
/// on its own (see backend Api\Model\TvTimeImport\MovieMatcher) - up to 5
/// TheTVDB candidates are shown so the user can pick the right one, or
/// dismiss it if none are correct.
class PendingMovie {
  const PendingMovie({
    required this.id,
    required this.movieName,
    this.expectedYear,
    required this.watched,
    this.watchedAt,
    required this.candidates,
  });

  final int id;
  final String movieName;
  final String? expectedYear;
  final bool watched;
  final String? watchedAt;
  final List<PendingMovieCandidate> candidates;

  factory PendingMovie.fromJson(Map<String, dynamic> json) {
    final candidatesJson = json['candidates'] as List<dynamic>? ?? [];
    return PendingMovie(
      id: (json['id'] as num).toInt(),
      movieName: json['movie_name'] as String? ?? '',
      expectedYear: json['expected_year'] as String?,
      watched: json['watched'] as bool? ?? false,
      watchedAt: json['watched_at'] as String?,
      candidates: candidatesJson
          .map(
            (item) =>
                PendingMovieCandidate.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
