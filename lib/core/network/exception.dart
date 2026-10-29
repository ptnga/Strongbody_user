/// Lỗi không có response từ server (mất mạng, timeout, huỷ request).
class NetworkException implements Exception {
  final String message;
  final int? statusCode;

  NetworkException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
