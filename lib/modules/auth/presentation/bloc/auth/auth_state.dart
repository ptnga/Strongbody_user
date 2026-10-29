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

  /// Đăng ký trùng email → hiện gợi ý "You can sign in now".
  final bool emailExists;

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
    this.emailExists = false,
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
    bool? emailExists,
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
      emailExists: emailExists ?? (clearErrors ? false : this.emailExists),
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
    emailExists,
    resendIn,
    session,
  ];
}
