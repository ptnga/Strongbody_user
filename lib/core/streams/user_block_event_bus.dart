import 'dart:async';

/// Việc chặn / bỏ chặn vừa xảy ra (port từ Multime `lib/core/streams/`).
sealed class UserBlockEvent {
  const UserBlockEvent();

  /// Id người bị chặn hoặc vừa được bỏ chặn.
  int get userId;
}

class UserBlocked extends UserBlockEvent {
  const UserBlocked({required this.userId, required this.blockRecordId});

  @override
  final int userId;

  /// `id` bản ghi block — thứ cần cho lệnh DELETE lúc bỏ chặn, không phải
  /// [userId]. `0` nghĩa là chưa dò ra, phải hỏi lại `my-blocked`.
  final int blockRecordId;
}

class UserUnblocked extends UserBlockEvent {
  const UserUnblocked(this.userId);

  @override
  final int userId;
}

/// Loan tin chặn / bỏ chặn cho toàn app.
///
/// Chặn xảy ra ở menu "⋯" của màn chat, nhưng thứ phải phản ứng là chính màn
/// chat (khoá composer) và màn "Blocked users" (gỡ dòng). Không có quan hệ cha
/// con nào để truyền callback giữa chúng.
abstract final class UserBlockEventBus {
  static final StreamController<UserBlockEvent> _controller =
      StreamController<UserBlockEvent>.broadcast();

  /// Ai đang bị chặn, và bằng bản ghi nào. Là `Map` vì bỏ chặn cần
  /// `blockRecordId`. Tồn tại độc lập với stream để màn mở sau khi sự kiện đã
  /// bay qua vẫn đọc được trạng thái hiện tại.
  static final Map<int, int> _recordIdByUserId = {};

  static Stream<UserBlockEvent> get stream => _controller.stream;

  static bool isBlocked(int? userId) =>
      userId != null && _recordIdByUserId.containsKey(userId);

  static int? recordIdOf(int userId) {
    final id = _recordIdByUserId[userId];
    // `0` là "đã chặn nhưng chưa biết id bản ghi" — trả `null` để nơi gọi biết
    // phải dò lại, thay vì gửi DELETE /user_blocks/0.
    return (id == null || id <= 0) ? null : id;
  }

  /// Cập nhật registry **trước** khi phát: nơi nghe stream có thể đọc registry
  /// ngay trong handler.
  static void emit(UserBlockEvent event) {
    switch (event) {
      case UserBlocked(:final userId, :final blockRecordId):
        _recordIdByUserId[userId] = blockRecordId;
      case UserUnblocked(:final userId):
        _recordIdByUserId.remove(userId);
    }
    if (!_controller.isClosed) _controller.add(event);
  }

  /// Xoá sạch registry. Gọi khi đăng xuất — danh sách chặn là của riêng một
  /// người.
  static void clear() => _recordIdByUserId.clear();
}
