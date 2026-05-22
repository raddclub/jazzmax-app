import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/auth_api.dart';
import '../core/security/keystore.dart';
import '../models/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, AppUser? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  /// Called on app start — checks if a token exists and validates it.
  Future<void> checkAuth() async {
    final hasToken = await Keystore.hasTokens();
    if (!hasToken) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await AuthApi.getMe();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      // Token is invalid or expired — clear and send to login
      await Keystore.clearAll();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({required String phone, required String password}) async {
    state = state.copyWith(error: null);
    final result = await AuthApi.login(phone: phone, password: password);
    await Keystore.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      userId: result.userId.toString(),
    );
    final user = await AuthApi.getMe();
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> register({required String phone, required String password}) async {
    await AuthApi.register(phone: phone, password: password);
    // After registration, log in automatically
    await login(phone: phone, password: password);
  }

  Future<void> logout() async {
    await AuthApi.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void refreshUser(AppUser user) {
    state = state.copyWith(user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
