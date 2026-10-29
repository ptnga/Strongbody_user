import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/auth_entities.dart';
import '../repositories/auth_repository.dart';

class CredentialsParams extends Equatable {
  final String email;
  final String password;

  const CredentialsParams({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class EmailOtpParams extends Equatable {
  final String email;
  final String otp;

  const EmailOtpParams({required this.email, required this.otp});

  @override
  List<Object?> get props => [email, otp];
}

class ResetPasswordParams extends Equatable {
  final String secretToken;
  final String newPassword;

  const ResetPasswordParams({
    required this.secretToken,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [secretToken, newPassword];
}

enum SocialProvider { google, apple }

/// Đăng ký rồi đăng nhập luôn bằng chính email / mật khẩu đó (như web `SignUpForm`).
class SignUpUseCase implements UseCase<AuthSession, CredentialsParams> {
  final AuthRepository _repository;

  SignUpUseCase(this._repository);

  @override
  Future<Either<Failure, AuthSession>> call(CredentialsParams params) async {
    final signedUp = await _repository.signUp(
      email: params.email,
      password: params.password,
    );
    return signedUp.fold(
      (failure) async => Left(failure),
      (_) => _repository.login(email: params.email, password: params.password),
    );
  }
}

class LoginUseCase implements UseCase<AuthSession, CredentialsParams> {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  @override
  Future<Either<Failure, AuthSession>> call(CredentialsParams params) =>
      _repository.login(email: params.email, password: params.password);
}

class SocialLoginUseCase implements UseCase<AuthSession, SocialProvider> {
  final AuthRepository _repository;

  SocialLoginUseCase(this._repository);

  @override
  Future<Either<Failure, AuthSession>> call(SocialProvider provider) =>
      switch (provider) {
        SocialProvider.google => _repository.loginWithGoogle(),
        SocialProvider.apple => _repository.loginWithApple(),
      };
}

class VerifyEmailUseCase implements UseCase<Unit, EmailOtpParams> {
  final AuthRepository _repository;

  VerifyEmailUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(EmailOtpParams params) =>
      _repository.verifyEmail(email: params.email, otp: params.otp);
}

class ResendVerifyEmailUseCase implements UseCase<Unit, String> {
  final AuthRepository _repository;

  ResendVerifyEmailUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(String email) =>
      _repository.resendVerifyEmail(email);
}

class RequestPasswordResetUseCase implements UseCase<Unit, String> {
  final AuthRepository _repository;

  RequestPasswordResetUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(String email) =>
      _repository.requestPasswordReset(email);
}

class VerifyPasswordResetUseCase implements UseCase<String, EmailOtpParams> {
  final AuthRepository _repository;

  VerifyPasswordResetUseCase(this._repository);

  @override
  Future<Either<Failure, String>> call(EmailOtpParams params) =>
      _repository.verifyPasswordReset(email: params.email, otp: params.otp);
}

class ResetPasswordUseCase implements UseCase<Unit, ResetPasswordParams> {
  final AuthRepository _repository;

  ResetPasswordUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(ResetPasswordParams params) =>
      _repository.resetPassword(
        secretToken: params.secretToken,
        newPassword: params.newPassword,
      );
}
