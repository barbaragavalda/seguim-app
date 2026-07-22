import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/auth_api.dart';

class AuthState {
  const AuthState({this.token, this.isLoading = false, this.errorKey});

  final String? token;
  final bool isLoading;
  final String? errorKey;

  bool get isLoggedIn => token != null;

  AuthState copyWith({
    String? token,
    bool? isLoading,
    String? errorKey,
    bool clearToken = false,
    bool clearError = false,
  }) {
    return AuthState(
      token: clearToken ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

class AuthController extends Notifier<AuthState> {
  static const _tokenStorageKey = 'auth_token';
  static const _storage = FlutterSecureStorage();

  late final AuthApi _api;

  @override
  AuthState build() {
    _api = AuthApi();
    _restoreSession();
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    final token = await _storage.read(key: _tokenStorageKey);
    if (token != null) {
      state = state.copyWith(token: token);
    }
  }

  Future<bool> logIn({required String email, required String password}) {
    return _submit(() => _api.login(email: email, password: password));
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) {
    return _submit(
      () =>
          _api.register(username: username, email: email, password: password),
    );
  }

  Future<bool> _submit(Future<String> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await action();
      await _storage.write(key: _tokenStorageKey, value: token);
      state = state.copyWith(token: token, isLoading: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorKey: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
      return false;
    }
  }

  Future<void> logOut() async {
    final token = state.token;
    state = state.copyWith(clearToken: true);
    await _storage.delete(key: _tokenStorageKey);
    if (token != null) {
      try {
        await _api.logout(token);
      } catch (_) {
        // Best-effort server-side revoke; the local session is already gone.
      }
    }
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
