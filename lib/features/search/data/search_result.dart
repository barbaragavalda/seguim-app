enum SearchResultType { series, movie }

/// A row from the unified `/api/search` endpoint - mixes series and movies
/// in one ranked list. Deliberately separate from [Series], which stays
/// series-only for the "add to list" flow.
class SearchResult {
  const SearchResult({
    required this.tvdbId,
    required this.name,
    required this.type,
    this.year,
    this.imageUrl,
    this.status,
    this.watchedEpisodes,
    this.totalEpisodes,
  });

  final String tvdbId;
  final String name;
  final SearchResultType type;
  final String? year;
  final String? imageUrl;
  final String? status;
  // series only - both null unless the request carried a real user token
  // and the series is already synced locally
  final int? watchedEpisodes;
  final int? totalEpisodes;

  double? get watchProgress {
    final total = totalEpisodes;
    final watched = watchedEpisodes;
    if (total == null || watched == null || total == 0) return null;
    return (watched / total).clamp(0.0, 1.0);
  }

  // TheTVDB returns its own generic placeholder instead of omitting the
  // image when a result has no real artwork.
  static const _missingImagePath = '/images/missing/series.jpg';

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final rawImageUrl =
        (json['thumbnail'] as String?) ?? (json['image'] as String?);
    return SearchResult(
      tvdbId: json['tvdb_id'] as String,
      name: json['name'] as String? ?? '',
      type: (json['type'] as String?) == 'movie'
          ? SearchResultType.movie
          : SearchResultType.series,
      year: json['year'] as String?,
      imageUrl: (rawImageUrl != null && rawImageUrl.endsWith(_missingImagePath))
          ? null
          : rawImageUrl,
      status: json['status'] as String?,
      watchedEpisodes: (json['watched_episodes'] as num?)?.toInt(),
      totalEpisodes: (json['total_episodes'] as num?)?.toInt(),
    );
  }
}
