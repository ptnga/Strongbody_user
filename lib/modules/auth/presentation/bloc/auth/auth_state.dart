part of 'auth_bloc.dart';

/// Các màn trong sheet đăng nhập (mirror web `ModalAuth`: signup / login / OTP / quên mật khẩu).
enum AuthScreen {
  signup,
  login,
  verifyOtp,
  forgotEmail,
  forgotOtp,
  forgotNewPassword,
  forgotDone,
}

enum AuthStatus { idle, submitting, success }

/// Lỗi / thông báo: `key` = LocaleKeys (lỗi của app), `text` = message của server.
class AuthMessage extends Equatable {
  final String? key;
  final String? text;

  const AuthMessage.key(String this.key) : text = null;
  const AuthMessage.text(String this.text) : key = null;

  @override
  List<Object?> get props => [key, text];
}

/// Toast sau một bước (web `toast.success` / `toast.info`).
class AuthNotice extends Equatable {
  final AuthMessage message;

  /// `true` = toast thông tin (vd email đã có tài khoản), `false` = thành công.
  final bool info;

  const AuthNotice.success(this.message) : info = false;
  const AuthNotice.info(this.message) : info = true;

  @override
  List<Object?> get props => [message, info];
}

class AuthState extends Equatable {
  final AuthScreen screen;
  final AuthStatus status;
  final String email;

  /// Giữ mật khẩu vừa nhập để đăng nhập lại ngay sau khi xác minh OTP.
  final String password;
  final String? secretToken;
  final AuthMessage? emailError;
  final AuthMessage? passwordError;
  final AuthMessage? otpError;
  final AuthMessage? formError;

  /// Domain email không nhận thư (chỉ cảnh báo ở màn đăng ký, không chặn gửi — như web).
  final AuthMessage? emailDomainError;

  /// Toast mới nhất; [noticeId] tăng mỗi lần có toast để UI chỉ hiện một lần.
  final AuthNotice? notice;
  final int noticeId;

  /// Đếm ngược nút "Resend" (giây).
  final int resendIn;
  final AuthSession? session;

  const AuthState({
    this.screen = AuthScreen.signup,
    this.status = AuthStatus.idle,
    this.email = '',
    this.password = '',
    this.secretToken,
    this.emailError,
    this.passwordError,
    this.otpError,
    this.formError,
    this.emailDomainError,
    this.notice,
    this.noticeId = 0,
    this.resendIn = 0,
    this.session,
  });

  bool get isSubmitting => status == AuthStatus.submitting;

  AuthState copyWith({
    AuthScreen? screen,
    AuthStatus? status,
    String? email,
    String? password,
    String? secretToken,
    AuthMessage? emailError,
    AuthMessage? passwordError,
    AuthMessage? otpError,
    AuthMessage? formError,
    bool clearErrors = false,
    AuthMessage? emailDomainError,
    bool clearEmailDomainError = false,
    AuthNotice? notice,
    int? resendIn,
    AuthSession? session,
  }) {
    return AuthState(
      screen: screen ?? this.screen,
      status: status ?? this.status,
      email: email ?? this.email,
      password: password ?? this.password,
      secretToken: secretToken ?? this.secretToken,
      emailError: clearErrors ? emailError : (emailError ?? this.emailError),
      passwordError: clearErrors
          ? passwordError
          : (passwordError ?? this.passwordError),
      otpError: clearErrors ? otpError : (otpError ?? this.otpError),
      formError: clearErrors ? formError : (formError ?? this.formError),
      emailDomainError: clearEmailDomainError
          ? null
          : (emailDomainError ?? this.emailDomainError),
      notice: notice ?? this.notice,
      noticeId: notice != null ? noticeId + 1 : noticeId,
      resendIn: resendIn ?? this.resendIn,
      session: session ?? this.session,
    );
  }

  @override
  List<Object?> get props => [
    screen,
    status,
    email,
    password,
    secretToken,
    emailError,
    passwordError,
    otpError,
    formError,
    emailDomainError,
    notice,
    noticeId,
    resendIn,
    session,
  ];
}
