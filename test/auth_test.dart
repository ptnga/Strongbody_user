import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/modules/auth/data/models/response/login_response_dto.dart';
import 'package:strongbody_buyer/modules/auth/domain/entities/auth_entities.dart';
import 'package:strongbody_buyer/modules/auth/domain/repositories/auth_repository.dart';
import 'package:strongbody_buyer/modules/auth/domain/usecases/auth_use_cases.dart';
import 'package:strongbody_buyer/modules/auth/presentation/bloc/auth/auth_bloc.dart';

/// Repo giả: mô phỏng đúng message BE mà web đang so.
class _FakeAuthRepository implements AuthRepository {
  bool verified = false;
  final calls = <String>[];

  static const _session = AuthSession(
    userId: 7,
    name: 'Sarah Nguyen',
    email: 'sarah@mail.com',
  );

  @override
  Future<Either<Failure, Unit>> signUp({
    required String email,
    required String password,
  }) async {
    calls.add('signUp');
    if (email == 'taken@mail.com') {
      return Left(
        AuthFailure(
          'Email already exist',
          reason: AuthFailureReason.emailExists,
        ),
      );
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, AuthSession>> login({
    required String email,
    required String password,
  }) async {
    calls.add('login');
    if (password != 'secret123') {
      return Left(
        AuthFailure(
          'Password is incorrect',
          reason: AuthFailureReason.wrongPassword,
        ),
      );
    }
    if (email == 'new@mail.com' && !verified) {
      return Left(
        AuthFailure(
          'Account not verified',
          reason: AuthFailureReason.notVerified,
          statusCode: 401,
        ),
      );
    }
    return const Right(_session);
  }

  @override
  Future<Either<Failure, Unit>> verifyEmail({
    required String email,
    required String otp,
  }) async {
    calls.add('verify');
    if (otp != '1234') return Left(AuthFailure('Invalid OTP'));
    verified = true;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> resendVerifyEmail(String email) async {
    calls.add('resend');
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> requestPasswordReset(String email) async {
    calls.add('forgot');
    return const Right(unit);
  }

  @override
  Future<Either<Failure, String>> verifyPasswordReset({
    required String email,
    required String otp,
  }) async => const Right('secret-token');

  @override
  Future<Either<Failure, Unit>> resetPassword({
    required String secretToken,
    required String newPassword,
  }) async {
    calls.add('reset:$secretToken');
    return const Right(unit);
  }

  @override
  Future<Either<Failure, AuthSession>> loginWithGoogle() async =>
      Left(AuthFailure('', reason: AuthFailureReason.notConfigured));

  @override
  Future<Either<Failure, AuthSession>> loginWithApple() async =>
      Left(AuthFailure('', reason: AuthFailureReason.cancelled));
}

AuthBloc _bloc(AuthRepository repo) => AuthBloc(
  signUp: SignUpUseCase(repo),
  login: LoginUseCase(repo),
  socialLogin: SocialLoginUseCase(repo),
  verifyEmail: VerifyEmailUseCase(repo),
  resendVerifyEmail: ResendVerifyEmailUseCase(repo),
  requestPasswordReset: RequestPasswordResetUseCase(repo),
  verifyPasswordReset: VerifyPasswordResetUseCase(repo),
  resetPassword: ResetPasswordUseCase(repo),
);

Future<AuthState> _until(AuthBloc bloc, bool Function(AuthState) test) =>
    test(bloc.state) ? Future.value(bloc.state) : bloc.stream.firstWhere(test);

void main() {
  test(
    'login response: double-nested user + tokens (web authOptions shape)',
    () {
      final dto = LoginResponseDto.fromData({
        'token': {'accessToken': 'a.b.c', 'refreshToken': 'r'},
        'user': {
          'role': 'User',
          'user': {
            'id': 7,
            'first_name': 'Sarah',
            'last_name': 'Nguyen',
            'email': 's@m.com',
          },
        },
        'seller': null,
      });
      expect(dto.accessToken, 'a.b.c');
      expect(dto.refreshToken, 'r');
      expect(dto.userId, 7);
      expect(dto.firstName, 'Sarah');
      expect(dto.role, 'User');
    },
  );

  test('backend messages → reasons', () {
    expect(
      AuthFailure.reasonFor('Email already exist'),
      AuthFailureReason.emailExists,
    );
    expect(
      AuthFailure.reasonFor('Account not verified'),
      AuthFailureReason.notVerified,
    );
    expect(
      AuthFailure.reasonFor('Password is incorrect'),
      AuthFailureReason.wrongPassword,
    );
  });

  test('validation matches web zod rules', () {
    expect(AuthBloc.validateEmail('')?.key, LocaleKeys.authEmailRequired);
    expect(AuthBloc.validateEmail('abc')?.key, LocaleKeys.authEmailInvalid);
    expect(
      AuthBloc.validateEmail('a+b@mail.com')?.key,
      LocaleKeys.authEmailChars,
    );
    expect(AuthBloc.validateEmail('sarah@mail.com'), isNull);
    expect(AuthBloc.validatePassword('short')?.key, LocaleKeys.authPasswordMin);
    expect(
      AuthBloc.validatePassword('a' * 65)?.key,
      LocaleKeys.authPasswordMax,
    );
  });

  test('sign up → auto login → success', () async {
    final repo = _FakeAuthRepository();
    final bloc = _bloc(repo)
      ..add(
        const AuthSignUpSubmitted(
          email: 'sarah@mail.com',
          password: 'secret123',
        ),
      );
    final done = await _until(bloc, (s) => s.status == AuthStatus.success);
    expect(done.session?.userId, 7);
    expect(repo.calls, ['signUp', 'login']);
    await bloc.close();
  });

  test('sign up with taken email → "you can sign in now"', () async {
    final bloc = _bloc(_FakeAuthRepository())
      ..add(
        const AuthSignUpSubmitted(
          email: 'taken@mail.com',
          password: 'secret123',
        ),
      );
    final state = await _until(bloc, (s) => s.emailExists);
    expect(state.status, AuthStatus.idle);
    bloc.add(
      const AuthScreenChanged(AuthScreen.login, email: 'taken@mail.com'),
    );
    final login = await _until(bloc, (s) => s.screen == AuthScreen.login);
    expect(login.email, 'taken@mail.com');
    expect(login.emailExists, isFalse);
    await bloc.close();
  });

  test('wrong password shows under password field', () async {
    final bloc = _bloc(_FakeAuthRepository())
      ..add(const AuthStarted(screen: AuthScreen.login))
      ..add(
        const AuthLoginSubmitted(
          email: 'sarah@mail.com',
          password: 'nope12345',
        ),
      );
    final state = await _until(bloc, (s) => s.passwordError != null);
    expect(state.passwordError?.key, LocaleKeys.authWrongPassword);
    await bloc.close();
  });

  test('not verified → OTP (60s resend) → verify → login', () async {
    final repo = _FakeAuthRepository();
    final bloc = _bloc(repo)
      ..add(const AuthStarted(screen: AuthScreen.login))
      ..add(
        const AuthLoginSubmitted(email: 'new@mail.com', password: 'secret123'),
      );
    final otp = await _until(bloc, (s) => s.screen == AuthScreen.verifyOtp);
    expect(otp.resendIn, AuthBloc.resendSeconds);

    bloc.add(const AuthOtpSubmitted('0000'));
    await _until(bloc, (s) => s.otpError != null);

    bloc.add(const AuthOtpSubmitted('1234'));
    final done = await _until(bloc, (s) => s.status == AuthStatus.success);
    expect(done.session?.email, 'sarah@mail.com');
    expect(repo.calls.where((c) => c == 'verify').length, 2);
    await bloc.close();
  });

  test('forgot password: email → code → new password → done', () async {
    final repo = _FakeAuthRepository();
    final bloc = _bloc(repo)
      ..add(const AuthScreenChanged(AuthScreen.forgotEmail))
      ..add(const AuthForgotEmailSubmitted('sarah@mail.com'));
    await _until(bloc, (s) => s.screen == AuthScreen.forgotOtp);
    bloc.add(const AuthOtpSubmitted('1234'));
    await _until(bloc, (s) => s.screen == AuthScreen.forgotNewPassword);

    bloc.add(
      const AuthNewPasswordSubmitted(
        password: 'newpass123',
        confirm: 'other123',
      ),
    );
    final mismatch = await _until(bloc, (s) => s.passwordError != null);
    expect(mismatch.passwordError?.key, LocaleKeys.authPasswordMismatch);

    bloc.add(
      const AuthNewPasswordSubmitted(
        password: 'newpass123',
        confirm: 'newpass123',
      ),
    );
    await _until(bloc, (s) => s.screen == AuthScreen.forgotDone);
    expect(repo.calls, contains('reset:secret-token'));
    await bloc.close();
  });

  test('social: not configured shows message, cancel is silent', () async {
    final bloc = _bloc(_FakeAuthRepository())
      ..add(const AuthSocialRequested(SocialProvider.google));
    final state = await _until(bloc, (s) => s.formError != null);
    expect(state.formError?.key, LocaleKeys.authSocialNotConfigured);
    bloc.add(const AuthSocialRequested(SocialProvider.apple));
    final cancelled = await _until(
      bloc,
      (s) => s.status == AuthStatus.idle && s.formError == null,
    );
    expect(cancelled.session, isNull);
    await bloc.close();
  });
}
