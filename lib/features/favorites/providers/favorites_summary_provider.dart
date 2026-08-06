import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/favorites_api.dart';

/// Backs the two "Sèries favorites"/"Pel·lícules favorites" preview rows
/// pinned above ProfileScreen's own list-preview rows - own provider
/// rather than folding into AccountStats, same reasoning as
/// pendingCountProvider being separate from account stats: a different
/// shape of data (counts + poster previews, not a plain counter).
class FavoritesSummaryController extends Notifier<FavoritesSummary> {
  late final FavoritesApi _api;

  @override
  FavoritesSummary build() {
    _api = FavoritesApi();
    return FavoritesSummary.empty;
  }

  Future<void> load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      state = await _api.summary(token: token);
    } catch (_) {
      // transient network hiccup - keep the last known summary rather than
      // flashing it to empty, same reasoning as pendingCountProvider
    }
  }
}

final favoritesSummaryProvider =
    NotifierProvider<FavoritesSummaryController, FavoritesSummary>(
      FavoritesSummaryController.new,
    );
