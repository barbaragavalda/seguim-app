import 'pending_movie.dart' show PendingMovieCandidate;

/// A show whose tv_show_id no longer resolves on TheTVDB; up to 5
/// candidates let the user pick or dismiss. Reuses PendingMovieCandidate
/// since the candidate shape is identical for both.
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
