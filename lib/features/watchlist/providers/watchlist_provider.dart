import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/watchlist_api.dart';
import '../data/watchlist_item.dart';

class WatchlistState {
  const WatchlistState({
    this.isLoading = true,
    this.watching = const [],
    this.notStarted = const [],
    this.notStartedPage = 0,
    this.notStartedHasMore = false,
    this.isLoadingMore = false,
    this.errorKey,
  });

  final bool isLoading;
  final List<WatchlistItem> watching;
  final List<WatchlistItem> notStarted;
  final int notStartedPage;
  final bool notStartedHasMore;
  final bool isLoadingMore;
  final String? errorKey;

  WatchlistState copyWith({
    bool? isLoading,
    List<WatchlistItem>? watching,
    List<WatchlistItem>? notStarted,
    int? notStartedPage,
    bool? notStartedHasMore,
    bool? isLoadingMore,
    String? errorKey,
    bool clearError = false,
  }) {
    return WatchlistState(
      isLoading: isLoading ?? this.isLoading,
      watching: watching ?? this.watching,
      notStarted: notStarted ?? this.notStarted,
      notStartedPage: notStartedPage ?? this.notStartedPage,
      notStartedHasMore: notStartedHasMore ?? this.notStartedHasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

class WatchlistController extends Notifier<WatchlistState> {
  late final WatchlistApi _api;

  @override
  WatchlistState build() {
    _api = WatchlistApi();
    return const WatchlistState();
  }

  Future<void> load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _api.getWatching(token: token),
        _api.getNotStarted(token: token),
      ]);
      final notStartedPage = results[1] as NotStartedPage;
      state = WatchlistState(
        isLoading: false,
        watching: results[0] as List<WatchlistItem>,
        notStarted: notStartedPage.items,
        notStartedHasMore: notStartedPage.hasMore,
      );
    } on WatchlistException catch (e) {
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
    }
  }

  Future<void> loadMoreNotStarted() async {
    final token = ref.read(authProvider).token;
    if (token == null ||
        state.isLoadingMore ||
        !state.notStartedHasMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.notStartedPage + 1;
      final page = await _api.getNotStarted(token: token, page: nextPage);
      state = state.copyWith(
        notStarted: [...state.notStarted, ...page.items],
        notStartedPage: nextPage,
        notStartedHasMore: page.hasMore,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final watchlistProvider = NotifierProvider<WatchlistController, WatchlistState>(
  WatchlistController.new,
);
