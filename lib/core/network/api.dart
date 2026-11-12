import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/environment.dart';
import '../constants/app_constants.dart';
import '../domain/storages/global_storage.dart';
import '../streams/auth_event_bus.dart';
import '../utils/app_logger.dart';
import 'api_type.dart';
import 'exception.dart';

/// HTTP client dùng chung. Repository/datasource gọi [request] và nhận về
/// `response.data` đã decode.
///
/// - Tự gắn `Authorization: Bearer <accessToken>` nếu đã đăng nhập.
/// - Tự gắn `Scope: strongbody-ai`, `locale` + `Accept-Language` (web `apiFetch`) nếu caller chưa set.
/// - Lỗi không có response → [NetworkException]; lỗi HTTP → rethrow [DioException]
///   để repository tự lấy `message` từ body.
/// - `path` tuyệt đối (`https://...`) thì Dio bỏ qua baseUrl — dùng cho API route của web.
/// - Access token (JWT) đã hết hạn → refresh TRƯỚC khi gửi (web next-auth `jwt` callback:
///   `Date.now() >= accessTokenExpires` → `refreshAccessToken`).
/// - 401 (HTTP hoặc body `code` 401/403) khi đã đăng nhập → refresh 1 lần (`GET /auth/refresh-token`,
///   Bearer refreshToken, như web `refreshAccessToken`) rồi gửi lại; BE từ chối refresh → xoá phiên
///   + [UserLoggedOut] `expired` (web `RefreshTokenGuard` → đăng xuất, mở trang đăng nhập).
class ApiClient {
  final Dio _dio;
  final GlobalStorage _storage;

  /// Dio riêng cho refresh — không qua interceptor (tránh vòng lặp 401).
  final Dio _refreshDio;
  Future<String?>? _refreshing;

  static const _refreshPath = '/auth/refresh-token';

  /// Logout chủ động: BE từ chối token lúc này không phải "hết phiên" (không mở lại đăng nhập).
  static const _logoutPath = '/auth/logout';

  /// Refresh sớm hơn `exp` một chút để token không hết hạn giữa đường.
  static const expirySkew = Duration(seconds: 10);

  ApiClient(this._dio, this._storage, {Dio? refreshDio})
    : _refreshDio =
          refreshDio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ),
          ) {
    _dio.options
      ..baseUrl = AppConfig.baseUrl
      ..connectTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 30)
      ..sendTimeout = const Duration(seconds: 30);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skip_auth'] != true &&
              options.headers['Authorization'] == null) {
            var token = _storage.accessToken;
            if (token != null &&
                token.isNotEmpty &&
                (_storage.refreshToken?.isNotEmpty ?? false) &&
                isTokenExpired(token, DateTime.now())) {
              // Đã thử refresh cho request này → 401 sau đó không refresh lần nữa.
              options.extra['auth_retried'] = true;
              token = await _refreshOnce(options.path) ?? _storage.accessToken;
            }
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          final locale = _storage.locale;
          options.headers
            ..putIfAbsent('Scope', () => AppConstants.strongbodyAi)
            ..putIfAbsent('locale', () => locale)
            ..putIfAbsent('Accept-Language', () => locale);
          handler.next(options);
        },
        // BE trả HTTP 200 kèm `code` 401/403 khi token hết hạn → đổi thành lỗi 401
        // để refresh như lỗi HTTP (giống Multime `api.dart`).
        onResponse: (response, handler) {
          final body = response.data;
          final code = body is Map ? body['code'] : null;
          if ((code == 401 || code == 403) &&
              response.requestOptions.extra['skip_auth'] != true) {
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: Response(
                  requestOptions: response.requestOptions,
                  statusCode: 401,
                  data: body,
                ),
                type: DioExceptionType.badResponse,
              ),
              true,
            );
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          final options = error.requestOptions;
          final canRefresh =
              error.response?.statusCode == 401 &&
              options.extra['skip_auth'] != true &&
              options.extra['auth_retried'] != true &&
              (_storage.refreshToken?.isNotEmpty ?? false);
          if (!canRefresh) return handler.next(error);
          // Request khác đã refresh xong trong lúc request này bay → dùng luôn token mới,
          // không refresh lần nữa (refresh token có thể đã bị xoay vòng).
          final sent = options.headers['Authorization'];
          final current = _storage.accessToken;
          final token =
              (current != null &&
                  current.isNotEmpty &&
                  sent != 'Bearer $current')
              ? current
              : await _refreshOnce(options.path);
          if (token == null) return handler.next(error);
          try {
            options
              ..extra['auth_retried'] = true
              ..headers['Authorization'] = 'Bearer $token';
            // FormData chỉ gửi được một lần (Dio: "already been finalized").
            if (options.data case final FormData form) {
              options.data = form.clone();
            }
            handler.resolve(await _dio.fetch(options));
          } on DioException catch (e) {
            handler.next(e);
          }
        },
      ),
    );

    if (AppConfig.isDev) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (log) => AppLogger.d(log),
        ),
      );
    }
  }

  /// `exp` (giây) trong payload JWT → thời điểm hết hạn. Không phải JWT / không có `exp` → null.
  @visibleForTesting
  static DateTime? tokenExpiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload is Map ? payload['exp'] : null;
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch((exp * 1000).toInt());
    } catch (_) {
      return null;
    }
  }

  /// Token đã (sắp) hết hạn. Không đọc được `exp` → coi là còn hạn (để 401 quyết định).
  @visibleForTesting
  static bool isTokenExpired(String token, DateTime now) {
    final expiry = tokenExpiry(token);
    return expiry != null && !now.add(expirySkew).isBefore(expiry);
  }

  /// Body của `GET /auth/refresh-token` → access token mới. Như web: chỉ nhận khi
  /// `code === 0` (`data.data?.accessToken ?? data.accessToken`), còn lại là bị từ chối.
  @visibleForTesting
  static ({String accessToken, String? refreshToken})? parseRefreshResponse(
    dynamic body,
  ) {
    if (body is! Map || '${body['code']}' != '0') return null;
    final data = body['data'] is Map ? body['data'] as Map : const {};
    final token = (data['accessToken'] ?? body['accessToken'])?.toString();
    if (token == null || token.isEmpty) return null;
    final refresh = (data['refreshToken'] ?? body['refreshToken'])?.toString();
    return (accessToken: token, refreshToken: refresh);
  }

  /// Mọi request 401 cùng lúc chờ chung một lần refresh.
  Future<String?> _refreshOnce(String triggerPath) => _refreshing ??=
      _refreshAccessToken(triggerPath).whenComplete(() => _refreshing = null);

  Future<String?> _refreshAccessToken(String triggerPath) async {
    try {
      final response = await _refreshDio.get(
        '${AppConfig.baseUrl}$_refreshPath',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_storage.refreshToken}',
            'Scope': AppConstants.strongbodyAi,
          },
        ),
      );
      final result = parseRefreshResponse(response.data);
      if (result == null) throw Exception('Refresh token failed');
      await _storage.saveAccessToken(
        result.accessToken,
        refreshToken: result.refreshToken,
      );
      return result.accessToken;
    } on DioException catch (e) {
      // Mạng yếu / timeout / 5xx: giữ phiên, chỉ request này lỗi. Chỉ đăng xuất khi BE
      // từ chối chính refresh token.
      final status = e.response?.statusCode;
      // 4xx (401/403/400 token sai…) = BE từ chối refresh token (web: `!res.ok` → đăng xuất).
      if (status != null && status >= 400 && status < 500) {
        return _signOut(e, triggerPath);
      }
      AppLogger.w('Refresh token failed (kept session)', e);
      return null;
    } catch (e) {
      return _signOut(e, triggerPath);
    }
  }

  Future<String?> _signOut(Object reason, String triggerPath) async {
    AppLogger.w('Refresh token rejected — signing out', reason);
    if (!_storage.isLoggedIn) return null;
    await _storage.clearUser();
    AuthEventBus.emit(
      UserLoggedOut(expired: !triggerPath.endsWith(_logoutPath)),
    );
    return null;
  }

  Future<dynamic> request({
    required String path,
    required ApiType method,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,

    /// Ghi đè timeout gửi/nhận (vd upload ghi âm, AI soạn request).
    Duration? timeout,

    /// Không gắn Bearer token (API `/public/*` dùng `X-API-KEY`, gắn token bị 403).
    bool skipAuth = false,

    /// `ResponseType.stream` → trả `ResponseBody` để đọc dần (server-sent events).
    ResponseType? responseType,
  }) async {
    try {
      final response = await _dio.request(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          method: method.name.toUpperCase(),
          headers: headers,
          sendTimeout: timeout,
          receiveTimeout: timeout,
          responseType: responseType,
          extra: {'skip_auth': skipAuth},
        ),
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response == null) {
        throw NetworkException(
          e.message ?? 'Network error',
          statusCode: e.response?.statusCode,
        );
      }
      rethrow;
    }
  }
}
