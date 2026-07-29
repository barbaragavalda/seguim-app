import 'pending_movie.dart';
import 'pending_series.dart';

enum PendingEntryKind { series, movie }

/// One row in the unified "series/movies pending resolution" screen -
/// wraps either a PendingSeries or a PendingMovie so the screen/provider can
/// treat both uniformly (one merged, chronologically-mixed list) while
/// still knowing which backend API to call for it.
class PendingEntry {
  const PendingEntry.series(this.series)
    : kind = PendingEntryKind.series,
      movie = null;

  const PendingEntry.movie(this.movie)
    : kind = PendingEntryKind.movie,
      series = null;

  final PendingEntryKind kind;
  final PendingSeries? series;
  final PendingMovie? movie;

  // ids come from two different database tables, so the same int can
  // legitimately appear for both a pending series and a pending movie -
  // this compound key is what actually identifies a row uniquely
  String get key => '${kind.name}:$_localId';

  int get _localId => kind == PendingEntryKind.series ? series!.id : movie!.id;

  String get title =>
      kind == PendingEntryKind.series ? series!.showName : movie!.movieName;

  List<PendingMovieCandidate> get candidates =>
      kind == PendingEntryKind.series ? series!.candidates : movie!.candidates;
}
