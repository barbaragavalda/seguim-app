enum SearchResultType { series, movie }

/// A row from the unified `/api/search` endpoint - mixes series and movies
/// in one ranked list, each carrying its own [type] so the UI can route to
/// the right detail screen without a second lookup. Deliberately separate
/// from [Series] (lists/data/series.dart isn't touched by this) - that
/// model stays series-only, used by the still-series-only "add to list"
/// flow.
class SearchResult {
  const SearchResult({
    required this.tvdbId,
    required this.name,
    required this.type,
    this.year,
    this.imageUrl,
    this.status,
  });

  final String tvdbId;
  final String name;
  final SearchResultType type;
  final String? year;
  final String? imageUrl;
  final String? status;

  // TheTVDB returns its own generic placeholder here instead of omitting
  // an image when a result has no real artwork - same convention as
  // Series.fromJson's own _missingImagePath check.
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
    );
  }
}
