import 'package:dio/dio.dart';
import '../constants.dart';
import '../security/keystore.dart';
import '../debug/debug_logger.dart';

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

    _dio.interceptors.add(_LoggingInterceptor());
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

// ── Logging Interceptor ───────────────────────────────────────────────────────
/// Records every HTTP request and response to the debug log file.
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_req_start_ms'] = DateTime.now().millisecondsSinceEpoch;
    final bodyPreview = options.data != null
        ? options.data.toString().length > 200
            ? options.data.toString().substring(0, 200) + '…'
            : options.data.toString()
        : null;
    DebugLogger.logApi(
      method: options.method,
      url: '${options.baseUrl}${options.path}',
      requestBody: bodyPreview,
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final start =
        response.requestOptions.extra['_req_start_ms'] as int? ?? 0;
    final dur =
        start > 0 ? DateTime.now().millisecondsSinceEpoch - start : null;
    final rawBody = response.data?.toString() ?? '';
    DebugLogger.logApi(
      method: response.requestOptions.method,
      url:
          '${response.requestOptions.baseUrl}${response.requestOptions.path}',
      statusCode: response.statusCode,
      responsePreview: rawBody,
      durationMs: dur,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final start = err.requestOptions.extra['_req_start_ms'] as int? ?? 0;
    final dur =
        start > 0 ? DateTime.now().millisecondsSinceEpoch - start : null;
    final respBody = err.response?.data?.toString() ?? '';
    final respPreview = respBody.length > 300
        ? respBody.substring(0, 300) + '…'
        : respBody;
    DebugLogger.logApi(
      method: err.requestOptions.method,
      url:
          '${err.requestOptions.baseUrl}${err.requestOptions.path}',
      error:
          '${err.type.name}: ${err.message}  HTTP ${err.response?.statusCode}  Body: $respPreview',
      durationMs: dur,
    );
    handler.next(err);
  }
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
      DebugLogger.log('AUTH', 'Attaching Bearer token to ${options.path}');
    } else {
      DebugLogger.logWarn('AUTH', 'No access token for ${options.path}');
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      DebugLogger.logWarn('AUTH', '401 received on ${err.requestOptions.path} — attempting token refresh');
      _isRefreshing = true;
      try {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          // Retry the original request with new token
          final newToken = await Keystore.getAccessToken();
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';
          DebugLogger.log('AUTH', 'Token refreshed — retrying ${opts.path}');
          final response = await _dio.fetch(opts);
          _isRefreshing = false;
          return handler.resolve(response);
        }
      } catch (e) {
        DebugLogger.logError('AUTH', 'Token refresh threw exception', e);
      }
      _isRefreshing = false;
      DebugLogger.logError('AUTH', 'Refresh failed — clearing tokens, user must log in');
      // Refresh failed — clear tokens so app goes to login
      await Keystore.clearAll();
    }
    handler.next(err);
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await Keystore.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      DebugLogger.logWarn('AUTH', 'No refresh token available');
      return false;
    }

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
          DebugLogger.log('AUTH', 'Token refresh successful');
          return true;
        }
      }
    } catch (e) {
      DebugLogger.logError('AUTH', '_tryRefresh network error', e);
    }
    return false;
  }
}
