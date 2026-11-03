import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';

import '../../api_config/user_block_api_config.dart';

/// Lỗi nghiệp vụ bóc từ envelope `{code, message, data}` — mang nguyên `code`
/// và `message` gốc để `UserBlockErrorMapper` phân loại.
class UserBlockApiException implements Exception {
  final int code;
  final String message;

  UserBlockApiException(this.code, this.message);

  @override
  String toString() => message;
}

abstract class UserBlockRemoteDataSource {
  Future<Map<String, dynamic>> block(int userId, {String? reason});
  Future<void> unblock(int blockRecordId);
  Future<Map<String, dynamic>> myBlocked({required int page, required int limit});
  Future<Map<String, dynamic>> check(int userId);
}

class UserBlockRemoteDataSourceImpl implements UserBlockRemoteDataSource {
  final ApiClient _api;

  UserBlockRemoteDataSourceImpl(this._api);

  Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  /// Bóc envelope và ném lỗi nghiệp vụ ra ngoài (server trả HTTP 200 kèm `code`).
  dynamic _unwrap(dynamic body) {
    if (body is Map) {
      final code = body['code'];
      if (code is num && code != 0 && code != 200) {
        throw UserBlockApiException(
          code.toInt(),
          body['message']?.toString() ?? 'Failed',
        );
      }
      return body.containsKey('data') ? body['data'] : body;
    }
    return body;
  }

  @override
  Future<Map<String, dynamic>> block(int userId, {String? reason}) async => _map(
    _unwrap(
      await _api.request(
        path: UserBlockApiConfig.userBlocks,
        method: ApiType.post,
        data: {
          'blocked_id': userId,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      ),
    ),
  );

  @override
  Future<void> unblock(int blockRecordId) async {
    _unwrap(
      await _api.request(
        path: UserBlockApiConfig.byId(blockRecordId),
        method: ApiType.delete,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> myBlocked({
    required int page,
    required int limit,
  }) async => _map(
    _unwrap(
      await _api.request(
        path: UserBlockApiConfig.myBlocked,
        method: ApiType.get,
        queryParameters: {'page': page < 1 ? 1 : page, 'limit': limit},
      ),
    ),
  );

  @override
  Future<Map<String, dynamic>> check(int userId) async => _map(
    _unwrap(
      await _api.request(
        path: UserBlockApiConfig.check(userId),
        method: ApiType.get,
      ),
    ),
  );
}
