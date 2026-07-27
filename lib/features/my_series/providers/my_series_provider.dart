import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../watchlist/data/watchlist_item.dart';
import '../data/my_series_api.dart';

class MySeriesState {
  const MySeriesState({
    this.status = SeriesStatus.watching,
    this.search = '',
    this.isLoading = true,
    this.isLoadingMore = false,
    this.items = const [],
    this.hasMore = false,
    this.page = 0,
    this.errorKey,
  });

  final SeriesStatus status;
  final String search;
  final bool isLoading;
  final bool isLoadingMore;
  final List<WatchlistItem> items;
  final bool hasMore;
  final int page;
  final String? errorKey;

  MySeriesState copyWith({
    SeriesStatus? status,
    String? search,
    bool? isLoading,
    bool? isLoadingMore,
    List<WatchlistItem>? items,
    bool? hasMore,
    int? page,
    String? errorKey,
    bool clearError = false,
  }) {
    return MySeriesState(
      status: status ?? this.status,
      search: search ?? this.search,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

class MySeriesController extends Notifier<MySeriesState> {
  static const _debounceDuration = Duration(milliseconds: 400);

  late final MySeriesApi _api;
  Timer? _debounce;
  int _requestId = 0;

  @override
  MySeriesState build() {
    _api = MySeriesApi();
    ref.onDispose(() => _debounce?.cancel());
    return const MySeriesState();
  }

  Future<void> load() async {
    _debounce?.cancel();
    final requestId = ++_requestId;
    final token = ref.read(authProvider).token;
    if (token == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.list(
        status: state.status,
        search: state.search.trim(),
        token: token,
      );
      if (requestId != _requestId) return;
      state = state.copyWith(
        isLoading: false,
        items: result.items,
        hasMore: result.hasMore,
        page: 0,
      );
    } on MySeriesException catch (e) {
      if (requestId != _requestId) return;
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } catch (_) {
      if (requestId != _requestId) return;
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
    }
  }

  void setStatus(SeriesStatus status) {
    if (status == state.status) return;
    _debounce?.cancel();
    state = state.copyWith(status: status);
    load();
  }

  void onSearchChanged(String search) {
    _debounce?.cancel();
    state = state.copyWith(search: search);
    _debounce = Timer(_debounceDuration, load);
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || !state.hasMore) return;

    final requestId = _requestId;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _api.list(
        status: state.status,
        search: state.search.trim(),
        page: nextPage,
        token: ref.read(authProvider).token!,
      );
      if (requestId != _requestId) return;
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false,
        hasMore: result.hasMore,
        page: nextPage,
      );
    } catch (_) {
      if (requestId != _requestId) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final mySeriesProvider = NotifierProvider<MySeriesController, MySeriesState>(
  MySeriesController.new,
);
