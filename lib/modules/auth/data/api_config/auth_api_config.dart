/// Endpoint đăng ký / đăng nhập — giống web (`src/api/auth`, `src/guards/authOptions.ts`,
/// `ModalAuth/*`). Riêng Google / Apple dùng endpoint native của Multime vì token lấy từ SDK
/// mobile (web dùng OAuth web → `/login-google`, `/login-apple-web`).
class AuthApiConfig {
  AuthApiConfig._();

  static const String signUp = '/public/auth/sign-up';
  static const String login = '/public/auth/login';

  /// OTP khi đăng nhập báo "Account not verified" (web `ModalVerifyOtp`).
  static const String verifyEmail = '/verify-email';
  static const String resendVerifyEmail = '/auth/resend-verify-email';

  /// Quên mật khẩu (web `ForgotPasswordDialog`): gửi mã → xác minh → đặt lại.
  static const String forgotPassword = '/forgot-password';
  static const String forgotPasswordVerify = '/forgot-password/verify';
  static const String forgotPasswordReset = '/forgot-password/reset';

  /// Sau khi xác minh email, web gọi để nhận offer gửi tới email lúc còn là khách.
  static const String claimOffer = '/public/offer/claim';

  static const String loginGoogleIdToken = '/public/auth/login-google-id-token';
  static const String loginApple = '/public/auth/login-apple';

  /// Lấy IP công khai gửi kèm đăng ký (web `/api/ip`, Multime ipify).
  static const String ipLookup = 'https://api.ipify.org?format=json';
}
