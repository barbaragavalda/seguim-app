class MovieWatchlistItem {
  const MovieWatchlistItem({
    required this.tvdbId,
    required this.name,
    this.imageUrl,
    this.year,
    this.watched = false,
    this.watchCount = 0,
  });

  final String tvdbId;
  final String name;
  final String? imageUrl;
  final String? year;
  final bool watched;
  // how many times this movie has been watched - 0 when unwatched, 1 for a
  // plain watch, 2+ once rewatched (see MovieDetailController.rewatch());
  // user_movie_watched is one row per watch event
  final int watchCount;

  factory MovieWatchlistItem.fromJson(Map<String, dynamic> json) {
    return MovieWatchlistItem(
      tvdbId: '${json['tvdb_id']}',
      name: json['name'] as String? ?? '',
      imageUrl: json['image'] as String?,
      year: json['year'] as String?,
      watched: json['watched'] as bool? ?? false,
      watchCount: (json['watch_count'] as num?)?.toInt() ?? 0,
    );
  }
}
