import 'dart:convert';

/// Stable error codes returned by chat-server. Branch on these.
abstract class ErrorCode {
  static const String adminAuthFailed = 'admin_auth_failed';
  static const String missingToken = 'missing_token';
  static const String invalidToken = 'invalid_token';
  static const String tenantMismatch = 'tenant_mismatch';
  static const String noWritePermission = 'no_write_permission';
  static const String badJson = 'bad_json';
  static const String missingUuid = 'missing_uuid';
  static const String invalidTenant = 'invalid_tenant';
  static const String fanoutFailed = 'fanout_failed';
  static const String notImplemented = 'not_implemented';
  static const String transportError = 'transport_error';
}

/// Typed error thrown by SDK methods for non-2xx chat-server responses.
class ChatError implements Exception {
  final int httpStatus;
  final String code;
  final String message;

  const ChatError({
    required this.httpStatus,
    required this.code,
    required this.message,
  });

  @override
  String toString() =>
      'ChatError(http=$httpStatus, code=$code): $message';
}

bool isAdminAuthFailed(Object e) =>
    e is ChatError && e.code == ErrorCode.adminAuthFailed;
bool isInvalidToken(Object e) =>
    e is ChatError &&
    (e.code == ErrorCode.invalidToken || e.code == ErrorCode.missingToken);
bool isTenantMismatch(Object e) =>
    e is ChatError && e.code == ErrorCode.tenantMismatch;
bool isNoWritePermission(Object e) =>
    e is ChatError && e.code == ErrorCode.noWritePermission;
bool isBadRequest(Object e) =>
    e is ChatError &&
    (e.code == ErrorCode.badJson ||
        e.code == ErrorCode.missingUuid ||
        e.code == ErrorCode.invalidTenant);
bool isNotImplemented(Object e) =>
    e is ChatError && e.code == ErrorCode.notImplemented;

/// Parse a non-2xx HTTP response body into a [ChatError].
ChatError parseErrorBody(int status, String body) {
  String code = ErrorCode.transportError;
  String message = body;
  try {
    final Object? decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final Object? err = decoded['error'];
      if (err is Map<String, dynamic>) {
        code = (err['code'] as String?) ?? code;
        message = (err['message'] as String?) ?? message;
      }
    }
  } catch (_) {
    // Body wasn't JSON — keep raw text.
  }
  return ChatError(httpStatus: status, code: code, message: message);
}
