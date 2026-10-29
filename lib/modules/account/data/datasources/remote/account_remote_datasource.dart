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
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body);
  Future<void> logout();
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
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async =>
      _map(
        _unwrap(
          await _api.request(
            path: AccountApiConfig.profile,
            method: ApiType.put,
            data: body,
            headers: {'x-api-key': AppConfig.publicApiKey},
          ),
        ),
      );

  @override
  Future<void> logout() async {
    _unwrap(
      await _api.request(path: AccountApiConfig.logout, method: ApiType.post),
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
