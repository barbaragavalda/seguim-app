import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/pending_movies_api.dart';
import '../data/pending_series_api.dart';

/// Deliberately its own provider, not pendingResolutionProvider.items.length
/// - sharing one used to let ProfileScreen's poll wipe out ticked
/// selections on PendingResolutionScreen.
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

  /// Local decrement instead of a fresh load(), so confirmAll() resolving
  /// dozens of entries doesn't trigger a round trip per item.
  void decrement() {
    if (state > 0) state--;
  }
}

final pendingCountProvider = NotifierProvider<PendingCountController, int>(
  PendingCountController.new,
);
