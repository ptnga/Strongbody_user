import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
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
  final VerifyEmailDomainUseCase _verifyEmailDomain;

  Timer? _resendTimer;
  Timer? _domainDebounce;

  /// Email gõ gần nhất ở màn đăng ký — bỏ kết quả kiểm tra domain của email cũ.
  String _domainEmail = '';

  /// Web cache kết quả theo email (tối đa 50).
  final _domainCache = <String, AuthMessage?>{};

  /// Đăng ký xong nhưng phải xác minh email → đăng nhập sau OTP tính là sign up.
  bool _signUpAwaitingVerify = false;

  /// Web: "Resend (m:ss)" sau 60 giây.
  static const resendSeconds = 60;

  // Cùng rule `signUpSchema` / `loginSchema` (zod) của web.
  static final _emailFormat = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _emailChars = RegExp(
    r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Web `useEmailDomainValidation`: chỉ kiểm tra khi có dạng `x@domain`.
  static final _domainCheckable = RegExp(r'^[^\s@]+@([^\s@]+)$');

  /// Web: gõ xong 800ms mới kiểm tra domain.
  static const domainDebounce = Duration(milliseconds: 800);

  AuthBloc({
    required SignUpUseCase signUp,
    required LoginUseCase login,
    required SocialLoginUseCase socialLogin,
    required VerifyEmailUseCase verifyEmail,
    required ResendVerifyEmailUseCase resendVerifyEmail,
    required RequestPasswordResetUseCase requestPasswordReset,
    required VerifyPasswordResetUseCase verifyPasswordReset,
    required ResetPasswordUseCase resetPassword,
    required VerifyEmailDomainUseCase verifyEmailDomain,
  }) : _signUp = signUp,
       _login = login,
       _socialLogin = socialLogin,
       _verifyEmail = verifyEmail,
       _resendVerifyEmail = resendVerifyEmail,
       _requestPasswordReset = requestPasswordReset,
       _verifyPasswordReset = verifyPasswordReset,
       _resetPassword = resetPassword,
       _verifyEmailDomain = verifyEmailDomain,
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
    on<AuthEmailChanged>(_onEmailChanged);
    on<_AuthEmailDomainRequested>(_onEmailDomainRequested);
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

  /// Bước 1 quên mật khẩu (web `ForgotPasswordDialog`): chỉ bắt buộc + đúng dạng email.
  static AuthMessage? validateForgotEmail(String email) {
    final value = email.trim();
    final key = value.isEmpty
        ? LocaleKeys.authEmailRequired
        : !_emailFormat.hasMatch(value)
        ? LocaleKeys.authEmailInvalid
        : null;
    return key == null ? null : AuthMessage.key(key);
  }

  /// Mật khẩu mới khi đặt lại (web `ForgotPasswordDialog`): chỉ tối thiểu 8 ký tự.
  static AuthMessage? validateNewPassword(String password) =>
      password.length < 8
      ? const AuthMessage.key(LocaleKeys.authPasswordMin)
      : null;

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
        clearEmailDomainError: true,
      ),
    );
  }

  /// Lỗi của các bước: message server, rỗng thì [fallback] (web `err?.message || t(...)`).
  AuthMessage _message(
    Failure failure, {
    String fallback = LocaleKeys.authSomethingWrong,
  }) => failure.message.isEmpty
      ? AuthMessage.key(fallback)
      : AuthMessage.text(failure.message);

  void _onEmailChanged(AuthEmailChanged event, Emitter<AuthState> emit) {
    final email = event.email.trim();
    // Controller báo cả khi chỉ dời con trỏ — email không đổi thì bỏ qua.
    if (email == _domainEmail) return;
    _domainDebounce?.cancel();
    _domainEmail = email;
    if (state.emailDomainError != null) {
      emit(state.copyWith(clearEmailDomainError: true));
    }
    if (state.screen != AuthScreen.signup ||
        !_domainCheckable.hasMatch(email)) {
      return;
    }
    if (_domainCache.containsKey(email)) {
      final cached = _domainCache[email];
      if (cached != null) emit(state.copyWith(emailDomainError: cached));
      return;
    }
    _domainDebounce = Timer(domainDebounce, () {
      if (!isClosed) add(_AuthEmailDomainRequested(email));
    });
  }

  Future<void> _onEmailDomainRequested(
    _AuthEmailDomainRequested event,
    Emitter<AuthState> emit,
  ) async {
    await callApi(
      useCase: _verifyEmailDomain,
      param: event.email,
      onSuccess: (result) async {
        // Web: `valid === false` → lỗi server, không có thì câu chung; null = không rõ.
        final error = result.valid == false
            ? (result.error?.isNotEmpty ?? false)
                  ? AuthMessage.text(result.error!)
                  : const AuthMessage.key(LocaleKeys.authEmailDomainInvalid)
            : null;
        if (result.valid != null) {
          if (_domainCache.length >= 50) {
            _domainCache.remove(_domainCache.keys.first);
          }
          _domainCache[event.email] = error;
        }
        if (event.email != _domainEmail || state.screen != AuthScreen.signup) {
          return;
        }
        emit(
          error == null
              ? state.copyWith(clearEmailDomainError: true)
              : state.copyWith(emailDomainError: error),
        );
      },
      onFailure: (_) {},
    );
  }

  static String _reason(Failure failure) => failure is AuthFailure
      ? failure.reason.name
      : failure.runtimeType.toString();

  void _trackFailure(String step, Failure failure, {String? method}) =>
      AppAnalytics.capture(AnalyticsEvents.authFailed, {
        'step': step,
        'reason': _reason(failure),
        'method': method,
      });

  void _trackVerifyRequired(String step) {
    _signUpAwaitingVerify = step == 'sign_up';
    AppAnalytics.capture(AnalyticsEvents.emailVerificationRequired, {
      'step': step,
    });
  }

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
      onSuccess: (session) async {
        AppAnalytics.capture(AnalyticsEvents.signUpCompleted, {
          'method': 'email',
        });
        emit(
          state.copyWith(
            status: AuthStatus.success,
            session: session,
            notice: const AuthNotice.success(
              AuthMessage.key(LocaleKeys.authRegisterSuccess),
            ),
          ),
        );
      },
      onFailure: (_) {},
      onFailureTyped: (failure) {
        final reason = failure is AuthFailure
            ? failure.reason
            : AuthFailureReason.other;
        switch (reason) {
          case AuthFailureReason.emailExists:
            // Web: toast "đã có tài khoản" rồi sang thẳng màn đăng nhập, điền sẵn email.
            _trackFailure('sign_up', failure);
            emit(
              state.copyWith(
                status: AuthStatus.idle,
                screen: AuthScreen.login,
                email: email,
                clearErrors: true,
                clearEmailDomainError: true,
                notice: const AuthNotice.info(
                  AuthMessage.key(LocaleKeys.authEmailExistsSignIn),
                ),
              ),
            );
          case AuthFailureReason.notVerified:
            // Đăng ký xong nhưng BE yêu cầu xác minh email trước khi đăng nhập.
            _trackVerifyRequired('sign_up');
            _enterOtp(emit, AuthScreen.verifyOtp);
          case _:
            _trackFailure('sign_up', failure);
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
      onSuccess: (session) async {
        AppAnalytics.capture(AnalyticsEvents.loginCompleted, {
          'method': 'email',
        });
        emit(_signedIn(session));
      },
      onFailure: (_) {},
      onFailureTyped: (failure) {
        final reason = failure is AuthFailure
            ? failure.reason
            : AuthFailureReason.other;
        if (reason == AuthFailureReason.notVerified) {
          _trackVerifyRequired('login');
        } else {
          _trackFailure('login', failure);
        }
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
      onSuccess: (session) async {
        AppAnalytics.capture(AnalyticsEvents.loginCompleted, {
          'method': event.provider.name,
        });
        emit(_signedIn(session));
      },
      onFailure: (_) {},
      onFailureTyped: (failure) {
        _trackFailure('social', failure, method: event.provider.name);
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
    // Ô mã tự gửi khi đủ 4 số — sửa số lúc đang kiểm tra không gửi chồng lượt thứ hai.
    if (state.isSubmitting) return;
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
        onFailureTyped: (failure) {
          _trackFailure('forgot_otp', failure);
          emit(
            state.copyWith(
              status: AuthStatus.idle,
              otpError: _message(
                failure,
                fallback: LocaleKeys.authTokenMissing,
              ),
            ),
          );
        },
      );
      return;
    }

    var verified = false;
    await callApi(
      useCase: _verifyEmail,
      param: EmailOtpParams(email: state.email, otp: otp),
      onSuccess: (_) async => verified = true,
      onFailure: (_) {},
      onFailureTyped: (failure) {
        // Web `ModalVerifyOtp` không hiện message server, chỉ "OTP verification failed".
        _trackFailure('otp', failure);
        emit(
          state.copyWith(
            status: AuthStatus.idle,
            otpError: const AuthMessage.key(LocaleKeys.authOtpFailed),
          ),
        );
      },
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
      onSuccess: (session) async {
        AppAnalytics.capture(
          _signUpAwaitingVerify
              ? AnalyticsEvents.signUpCompleted
              : AnalyticsEvents.loginCompleted,
          {'method': 'email', 'after_verify': true},
        );
        emit(
          state.copyWith(
            status: AuthStatus.success,
            session: session,
            notice: const AuthNotice.success(
              AuthMessage.key(LocaleKeys.authOtpVerified),
            ),
          ),
        );
      },
      onFailure: (_) {},
      onFailureTyped: (failure) {
        _trackFailure('login', failure);
        emit(
          state.copyWith(
            status: AuthStatus.idle,
            screen: AuthScreen.login,
            emailError: _message(failure),
          ),
        );
      },
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
      onFailureTyped: (failure) => emit(
        state.copyWith(
          otpError: _message(failure, fallback: LocaleKeys.authResendFailed),
        ),
      ),
    );
    if (!sent) return;
    emit(
      state.copyWith(
        clearErrors: true,
        notice: AuthNotice.success(
          AuthMessage.key(
            forgot ? LocaleKeys.authCodeResent : LocaleKeys.authOtpResent,
          ),
        ),
      ),
    );
    _startTimer(emit);
  }

  Future<void> _onForgotEmail(
    AuthForgotEmailSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final email = event.email.trim();
    final emailError = validateForgotEmail(email);
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
        state.copyWith(
          status: AuthStatus.idle,
          emailError: _message(failure, fallback: LocaleKeys.authEmailNotExist),
        ),
      ),
    );
  }

  Future<void> _onNewPassword(
    AuthNewPasswordSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final passwordError = validateNewPassword(event.password);
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
      onSuccess: (_) async {
        AppAnalytics.capture(AnalyticsEvents.passwordResetCompleted);
        emit(
          state.copyWith(
            status: AuthStatus.idle,
            screen: AuthScreen.forgotDone,
            password: '',
            notice: const AuthNotice.success(
              AuthMessage.key(LocaleKeys.authResetSuccess),
            ),
          ),
        );
      },
      onFailure: (_) {},
      onFailureTyped: (failure) {
        _trackFailure('reset_password', failure);
        emit(
          state.copyWith(
            status: AuthStatus.idle,
            formError: _message(failure, fallback: LocaleKeys.authResetFailed),
          ),
        );
      },
    );
  }

  /// Đăng nhập (email / Google / Apple) xong — web toast "Login successful" (`?login=success`).
  AuthState _signedIn(AuthSession session) => state.copyWith(
    status: AuthStatus.success,
    session: session,
    notice: const AuthNotice.success(
      AuthMessage.key(LocaleKeys.authLoginSuccess),
    ),
  );

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
    _domainDebounce?.cancel();
    return super.close();
  }
}
