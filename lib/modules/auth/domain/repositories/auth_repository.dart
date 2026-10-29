import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';

import '../entities/auth_entities.dart';

abstract class AuthRepository {
  /// `POST /public/auth/sign-up` (không đăng nhập — gọi [login] ngay sau, như web).
  Future<Either<Failure, Unit>> signUp({
    required String email,
    required String password,
  });

  /// `POST /public/auth/login` → lưu token + user, phát `UserLoggedIn`.
  Future<Either<Failure, AuthSession>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, Unit>> verifyEmail({
    required String email,
    required String otp,
  });

  Future<Either<Failure, Unit>> resendVerifyEmail(String email);

  Future<Either<Failure, Unit>> requestPasswordReset(String email);

  /// Trả `secret_token` dùng cho bước đặt lại mật khẩu.
  Future<Either<Failure, String>> verifyPasswordReset({
    required String email,
    required String otp,
  });

  Future<Either<Failure, Unit>> resetPassword({
    required String secretToken,
    required String newPassword,
  });

  Future<Either<Failure, AuthSession>> loginWithGoogle();

  Future<Either<Failure, AuthSession>> loginWithApple();
}
