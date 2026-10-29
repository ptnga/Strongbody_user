import 'package:equatable/equatable.dart';

import 'package:strongbody_buyer/core/base/failure.dart';

/// Phiên đăng nhập đã lưu.
class AuthSession extends Equatable {
  final int userId;
  final String? name;
  final String? email;

  const AuthSession({required this.userId, this.name, this.email});

  @override
  List<Object?> get props => [userId, name, email];
}

/// Lý do lỗi auth mà UI xử lý riêng (giống web `LoginForm` / `BuyerSignUpForm`).
enum AuthFailureReason {
  /// Đăng ký: "Email already exist" → gợi ý đăng nhập.
  emailExists,

  /// Đăng nhập: "Account not verified" → màn nhập OTP.
  notVerified,

  /// Đăng nhập: "Password is incorrect".
  wrongPassword,

  /// Huỷ hộp thoại Google / Apple — không báo lỗi.
  cancelled,

  /// Bản build chưa cấu hình Google / Apple.
  notConfigured,
  other,
}

class AuthFailure extends Failure {
  final AuthFailureReason reason;

  AuthFailure(
    super.message, {
    this.reason = AuthFailureReason.other,
    super.statusCode,
  });

  /// Map message của BE (cùng chuỗi web đang so) → lý do.
  static AuthFailureReason reasonFor(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('already exist')) return AuthFailureReason.emailExists;
    if (lower.contains('not verified')) return AuthFailureReason.notVerified;
    if (lower.contains('password is incorrect') ||
        lower.contains('wrong password')) {
      return AuthFailureReason.wrongPassword;
    }
    return AuthFailureReason.other;
  }
}
