import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/auth_api.dart';
import '../core/security/keystore.dart';
import '../core/constants.dart';
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

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final isGuest = prefs.getBool(StorageKeys.isGuest) ?? false;

    if (isGuest) {
      final hasToken = await Keystore.hasTokens();
      if (hasToken) {
        state = AuthState(status: AuthStatus.authenticated, user: AppUser.guest());
        return;
      }
      await prefs.remove(StorageKeys.isGuest);
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    final hasToken = await Keystore.hasTokens();
    if (!hasToken) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await AuthApi.getMe();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.isGuest);
    final user = await AuthApi.getMe();
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> register({required String phone, required String password}) async {
    await AuthApi.register(phone: phone, password: password);
    await login(phone: phone, password: password);
  }

  Future<void> continueAsGuest() async {
    final token = await AuthApi.guestLogin();
    await Keystore.saveTokens(
      accessToken: token,
      refreshToken: '',
      userId: '0',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.isGuest, true);
    state = AuthState(status: AuthStatus.authenticated, user: AppUser.guest());
  }

  Future<void> logout() async {
    try { await AuthApi.logout(); } catch (_) {}
    await Keystore.clearAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.isGuest);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Returns the current access token (for constructing stream URLs).
  Future<String?> getAccessToken() => Keystore.getAccessToken();

  void refreshUser(AppUser user) {
    state = state.copyWith(user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
