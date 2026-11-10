import 'package:dio/dio.dart';

import 'package:strongbody_buyer/core/config/environment.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';

import '../../api_config/account_api_config.dart';

/// strongbody-api trả `{code, message, data}` (code != 0 = lỗi, kể cả HTTP 200).
class AccountApiException implements Exception {
  final String message;

  AccountApiException(this.message);

  @override
  String toString() => message;
}

abstract class AccountRemoteDataSource {
  Future<Map<String, dynamic>> getMe();

  /// Web `updateBuyerProfile`: `PUT /buyer/auth/profile` dạng multipart (FormData).
  Future<Map<String, dynamic>> updateProfile(Map<String, String> fields);
  Future<void> logout();

  /// Bước 1: yêu cầu xoá → server gửi mã OTP tới email.
  Future<void> requestAccountDeletion({
    required int userId,
    required String email,
    required String password,
  });

  /// Bước 2: gửi mã OTP để xác nhận và xoá thật.
  Future<void> verifyAccountDeletion({
    required String email,
    required String otp,
  });
  Future<Map<String, dynamic>> getWallet(int userId);
  Future<Map<String, dynamic>> getAppSettings();
  Future<List<Map<String, dynamic>>> getLedger(
    int walletId, {
    required int page,
    required int limit,
  });
}

class AccountRemoteDataSourceImpl implements AccountRemoteDataSource {
  final ApiClient _api;
  final GlobalStorage _storage;

  AccountRemoteDataSourceImpl(this._api, this._storage);

  Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  dynamic _unwrap(dynamic body) {
    if (body is Map) {
      final code = body['code'];
      if (code is num && code != 0 && code != 200) {
        throw AccountApiException(body['message']?.toString() ?? 'Failed');
      }
      return body.containsKey('data') ? body['data'] : body;
    }
    return body;
  }

  /// Point service: chỉ Bearer, không refresh/đăng xuất khi nó trả 401 (khác strongbody-api).
  Map<String, dynamic> get _pointHeaders => {
    'Authorization': 'Bearer ${_storage.accessToken}',
  };

  @override
  Future<Map<String, dynamic>> getMe() async {
    final data = _map(
      _unwrap(
        await _api.request(path: AccountApiConfig.me, method: ApiType.get),
      ),
    );
    return data['user'] is Map ? _map(data['user']) : data;
  }

  @override
  Future<Map<String, dynamic>> updateProfile(
    Map<String, String> fields,
  ) async => _map(
    _unwrap(
      await _api.request(
        path: AccountApiConfig.profile,
        method: ApiType.put,
        data: FormData.fromMap(fields),
      ),
    ),
  );

  @override
  Future<void> logout() async {
    _unwrap(
      await _api.request(path: AccountApiConfig.logout, method: ApiType.post),
    );
  }

  /// Bước 1 (`DELETE /buyer/auth/user/{userId}`): BE kiểm tra email+mật khẩu rồi
  /// gửi mã OTP. Body JSON `{email, password}` như web `deleteAccount`.
  @override
  Future<void> requestAccountDeletion({
    required int userId,
    required String email,
    required String password,
  }) async {
    _unwrap(
      await _api.request(
        path: '${AccountApiConfig.deleteAccount}/$userId',
        method: ApiType.delete,
        data: {'email': email, 'password': password},
      ),
    );
  }

  /// Bước 2 (`POST /verify-account-deletion`): body `{email, otp}`.
  @override
  Future<void> verifyAccountDeletion({
    required String email,
    required String otp,
  }) async {
    _unwrap(
      await _api.request(
        path: AccountApiConfig.verifyAccountDeletion,
        method: ApiType.post,
        headers: {'x-api-key': AppConfig.publicApiKey},
        data: {'email': email, 'otp': otp},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> getWallet(int userId) async => _map(
    _unwrap(
      await _api.request(
        path: AccountApiConfig.wallet(userId),
        method: ApiType.get,
        headers: _pointHeaders,
        skipAuth: true,
      ),
    ),
  );

  @override
  Future<Map<String, dynamic>> getAppSettings() async => _map(
    _unwrap(
      await _api.request(
        path: AccountApiConfig.appSettings,
        method: ApiType.get,
        skipAuth: true,
        headers: {
          'Authorization': 'Bearer ${_storage.accessToken}',
          'Scope': AccountApiConfig.adminScope,
          'x-api-key': AppConfig.publicApiKey,
        },
      ),
    ),
  );

  @override
  Future<List<Map<String, dynamic>>> getLedger(
    int walletId, {
    required int page,
    required int limit,
  }) async {
    final body = await _api.request(
      path: AccountApiConfig.ledger(walletId),
      method: ApiType.get,
      queryParameters: {'page': page, 'limit': limit},
      headers: _pointHeaders,
      skipAuth: true,
    );
    final data = body is Map ? body['data'] : body;
    final list = data is Map ? (data['list'] ?? data['data']) : data;
    return list is List
        ? list.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const [];
  }
}
