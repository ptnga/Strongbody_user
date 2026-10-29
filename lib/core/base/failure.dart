class Failure {
  final String message;

  /// Mã HTTP kèm theo lỗi (nếu có). Giúp presentation phân nhánh xử lý
  /// mà không phải dò chuỗi trong [message].
  final int? statusCode;

  Failure(this.message, {this.statusCode});
}

/// Lỗi mạng: không kết nối được, timeout, huỷ request.
class NetworkFailure extends Failure {
  NetworkFailure(super.message, {super.statusCode});
}

/// Máy chủ trả về lỗi (5xx hoặc business code khác 0/200).
class ServerFailure extends Failure {
  ServerFailure(super.message, {super.statusCode});
}

/// Tài nguyên không tồn tại (404) hoặc endpoint chưa được deploy.
class NotFoundFailure extends Failure {
  NotFoundFailure(super.message, {super.statusCode});
}

/// Hết phiên đăng nhập hoặc không đủ quyền (401/403).
class UnauthorizedFailure extends Failure {
  UnauthorizedFailure(super.message, {super.statusCode});
}
