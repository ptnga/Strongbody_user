import 'dart:io';

import 'package:dio/dio.dart';

import 'package:strongbody_buyer/core/config/environment.dart';
import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';

import '../../api_config/auth_api_config.dart';

/// Lỗi nghiệp vụ trong envelope `{code, message}` (HTTP 200 nhưng code != 0, hoặc HTTP lỗi).
class AuthApiException implements Exception {
  final String message;
  final int? code;
  final int? statusCode;

  AuthApiException(this.message, {this.code, this.statusCode});

  @override
  String toString() => message;
}

abstract class AuthRemoteDataSource {
  Future<void> signUp(Map<String, dynamic> body);

  /// Trả `data` của response login.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  });

  Future<void> verifyEmail({
    required String email,
    required String otp,
    String? referralCode,
  });

  Future<void> resendVerifyEmail(String email);

  Future<void> requestPasswordReset(String email);

  /// Trả `secret_token`.
  Future<String> verifyPasswordReset({
    required String email,
    required String otp,
  });

  Future<void> resetPassword({
    required String secretToken,
    required String newPassword,
  });

  Future<Map<String, dynamic>> loginGoogle(String idToken);

  Future<Map<String, dynamic>> loginApple(String authorizationCode);

  Future<void> claimOffer(String email);

  Future<String?> publicIp();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl(this._apiClient);

  static String get _platform => Platform.isIOS ? 'ios' : 'android';

  Map<String, dynamic> get _apiKey => {'x-api-key': AppConfig.publicApiKey};

  /// Gọi API auth, chuẩn hoá lỗi về [AuthApiException]; trả `data` (Map) nếu code == 0.
  Future<Map<String, dynamic>> _call({
    required String path,
    required ApiType method,
    Map<String, dynamic>? data,
    Map<String, dynamic>? headers,
  }) async {
    dynamic body;
    try {
      body = await _apiClient.request(
        path: path,
        method: method,
        data: data,
        headers: headers,
        skipAuth: true,
      );
    } on DioException catch (e) {
      final res = e.response?.data;
      throw AuthApiException(
        res is Map
            ? (res['message']?.toString() ?? 'Request failed')
            : 'Request failed',
        code: res is Map ? (res['code'] as num?)?.toInt() : null,
        statusCode: e.response?.statusCode,
      );
    }
    if (body is Map) {
      final code = (body['code'] as num?)?.toInt();
      if (code != null && code != 0) {
        throw AuthApiException(
          body['message']?.toString() ?? 'Request failed',
          code: code,
        );
      }
      final payload = body['data'];
      return payload is Map ? Map<String, dynamic>.from(payload) : const {};
    }
    return const {};
  }

  @override
  Future<void> signUp(Map<String, dynamic> body) => _call(
    path: AuthApiConfig.signUp,
    method: ApiType.post,
    data: {...body, 'platform': _platform},
  );

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) => _call(
    path: AuthApiConfig.login,
    method: ApiType.post,
    data: {'email': email, 'password': password},
  );

  @override
  Future<void> verifyEmail({
    required String email,
    required String otp,
    String? referralCode,
  }) => _call(
    path: AuthApiConfig.verifyEmail,
    method: ApiType.post,
    headers: _apiKey,
    data: {
      'email': email,
      'otp': otp,
      'referral_code': referralCode ?? '',
      'role_signup': 'user',
    },
  );

  @override
  Future<void> resendVerifyEmail(String email) => _call(
    path: AuthApiConfig.resendVerifyEmail,
    method: ApiType.post,
    data: {'email': email},
  );

  @override
  Future<void> requestPasswordReset(String email) => _call(
    path: AuthApiConfig.forgotPassword,
    method: ApiType.post,
    headers: _apiKey,
    data: {'email': email},
  );

  @override
  Future<String> verifyPasswordReset({
    required String email,
    required String otp,
  }) async {
    final data = await _call(
      path: AuthApiConfig.forgotPasswordVerify,
      method: ApiType.post,
      headers: _apiKey,
      data: {'email': email, 'otp': otp},
    );
    final token = (data['secret_token'] ?? data['secretToken'])?.toString();
    if (token == null || token.isEmpty) throw AuthApiException('Invalid code');
    return token;
  }

  @override
  Future<void> resetPassword({
    required String secretToken,
    required String newPassword,
  }) => _call(
    path: AuthApiConfig.forgotPasswordReset,
    method: ApiType.patch,
    headers: _apiKey,
    data: {'secretToken': secretToken, 'newPassword': newPassword},
  );

  @override
  Future<Map<String, dynamic>> loginGoogle(String idToken) => _call(
    path: AuthApiConfig.loginGoogleIdToken,
    method: ApiType.post,
    data: {'id_token': idToken, 'platform': _platform, 'role_signup': 'user'},
  );

  @override
  Future<Map<String, dynamic>> loginApple(String authorizationCode) => _call(
    path: AuthApiConfig.loginApple,
    method: ApiType.post,
    data: {
      'id_token': authorizationCode,
      'platform': _platform,
      'role_signup': 'user',
    },
  );

  @override
  Future<void> claimOffer(String email) => _call(
    path: AuthApiConfig.claimOffer,
    method: ApiType.post,
    data: {'email': email},
  );

  @override
  Future<String?> publicIp() async {
    try {
      final body = await _apiClient.request(
        path: AuthApiConfig.ipLookup,
        method: ApiType.get,
        skipAuth: true,
        timeout: const Duration(seconds: 4),
      );
      return body is Map ? body['ip']?.toString() : null;
    } catch (_) {
      return null;
    }
  }
}
