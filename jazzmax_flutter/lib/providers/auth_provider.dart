import 'package:dio/dio.dart';
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

  /// Check if user is logged in on app startup.
  ///
  /// LOGIN PERSISTENCE RULE (do not change):
  /// - User stays logged in as long as they have a refresh token (valid 90 days)
  /// - Access tokens expire every 15 min but are refreshed automatically
  /// - Network errors, server down, timeouts → user stays logged in (offline mode)
  /// - ONLY log out on explicit 401/403 auth rejection from server
  /// - This means users can go months without needing to log in again
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

    // Check for refresh token — this is the real "stay logged in" credential.
    // If refresh token exists, the user logged in before and should stay logged in.
    final hasRefresh = await Keystore.hasRefreshToken();
    if (!hasRefresh) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    // Try to get fresh user data from server
    try {
      final user = await AuthApi.getMe();
      // Cache user data locally for offline startup
      await _cacheUserLocally(user, prefs);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      // Only log out if the server explicitly rejected the credentials (401 or 403).
      // Any other error (network down, timeout, server error) → stay logged in.
      final isAuthRejected = e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403);

      if (isAuthRejected) {
        await Keystore.clearAll();
        await _clearCachedUser(prefs);
        state = state.copyWith(status: AuthStatus.unauthenticated);
      } else {
        // Server unreachable — restore from cached user data
        // User can still browse the local catalog offline
        final offlineUser = await _restoreCachedUser(prefs);
        state = AuthState(status: AuthStatus.authenticated, user: offlineUser);
      }
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
    await _cacheUserLocally(user, prefs);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.isGuest);
    await _clearCachedUser(prefs);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void refreshUser(AppUser user) {
    state = state.copyWith(user: user);
  }

  // ── Local user cache (for offline startup) ────────────────────────────────

  Future<void> _cacheUserLocally(AppUser user, SharedPreferences prefs) async {
    await prefs.setString(StorageKeys.cachedUserPhone, user.phone);
    await prefs.setInt(StorageKeys.cachedUserId, user.id);
    await prefs.setString(StorageKeys.cachedUserPlan, user.planName);
  }

  Future<AppUser> _restoreCachedUser(SharedPreferences prefs) async {
    final phone = prefs.getString(StorageKeys.cachedUserPhone) ?? '';
    final id = prefs.getInt(StorageKeys.cachedUserId) ?? 0;
    final plan = prefs.getString(StorageKeys.cachedUserPlan) ?? 'free';
    return AppUser.offline(id: id, phone: phone, plan: plan);
  }

  Future<void> _clearCachedUser(SharedPreferences prefs) async {
    await prefs.remove(StorageKeys.cachedUserPhone);
    await prefs.remove(StorageKeys.cachedUserId);
    await prefs.remove(StorageKeys.cachedUserPlan);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
