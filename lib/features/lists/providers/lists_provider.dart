import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/lists_api.dart';
import '../data/user_list.dart';

class ListsState {
  const ListsState({
    this.isLoading = true,
    this.isLoadingMore = false,
    this.items = const [],
    this.hasMore = false,
    this.page = 0,
    this.errorKey,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final List<UserList> items;
  final bool hasMore;
  final int page;
  final String? errorKey;

  ListsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<UserList>? items,
    bool? hasMore,
    int? page,
    String? errorKey,
    bool clearError = false,
  }) {
    return ListsState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

class ListsController extends Notifier<ListsState> {
  late final ListsApi _api;

  @override
  ListsState build() {
    _api = ListsApi();
    return const ListsState();
  }

  Future<void> load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.getLists(token: token);
      state = ListsState(
        isLoading: false,
        items: result.items,
        hasMore: result.hasMore,
      );
    } on ListsException catch (e) {
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || !state.hasMore) return;
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _api.getLists(page: nextPage, token: token);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false,
        hasMore: result.hasMore,
        page: nextPage,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Returns null on success, or an error message to show inline.
  Future<String?> createList(String name) async {
    final token = ref.read(authProvider).token;
    if (token == null) return 'unknown_error';
    try {
      final id = await _api.createList(name, token: token);
      state = state.copyWith(items: [...state.items, UserList(id: id, name: name)]);
      return null;
    } on ListsException catch (e) {
      return e.message;
    } catch (_) {
      return 'unknown_error';
    }
  }

  Future<String?> renameList(int id, String name) async {
    final token = ref.read(authProvider).token;
    if (token == null) return 'unknown_error';
    try {
      final saved = await _api.renameList(id, name, token: token);
      state = state.copyWith(
        items: [
          for (final list in state.items)
            if (list.id == id) UserList(id: id, name: saved) else list,
        ],
      );
      return null;
    } on ListsException catch (e) {
      return e.message;
    } catch (_) {
      return 'unknown_error';
    }
  }

  Future<void> deleteList(int id) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final previous = state.items;
    state = state.copyWith(
      items: state.items.where((list) => list.id != id).toList(),
    );
    try {
      await _api.deleteList(id, token: token);
    } catch (_) {
      state = state.copyWith(items: previous);
    }
  }

  /// Moves [id] right after [afterId] (or to the front if null), both
  /// locally (so the UI reflects the drag immediately) and on the server.
  Future<void> reorder(int id, {int? afterId}) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final previous = state.items;
    state = state.copyWith(items: _moved(state.items, id, afterId));
    try {
      await _api.reorderList(id, afterId: afterId, token: token);
    } catch (_) {
      state = state.copyWith(items: previous);
    }
  }

  List<UserList> _moved(List<UserList> items, int id, int? afterId) {
    final result = [...items];
    final moving = result.firstWhere((list) => list.id == id);
    result.remove(moving);
    if (afterId == null) {
      result.insert(0, moving);
    } else {
      final index = result.indexWhere((list) => list.id == afterId);
      result.insert(index == -1 ? result.length : index + 1, moving);
    }
    return result;
  }
}

final listsProvider = NotifierProvider<ListsController, ListsState>(
  ListsController.new,
);
