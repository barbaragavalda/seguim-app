/// A movie inside a list - same "raw table row, not the enriched search/
/// detail shape" reasoning as Series.fromListRow (GET /lists/{id} returns
/// `SELECT m.*` un-enriched), except movie has its own single `year` column
/// rather than series' year_start/year_end range, so no separate mapping
/// quirk to note there.
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
  // null in a plain list row (being in a list has nothing to do with
  // watch status) - only ever set when this same model is reused for the
  // "My movies" screen (Api\Model\MovieWatchlist::finalizeRows()), which
  // does carry a watched flag
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
