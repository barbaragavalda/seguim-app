import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/pending_movies_api.dart';
import '../data/pending_series_api.dart';

/// Just the "X pendents" badge count for ProfileScreen - deliberately its
/// own provider rather than reading pendingResolutionProvider.items.length,
/// so ProfileScreen's periodic poll (see its own docblock on why it polls
/// at all) can never stomp on PendingResolutionScreen's own selections -
/// that used to be the same shared provider, and a poll firing while the
/// user had candidates ticked on the full screen wiped them out.
class PendingCountController extends Notifier<int> {
  late final PendingSeriesApi _seriesApi;
  late final PendingMoviesApi _movieApi;

  @override
  int build() {
    _seriesApi = PendingSeriesApi();
    _movieApi = PendingMoviesApi();
    return 0;
  }

  Future<void> load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      final series = await _seriesApi.list(token: token);
      final movies = await _movieApi.list(token: token);
      state = series.length + movies.length;
    } catch (_) {
      // transient network hiccup while polling - keep the last known count
      // rather than flashing it to 0
    }
  }
}

final pendingCountProvider = NotifierProvider<PendingCountController, int>(
  PendingCountController.new,
);
