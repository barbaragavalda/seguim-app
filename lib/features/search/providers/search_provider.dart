import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/series.dart';
import '../data/series_api.dart';

class SearchState {
  const SearchState({
    this.query = '',
    this.isLoading = false,
    this.results = const [],
    this.errorKey,
  });

  final String query;
  final bool isLoading;
  final List<Series> results;
  final String? errorKey;

  SearchState copyWith({
    String? query,
    bool? isLoading,
    List<Series>? results,
    String? errorKey,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      results: results ?? this.results,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

class SearchController extends Notifier<SearchState> {
  static const _debounceDuration = Duration(milliseconds: 400);

  late final SeriesApi _api;
  Timer? _debounce;

  @override
  SearchState build() {
    _api = SeriesApi();
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void onQueryChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    state = state.copyWith(
      query: query,
      clearError: true,
      isLoading: trimmed.isNotEmpty,
    );
    if (trimmed.isEmpty) {
      state = state.copyWith(results: const [], isLoading: false);
      return;
    }
    _debounce = Timer(_debounceDuration, () => _search(trimmed));
  }

  Future<void> _search(String query) async {
    try {
      final results = await _api.search(query);
      state = state.copyWith(results: results, isLoading: false);
    } on SeriesSearchException catch (e) {
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
    }
  }
}

final searchProvider = NotifierProvider<SearchController, SearchState>(
  SearchController.new,
);
