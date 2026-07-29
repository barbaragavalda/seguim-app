import 'pending_movie.dart' show PendingMovieCandidate;

/// A show from a TV Time import whose tv_show_id no longer resolves on
/// TheTVDB at all (see backend Api\Model\TvTimeImport\SeriesMatcher) - up to
/// 5 TheTVDB candidates are shown so the user can pick the right one, or
/// dismiss it if none are correct. Reuses PendingMovieCandidate - the
/// candidate shape (tvdb_id/name/year/image) is identical for both.
class PendingSeries {
  const PendingSeries({
    required this.id,
    required this.showName,
    required this.episodesWatchedCount,
    required this.candidates,
  });

  final int id;
  final String showName;
  final int episodesWatchedCount;
  final List<PendingMovieCandidate> candidates;

  factory PendingSeries.fromJson(Map<String, dynamic> json) {
    final candidatesJson = json['candidates'] as List<dynamic>? ?? [];
    return PendingSeries(
      id: (json['id'] as num).toInt(),
      showName: json['show_name'] as String? ?? '',
      episodesWatchedCount:
          (json['episodes_watched_count'] as num?)?.toInt() ?? 0,
      candidates: candidatesJson
          .map(
            (item) =>
                PendingMovieCandidate.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
