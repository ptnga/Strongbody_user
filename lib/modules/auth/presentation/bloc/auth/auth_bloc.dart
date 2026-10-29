import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';

import '../../../domain/entities/auth_entities.dart';
import '../../../domain/usecases/auth_use_cases.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Đăng ký / đăng nhập trong sheet — luồng + endpoint giống web `ModalAuth`
/// (`BuyerSignUpForm`, `LoginForm`, `ModalVerifyOtp`, `ForgotPasswordDialog`).
class AuthBloc extends BlocWithApi<AuthEvent, AuthState> {
  final SignUpUseCase _signUp;
  final LoginUseCase _login;
  final SocialLoginUseCase _socialLogin;
  final VerifyEmailUseCase _verifyEmail;
  final ResendVerifyEmailUseCase _resendVerifyEmail;
  final RequestPasswordResetUseCase _requestPasswordReset;
  final VerifyPasswordResetUseCase _verifyPasswordReset;
  final ResetPasswordUseCase _resetPassword;

  Timer? _resendTimer;

  /// Web: "Resend (m:ss)" sau 60 giây.
  static const resendSeconds = 60;

  // Cùng rule `signUpSchema` / `loginSchema` (zod) của web.
  static final _emailFormat = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _emailChars = RegExp(
    r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  AuthBloc({
    required SignUpUseCase signUp,
    required LoginUseCase login,
    required SocialLoginUseCase socialLogin,
    required VerifyEmailUseCase verifyEmail,
    required ResendVerifyEmailUseCase resendVerifyEmail,
    required RequestPasswordResetUseCase requestPasswordReset,
    required VerifyPasswordResetUseCase verifyPasswordReset,
    required ResetPasswordUseCase resetPassword,
  }) : _signUp = signUp,
       _login = login,
       _socialLogin = socialLogin,
       _verifyEmail = verifyEmail,
       _resendVerifyEmail = resendVerifyEmail,
       _requestPasswordReset = requestPasswordReset,
       _verifyPasswordReset = verifyPasswordReset,
       _resetPassword = resetPassword,
       super(const AuthState()) {
    on<AuthStarted>(
      (event, emit) =>
          emit(state.copyWith(screen: event.screen, email: event.email)),
    );
    on<AuthScreenChanged>(_onScreenChanged);
    on<AuthSignUpSubmitted>(_onSignUp);
    on<AuthLoginSubmitted>(_onLogin);
    on<AuthSocialRequested>(_onSocial);
    on<AuthOtpSubmitted>(_onOtp);
    on<AuthResendRequested>(_onResend);
    on<AuthForgotEmailSubmitted>(_onForgotEmail);
    on<AuthNewPasswordSubmitted>(_onNewPassword);
    on<_AuthResendTicked>(
      (event, emit) => emit(
        state.copyWith(resendIn: state.resendIn > 0 ? state.resendIn - 1 : 0),
      ),
    );
  }

  static AuthMessage? validateEmail(String email) {
    final value = email.trim();
    final key = value.isEmpty
        ? LocaleKeys.authEmailRequired
        : !_emailFormat.hasMatch(value)
        ? LocaleKeys.authEmailInvalid
        : !_emailChars.hasMatch(value)
        ? LocaleKeys.authEmailChars
        : null;
    return key == null ? null : AuthMessage.key(key);
  }

  static AuthMessage? validatePassword(String password) {
    final key = password.isEmpty
        ? LocaleKeys.authPasswordRequired
        : password.length < 8
        ? LocaleKeys.authPasswordMin
        : password.length > 64
        ? LocaleKeys.authPasswordMax
        : null;
    return key == null ? null : AuthMessage.key(key);
  }

  void _onScreenChanged(AuthScreenChanged event, Emitter<AuthState> emit) {
    emit(
      state.copyWith(
        screen: event.screen,
        email: event.email,
        status: AuthStatus.idle,
        clearErrors: true,
      ),
    );
  }

  /// Lỗi chung của các bước: không mạng / server → hiện dưới form.
  AuthMessage _message(Failure failure) => failure.message.isEmpty
      ? const AuthMessage.key(LocaleKeys.authSomethingWrong)
      : AuthMessage.text(failure.message);

  Future<void> _onSignUp(
    AuthSignUpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final email = event.email.trim();
    final emailError = validateEmail(email);
    final passwordError = validatePassword(event.password);
    emit(
      state.copyWith(
        email: email,
        password: event.password,
        clearErrors: true,
        emailError: emailError,
        passwordError: passwordError,
      ),
    );
    if (emailError != null || passwordError != null) return;

    emit(state.copyWith(status: AuthStatus.submitting));
    await callApi(
      useCase: _signUp,
      param: CredentialsParams(email: email, password: event.password),
      onSuccess: (session) async =>
          emit(state.copyWith(status: AuthStatus.success, session: session)),
      onFailure: (_) {},
      onFailureTyped: (failure) {
        final reason = failure is AuthFailure
            ? failure.reason
            : AuthFailureReason.other;
        switch (reason) {
          case AuthFailureReason.emailExists:
            emit(state.copyWith(status: AuthStatus.idle, emailExists: true));
          case AuthFailureReason.notVerified:
            // Đăng ký xong nhưng BE yêu cầu xác minh email trước khi đăng nhập.
            _enterOtp(emit, AuthScreen.verifyOtp);
          case _:
            emit(
              state.copyWith(
                status: AuthStatus.idle,
                formError: _message(failure),
              ),
            );
        }
      },
    );
  }

  Future<void> _onLogin(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final email = event.email.trim();
    final emailError = validateEmail(email);
    final passwordError = validatePassword(event.password);
    emit(
      state.copyWith(
        email: email,
        password: event.password,
        clearErrors: true,
        emailError: emailError,
        passwordError: passwordError,
      ),
    );
    if (emailError != null || passwordError != null) return;

    emit(state.copyWith(status: AuthStatus.submitting));
    await callApi(
      useCase: _login,
      param: CredentialsParams(email: email, password: event.password),
      onSuccess: (session) async =>
          emit(state.copyWith(status: AuthStatus.success, session: session)),
      onFailure: (_) {},
      onFailureTyped: (failure) {
        final reason = failure is AuthFailure
            ? failure.reason
            : AuthFailureReason.other;
        switch (reason) {
          case AuthFailureReason.notVerified:
            _enterOtp(emit, AuthScreen.verifyOtp);
          case AuthFailureReason.wrongPassword:
            emit(
              state.copyWith(
                status: AuthStatus.idle,
                passwordError: const AuthMessage.key(
                  LocaleKeys.authWrongPassword,
                ),
              ),
            );
          case _:
            // Web hiện message của server dưới ô email.
            emit(
              state.copyWith(
                status: AuthStatus.idle,
                emailError: _message(failure),
              ),
            );
        }
      },
    );
  }

  Future<void> _onSocial(
    AuthSocialRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.submitting, clearErrors: true));
    await callApi(
      useCase: _socialLogin,
      param: event.provider,
      onSuccess: (session) async =>
          emit(state.copyWith(status: AuthStatus.success, session: session)),
      onFailure: (_) {},
      onFailureTyped: (failure) {
        final reason = failure is AuthFailure
            ? failure.reason
            : AuthFailureReason.other;
        emit(
          state.copyWith(
            status: AuthStatus.idle,
            formError: switch (reason) {
              AuthFailureReason.cancelled => null,
              AuthFailureReason.notConfigured => const AuthMessage.key(
                LocaleKeys.authSocialNotConfigured,
              ),
              _ => _message(failure),
            },
          ),
        );
      },
    );
  }

  Future<void> _onOtp(AuthOtpSubmitted event, Emitter<AuthState> emit) async {
    final otp = event.otp.trim();
    if (otp.length != 4) {
      emit(
        state.copyWith(
          otpError: const AuthMessage.key(LocaleKeys.authOtpRequired),
        ),
      );
      return;
    }
    emit(state.copyWith(status: AuthStatus.submitting, clearErrors: true));

    if (state.screen == AuthScreen.forgotOtp) {
      await callApi(
        useCase: _verifyPasswordReset,
        param: EmailOtpParams(email: state.email, otp: otp),
        onSuccess: (token) async => emit(
          state.copyWith(
            status: AuthStatus.idle,
            secretToken: token,
            screen: AuthScreen.forgotNewPassword,
          ),
        ),
        onFailure: (_) {},
        onFailureTyped: (failure) => emit(
          state.copyWith(status: AuthStatus.idle, otpError: _message(failure)),
        ),
      );
      return;
    }

    var verified = false;
    await callApi(
      useCase: _verifyEmail,
      param: EmailOtpParams(email: state.email, otp: otp),
      onSuccess: (_) async => verified = true,
      onFailure: (_) {},
      onFailureTyped: (failure) => emit(
        state.copyWith(status: AuthStatus.idle, otpError: _message(failure)),
      ),
    );
    if (!verified) return;
    _stopTimer();
    // Xác minh xong → đăng nhập bằng mật khẩu vừa nhập (web `signIn('credentials')`).
    if (state.password.isEmpty) {
      emit(state.copyWith(status: AuthStatus.idle, screen: AuthScreen.login));
      return;
    }
    await callApi(
      useCase: _login,
      param: CredentialsParams(email: state.email, password: state.password),
      onSuccess: (session) async =>
          emit(state.copyWith(status: AuthStatus.success, session: session)),
      onFailure: (_) {},
      onFailureTyped: (failure) => emit(
        state.copyWith(
          status: AuthStatus.idle,
          screen: AuthScreen.login,
          emailError: _message(failure),
        ),
      ),
    );
  }

  Future<void> _onResend(
    AuthResendRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state.resendIn > 0 || state.isSubmitting) return;
    final forgot = state.screen == AuthScreen.forgotOtp;
    var sent = false;
    await callApi(
      useCase: forgot ? _requestPasswordReset : _resendVerifyEmail,
      param: state.email,
      onSuccess: (_) async => sent = true,
      onFailure: (_) {},
      onFailureTyped: (failure) =>
          emit(state.copyWith(otpError: _message(failure))),
    );
    if (sent) _startTimer(emit);
  }

  Future<void> _onForgotEmail(
    AuthForgotEmailSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final email = event.email.trim();
    final emailError = validateEmail(email);
    emit(
      state.copyWith(email: email, clearErrors: true, emailError: emailError),
    );
    if (emailError != null) return;
    emit(state.copyWith(status: AuthStatus.submitting));
    await callApi(
      useCase: _requestPasswordReset,
      param: email,
      onSuccess: (_) async => _enterOtp(emit, AuthScreen.forgotOtp),
      onFailure: (_) {},
      onFailureTyped: (failure) => emit(
        state.copyWith(status: AuthStatus.idle, emailError: _message(failure)),
      ),
    );
  }

  Future<void> _onNewPassword(
    AuthNewPasswordSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final passwordError = validatePassword(event.password);
    final mismatch = event.password != event.confirm
        ? const AuthMessage.key(LocaleKeys.authPasswordMismatch)
        : null;
    emit(
      state.copyWith(
        clearErrors: true,
        passwordError: passwordError ?? mismatch,
      ),
    );
    if (passwordError != null || mismatch != null) return;
    emit(state.copyWith(status: AuthStatus.submitting));
    await callApi(
      useCase: _resetPassword,
      param: ResetPasswordParams(
        secretToken: state.secretToken ?? '',
        newPassword: event.password,
      ),
      onSuccess: (_) async => emit(
        state.copyWith(
          status: AuthStatus.idle,
          screen: AuthScreen.forgotDone,
          password: '',
        ),
      ),
      onFailure: (_) {},
      onFailureTyped: (failure) => emit(
        state.copyWith(status: AuthStatus.idle, formError: _message(failure)),
      ),
    );
  }

  /// Sang màn nhập mã + bắt đầu đếm ngược "Resend" trong cùng một state.
  void _enterOtp(Emitter<AuthState> emit, AuthScreen screen) {
    emit(
      state.copyWith(
        status: AuthStatus.idle,
        screen: screen,
        clearErrors: true,
        resendIn: resendSeconds,
      ),
    );
    _runTimer();
  }

  void _startTimer(Emitter<AuthState> emit) {
    emit(state.copyWith(resendIn: resendSeconds));
    _runTimer();
  }

  void _runTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed || state.resendIn <= 1) timer.cancel();
      if (!isClosed) add(const _AuthResendTicked());
    });
  }

  void _stopTimer() {
    _resendTimer?.cancel();
    _resendTimer = null;
  }

  @override
  Future<void> close() {
    _stopTimer();
    return super.close();
  }
}
