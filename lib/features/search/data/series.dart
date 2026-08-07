class Series {
  const Series({
    required this.tvdbId,
    required this.name,
    this.year,
    this.imageUrl,
    this.status,
    this.watchedEpisodes,
    this.totalEpisodes,
  });

  final String tvdbId;
  final String name;
  final String? year;
  final String? imageUrl;
  final String? status;
  // both null when never synced locally - always both set or both absent
  final int? watchedEpisodes;
  final int? totalEpisodes;

  /// Clamped in case a rewatch or a stale total ever pushed watched past
  /// total.
  double? get watchProgress {
    final total = totalEpisodes;
    final watched = watchedEpisodes;
    if (total == null || watched == null || total == 0) return null;
    return (watched / total).clamp(0.0, 1.0);
  }

  // TheTVDB returns its own generic placeholder instead of omitting
  // image_url when a series has no real artwork - treat it as no image.
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
      watchedEpisodes: (json['watched_episodes'] as num?)?.toInt(),
      totalEpisodes: (json['total_episodes'] as num?)?.toInt(),
    );
  }

  /// Maps a raw, un-enriched `serie` table row (e.g. GET /lists/{id}),
  /// where field names differ from fromJson() above: default_name/image/
  /// year_start instead of name/thumbnail/year.
  factory Series.fromListRow(Map<String, dynamic> json) {
    return Series(
      tvdbId: '${json['tvdb_id']}',
      name: json['default_name'] as String? ?? '',
      year: json['year_start'] as String?,
      imageUrl: json['image'] as String?,
      status: json['status'] as String?,
      watchedEpisodes: (json['watched_episodes'] as num?)?.toInt(),
      totalEpisodes: (json['total_episodes'] as num?)?.toInt(),
    );
  }
}
