class Series {
  const Series({
    required this.tvdbId,
    required this.name,
    this.year,
    this.imageUrl,
    this.status,
  });

  final String tvdbId;
  final String name;
  final String? year;
  final String? imageUrl;
  final String? status;

  // TheTVDB returns its own generic placeholder here instead of omitting
  // image_url when a series has no real artwork - treat it the same as no
  // image at all so our own placeholder shows instead of TVDB's.
  static const _missingImagePath = '/images/missing/series.jpg';

  factory Series.fromJson(Map<String, dynamic> json) {
    final rawImageUrl =
        (json['thumbnail'] as String?) ?? (json['image_url'] as String?);
    return Series(
      tvdbId: json['tvdb_id'] as String,
      name: json['name'] as String? ?? '',
      year: json['year'] as String?,
      imageUrl: (rawImageUrl != null && rawImageUrl.endsWith(_missingImagePath))
          ? null
          : rawImageUrl,
      status: json['status'] as String?,
    );
  }

  /// Maps a raw `serie` table row instead - GET /lists/{id} (Api\Controller\
  /// Lists\Show) returns `SELECT s.*` un-enriched (no per-language
  /// translation, no next_episode/remaining_episodes like Watchlist's own
  /// finalizeRows() adds), so the field names differ from fromJson() above:
  /// default_name/image/year_start instead of name/thumbnail/year.
  factory Series.fromListRow(Map<String, dynamic> json) {
    return Series(
      tvdbId: '${json['tvdb_id']}',
      name: json['default_name'] as String? ?? '',
      year: json['year_start'] as String?,
      imageUrl: json['image'] as String?,
      status: json['status'] as String?,
    );
  }
}
