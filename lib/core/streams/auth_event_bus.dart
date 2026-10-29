import 'dart:async';

/// Sự kiện phiên đăng nhập — màn nào cần làm mới (Home: lời chào, pill offer…) thì nghe.
sealed class AuthEvent {
  const AuthEvent();
}

final class UserLoggedIn extends AuthEvent {
  const UserLoggedIn();
}

final class UserLoggedOut extends AuthEvent {
  const UserLoggedOut();
}

/// Đổi tên / ảnh ở Account → Home làm mới lời chào, avatar.
final class UserProfileUpdated extends AuthEvent {
  const UserProfileUpdated();
}

/// Stream tĩnh typed (cùng kiểu `AuthEventBus` của Multime `lib/core/streams/`).
abstract final class AuthEventBus {
  static final _controller = StreamController<AuthEvent>.broadcast();

  static Stream<AuthEvent> get stream => _controller.stream;

  static void emit(AuthEvent event) => _controller.add(event);
}
