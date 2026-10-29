part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Mở sheet ở màn [screen] (request → signup, các chỗ khác → login).
final class AuthStarted extends AuthEvent {
  final AuthScreen screen;
  final String email;

  const AuthStarted({this.screen = AuthScreen.signup, this.email = ''});

  @override
  List<Object?> get props => [screen, email];
}

/// "Already have an account? Sign in" / "Don't have an account? Sign up" / "Forgot Password?".
final class AuthScreenChanged extends AuthEvent {
  final AuthScreen screen;
  final String? email;

  const AuthScreenChanged(this.screen, {this.email});

  @override
  List<Object?> get props => [screen, email];
}

final class AuthSignUpSubmitted extends AuthEvent {
  final String email;
  final String password;

  const AuthSignUpSubmitted({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

final class AuthLoginSubmitted extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginSubmitted({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

final class AuthSocialRequested extends AuthEvent {
  final SocialProvider provider;

  const AuthSocialRequested(this.provider);

  @override
  List<Object?> get props => [provider];
}

final class AuthOtpSubmitted extends AuthEvent {
  final String otp;

  const AuthOtpSubmitted(this.otp);

  @override
  List<Object?> get props => [otp];
}

/// Gửi lại mã (OTP xác minh email hoặc mã quên mật khẩu, tuỳ màn hiện tại).
final class AuthResendRequested extends AuthEvent {
  const AuthResendRequested();
}

final class AuthForgotEmailSubmitted extends AuthEvent {
  final String email;

  const AuthForgotEmailSubmitted(this.email);

  @override
  List<Object?> get props => [email];
}

final class AuthNewPasswordSubmitted extends AuthEvent {
  final String password;
  final String confirm;

  const AuthNewPasswordSubmitted({
    required this.password,
    required this.confirm,
  });

  @override
  List<Object?> get props => [password, confirm];
}

final class _AuthResendTicked extends AuthEvent {
  const _AuthResendTicked();
}
