import 'package:dio/dio.dart';
import '../constants.dart';
import '../security/keystore.dart';

/// Singleton Dio HTTP client.
/// Automatically attaches Bearer token to every request.
/// On 401 → auto-refreshes access token using refresh token → retries.
/// On refresh failure → clears tokens (user must log in again).
class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;

  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(_AuthInterceptor(_dio));
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  /// Call this after RemoteConfig.fetch() to point Dio at the new server URL.
  static void updateBaseUrl(String url) {
    _instance ??= ApiClient._();
    _instance!._dio.options.baseUrl = url;
  }

  Dio get dio => _dio;

  // ── Convenience methods ───────────────────────────────────────────────────

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);
}

/// Interceptor: attaches auth header + handles 401 token refresh.
class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  _AuthInterceptor(this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Skip auth header for auth endpoints
    final noAuthPaths = [ApiPaths.login, ApiPaths.register, ApiPaths.refresh, ApiPaths.guest];
    if (noAuthPaths.contains(options.path)) {
      return handler.next(options);
    }

    final token = await Keystore.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          // Retry the original request with new token
          final newToken = await Keystore.getAccessToken();
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';
          final response = await _dio.fetch(opts);
          _isRefreshing = false;
          return handler.resolve(response);
        }
      } catch (_) {}
      _isRefreshing = false;
      // Refresh failed — clear tokens so app goes to login
      await Keystore.clearAll();
    }
    handler.next(err);
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await Keystore.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      // Use a fresh Dio instance (no interceptors) to avoid infinite loop
      final freshDio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
      final response = await freshDio.post(
        ApiPaths.refresh,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final newAccess = data['access_token'] as String?;
        final newRefresh = data['refresh_token'] as String?;
        if (newAccess != null) {
          await Keystore.saveAccessToken(newAccess);
          if (newRefresh != null && newRefresh.isNotEmpty) {
            await Keystore.saveRefreshToken(newRefresh);
          }
          return true;
        }
      }
    } catch (_) {}
    return false;
  }
}
