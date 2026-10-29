import 'package:dio/dio.dart';

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
/// - Tự gắn `Scope: strongbody-ai` nếu caller chưa set.
/// - Lỗi không có response → [NetworkException]; lỗi HTTP → rethrow [DioException]
///   để repository tự lấy `message` từ body.
/// - `path` tuyệt đối (`https://...`) thì Dio bỏ qua baseUrl — dùng cho API route của web.
/// - 401 (HTTP hoặc body `code` 401/403) khi đã đăng nhập → refresh 1 lần (`GET /auth/refresh-token`, Bearer refreshToken,
///   như web `refreshAccessToken`) rồi gửi lại; refresh hỏng → xoá phiên.
class ApiClient {
  final Dio _dio;
  final GlobalStorage _storage;

  /// Dio riêng cho refresh — không qua interceptor (tránh vòng lặp 401).
  final Dio _refreshDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  Future<String?>? _refreshing;

  static const _refreshPath = '/auth/refresh-token';

  ApiClient(this._dio, this._storage) {
    _dio.options
      ..baseUrl = AppConfig.baseUrl
      ..connectTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 30)
      ..sendTimeout = const Duration(seconds: 30);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _storage.accessToken;
          if (options.extra['skip_auth'] != true &&
              token != null &&
              token.isNotEmpty &&
              options.headers['Authorization'] == null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers.putIfAbsent('Scope', () => AppConstants.strongbodyAi);
          options.headers.putIfAbsent('locale', () => _storage.locale);
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
          final token = await (_refreshing ??= _refreshAccessToken());
          _refreshing = null;
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

  Future<String?> _refreshAccessToken() async {
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
      final body = response.data;
      final data = body is Map ? (body['data'] ?? body) : null;
      final token = data is Map ? data['accessToken']?.toString() : null;
      if (token == null || token.isEmpty) throw Exception('No access token');
      await _storage.saveAccessToken(
        token,
        refreshToken: data is Map ? data['refreshToken']?.toString() : null,
      );
      return token;
    } on DioException catch (e) {
      // Mạng yếu / timeout / 5xx: giữ phiên, chỉ request này lỗi. Chỉ đăng xuất khi BE
      // từ chối chính refresh token.
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) return _signOut(e);
      AppLogger.w('Refresh token failed (kept session)', e);
      return null;
    } catch (e) {
      return _signOut(e);
    }
  }

  Future<String?> _signOut(Object reason) async {
    AppLogger.w('Refresh token rejected — signing out', reason);
    if (!_storage.isLoggedIn) return null;
    await _storage.clearUser();
    AuthEventBus.emit(const UserLoggedOut());
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
