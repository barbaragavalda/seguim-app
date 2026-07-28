import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/list_membership.dart';
import '../data/lists_api.dart';

class ListMembershipState {
  const ListMembershipState({
    this.isLoading = true,
    this.items = const [],
    this.errorKey,
  });

  final bool isLoading;
  final List<ListMembership> items;
  final String? errorKey;

  ListMembershipState copyWith({
    bool? isLoading,
    List<ListMembership>? items,
    String? errorKey,
    bool clearError = false,
  }) {
    return ListMembershipState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

/// Backs the "add to a list" picker on the series detail screen - same
/// "no FamilyNotifier in Riverpod 3.3.2" shape as ListDetailController,
/// with an explicit load(tvdbId) instead of a family provider.
class ListMembershipController extends Notifier<ListMembershipState> {
  late final ListsApi _api;
  String? _tvdbId;

  @override
  ListMembershipState build() {
    _api = ListsApi();
    return const ListMembershipState();
  }

  Future<void> load(String tvdbId) async {
    _tvdbId = tvdbId;
    final token = ref.read(authProvider).token;
    if (token == null) return;
    state = const ListMembershipState(isLoading: true);
    try {
      final items = await _api.getMembership(tvdbId, token: token);
      if (_tvdbId != tvdbId) return;
      state = ListMembershipState(isLoading: false, items: items);
    } on ListsException catch (e) {
      if (_tvdbId != tvdbId) return;
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } catch (_) {
      if (_tvdbId != tvdbId) return;
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
    }
  }

  Future<void> toggle(ListMembership item) async {
    final tvdbId = _tvdbId;
    final token = ref.read(authProvider).token;
    if (tvdbId == null || token == null) return;
    final addingIt = !item.inList;
    state = state.copyWith(
      items: [
        for (final i in state.items)
          if (i.id == item.id) i.copyWith(inList: addingIt) else i,
      ],
    );
    try {
      if (addingIt) {
        await _api.addSerie(item.id, tvdbId, token: token);
      } else {
        await _api.removeSerie(item.id, tvdbId, token: token);
      }
    } catch (_) {
      state = state.copyWith(
        items: [
          for (final i in state.items)
            if (i.id == item.id) i.copyWith(inList: !addingIt) else i,
        ],
      );
    }
  }

  /// Creates a new list and immediately adds the current series to it -
  /// returns null on success (state already reflects the new list, added),
  /// or an error message to show inline.
  Future<String?> createAndAdd(String name) async {
    final tvdbId = _tvdbId;
    final token = ref.read(authProvider).token;
    if (tvdbId == null || token == null) return 'unknown_error';
    try {
      final id = await _api.createList(name, token: token);
      await _api.addSerie(id, tvdbId, token: token);
      state = state.copyWith(
        items: [...state.items, ListMembership(id: id, name: name, inList: true)],
      );
      return null;
    } on ListsException catch (e) {
      return e.message;
    } catch (_) {
      return 'unknown_error';
    }
  }
}

final listMembershipProvider =
    NotifierProvider<ListMembershipController, ListMembershipState>(
      ListMembershipController.new,
    );
