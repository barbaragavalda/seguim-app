import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../search/data/series.dart';
import '../data/lists_api.dart';

class ListDetailState {
  const ListDetailState({
    this.isLoading = true,
    this.isLoadingMore = false,
    this.name = '',
    this.items = const [],
    this.hasMore = false,
    this.page = 0,
    this.errorKey,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final String name;
  final List<Series> items;
  final bool hasMore;
  final int page;
  final String? errorKey;

  ListDetailState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? name,
    List<Series>? items,
    bool? hasMore,
    int? page,
    String? errorKey,
    bool clearError = false,
  }) {
    return ListDetailState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      name: name ?? this.name,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

/// Same "no FamilyNotifier in Riverpod 3.3.2" shape as SeriesDetailController/
/// MySeriesController - a plain Notifier with an explicit load(id) rather
/// than a family provider.
class ListDetailController extends Notifier<ListDetailState> {
  late final ListsApi _api;
  int? _listId;

  @override
  ListDetailState build() {
    _api = ListsApi();
    return const ListDetailState();
  }

  Future<void> load(int listId, String name) async {
    _listId = listId;
    final token = ref.read(authProvider).token;
    if (token == null) return;
    state = ListDetailState(isLoading: true, name: name);
    try {
      final result = await _api.getListSeries(listId, token: token);
      if (_listId != listId) return;
      state = ListDetailState(
        isLoading: false,
        name: name,
        items: result.items,
        hasMore: result.hasMore,
      );
    } on ListsException catch (e) {
      if (_listId != listId) return;
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } catch (_) {
      if (_listId != listId) return;
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
    }
  }

  Future<void> loadMore() async {
    final listId = _listId;
    if (listId == null || state.isLoadingMore || state.isLoading || !state.hasMore) {
      return;
    }
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _api.getListSeries(listId, page: nextPage, token: token);
      if (_listId != listId) return;
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false,
        hasMore: result.hasMore,
        page: nextPage,
      );
    } catch (_) {
      if (_listId != listId) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Returns null on success, or an error message to show inline. Renaming
  /// from here (rather than the lists tab) doesn't update ListsController's
  /// own copy - see AppShell's Llistes-tab-switch reload, same pattern as
  /// WatchlistScreen's watchlist-tab-switch refresh.
  Future<String?> renameList(String name) async {
    final listId = _listId;
    final token = ref.read(authProvider).token;
    if (listId == null || token == null) return 'unknown_error';
    try {
      final saved = await _api.renameList(listId, name, token: token);
      state = state.copyWith(name: saved);
      return null;
    } on ListsException catch (e) {
      return e.message;
    } catch (_) {
      return 'unknown_error';
    }
  }

  Future<void> addSerie(Series series) async {
    final listId = _listId;
    final token = ref.read(authProvider).token;
    if (listId == null || token == null) return;
    if (state.items.any((s) => s.tvdbId == series.tvdbId)) return;
    state = state.copyWith(items: [...state.items, series]);
    try {
      await _api.addSerie(listId, series.tvdbId, token: token);
    } catch (_) {
      state = state.copyWith(
        items: state.items.where((s) => s.tvdbId != series.tvdbId).toList(),
      );
    }
  }

  Future<void> removeSerie(String tvdbId) async {
    final listId = _listId;
    final token = ref.read(authProvider).token;
    if (listId == null || token == null) return;
    final previous = state.items;
    state = state.copyWith(
      items: state.items.where((s) => s.tvdbId != tvdbId).toList(),
    );
    try {
      await _api.removeSerie(listId, tvdbId, token: token);
    } catch (_) {
      state = state.copyWith(items: previous);
    }
  }

  Future<void> reorderSerie(String tvdbId, {String? afterTvdbId}) async {
    final listId = _listId;
    final token = ref.read(authProvider).token;
    if (listId == null || token == null) return;
    final previous = state.items;
    state = state.copyWith(items: _moved(state.items, tvdbId, afterTvdbId));
    try {
      await _api.reorderSerie(
        listId,
        tvdbId,
        afterTvdbId: afterTvdbId,
        token: token,
      );
    } catch (_) {
      state = state.copyWith(items: previous);
    }
  }

  List<Series> _moved(List<Series> items, String tvdbId, String? afterTvdbId) {
    final result = [...items];
    final moving = result.firstWhere((s) => s.tvdbId == tvdbId);
    result.remove(moving);
    if (afterTvdbId == null) {
      result.insert(0, moving);
    } else {
      final index = result.indexWhere((s) => s.tvdbId == afterTvdbId);
      result.insert(index == -1 ? result.length : index + 1, moving);
    }
    return result;
  }
}

final listDetailProvider =
    NotifierProvider<ListDetailController, ListDetailState>(
      ListDetailController.new,
    );
