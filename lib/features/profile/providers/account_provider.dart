import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/account_api.dart';

class AccountState {
  const AccountState({
    this.isLoading = true,
    this.username,
    this.email,
    this.isSaving = false,
    this.errorKey,
  });

  final bool isLoading;
  final String? username;
  final String? email;
  final bool isSaving;
  final String? errorKey;

  AccountState copyWith({
    bool? isLoading,
    String? username,
    String? email,
    bool? isSaving,
    String? errorKey,
    bool clearError = false,
  }) {
    return AccountState(
      isLoading: isLoading ?? this.isLoading,
      username: username ?? this.username,
      email: email ?? this.email,
      isSaving: isSaving ?? this.isSaving,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

class AccountController extends Notifier<AccountState> {
  late final AccountApi _api;

  @override
  AccountState build() {
    _api = AccountApi();
    return const AccountState();
  }

  Future<void> load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final info = await _api.getAccount(token: token);
      state = AccountState(
        isLoading: false,
        username: info.username,
        email: info.email,
      );
    } on AccountException catch (e) {
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
    }
  }

  /// Returns null on success, or an error message to show inline.
  Future<String?> updateUsername(String username) {
    return _save(() async {
      final token = ref.read(authProvider).token!;
      final saved = await _api.updateUsername(username, token: token);
      state = state.copyWith(username: saved);
    });
  }

  Future<String?> updateEmail(String email) {
    return _save(() async {
      final token = ref.read(authProvider).token!;
      final saved = await _api.updateEmail(email, token: token);
      state = state.copyWith(email: saved);
    });
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _save(() async {
      final token = ref.read(authProvider).token!;
      await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        token: token,
      );
    });
  }

  Future<String?> _save(Future<void> Function() action) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await action();
      state = state.copyWith(isSaving: false);
      return null;
    } on AccountException catch (e) {
      state = state.copyWith(isSaving: false);
      return e.message;
    } catch (_) {
      state = state.copyWith(isSaving: false);
      return 'unknown_error';
    }
  }

  Future<bool> deleteAccount() async {
    final token = ref.read(authProvider).token;
    if (token == null) return false;
    try {
      await _api.deleteAccount(token: token);
      await ref.read(authProvider.notifier).logOut();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final accountProvider = NotifierProvider<AccountController, AccountState>(
  AccountController.new,
);
