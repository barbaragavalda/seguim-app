/// A movie inside a list - raw table row from `SELECT m.*`, not the
/// enriched search/detail shape. Unlike Series, has a single `year` column
/// rather than a year_start/year_end range.
class ListMovie {
  const ListMovie({
    required this.tvdbId,
    required this.name,
    this.year,
    this.imageUrl,
    this.status,
    this.watched,
  });

  final String tvdbId;
  final String name;
  final String? year;
  final String? imageUrl;
  final String? status;
  // null in a plain list row; set only when reused for the "My movies" screen
  final bool? watched;

  factory ListMovie.fromListRow(Map<String, dynamic> json) {
    return ListMovie(
      tvdbId: '${json['tvdb_id']}',
      name: json['default_name'] as String? ?? '',
      year: json['year'] as String?,
      imageUrl: json['image'] as String?,
      status: json['status'] as String?,
      watched: json['watched'] as bool?,
    );
  }
}
