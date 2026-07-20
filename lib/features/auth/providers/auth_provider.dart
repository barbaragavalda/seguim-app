import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  const AuthState({this.isLoggedIn = false});

  final bool isLoggedIn;

  AuthState copyWith({bool? isLoggedIn}) =>
      AuthState(isLoggedIn: isLoggedIn ?? this.isLoggedIn);
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  void logIn() => state = state.copyWith(isLoggedIn: true);

  void logOut() => state = state.copyWith(isLoggedIn: false);
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
