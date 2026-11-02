import '../../domain/entities/user_block_error.dart';

/// Nơi duy nhất dịch `code` + `message` tiếng Anh của server sang enum.
abstract final class UserBlockErrorMapper {
  /// Khớp bằng `contains` chứ không phải `==` (server có thể đổi hoa/thường hay
  /// thêm dấu chấm cuối câu).
  static UserBlockFailure map(int code, Object? rawMessage) {
    final message = (rawMessage?.toString() ?? '').trim();
    final needle = message.toLowerCase();

    if (code == 401 || code == 403) {
      return UserBlockFailure(UserBlockError.unauthorized, message);
    }

    final kind = switch (needle) {
      _ when needle.contains('block yourself') =>
        UserBlockError.cannotBlockSelf,
      _ when needle.contains('already blocked') =>
        UserBlockError.alreadyBlocked,
      _ when needle.contains('only unblock') => UserBlockError.notMyBlock,
      _ when needle.contains('not found') => UserBlockError.blockNotFound,
      _ when needle.contains('unauthorized') => UserBlockError.unauthorized,
      _ => UserBlockError.unknown,
    };

    return UserBlockFailure(kind, message.isEmpty ? 'Unknown error' : message);
  }

  static UserBlockFailure network(Object error) =>
      UserBlockFailure(UserBlockError.network, error.toString());
}
