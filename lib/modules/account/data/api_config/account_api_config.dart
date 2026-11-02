import 'package:strongbody_buyer/core/config/environment.dart';

class AccountApiConfig {
  AccountApiConfig._();

  /// strongbody-api (base đã có `/v1`) — web `getAuthMe` / `addSocialLink` / `Logout`.
  static const String me = '/buyer/auth/me';
  static const String profile = '/buyer/auth/profile';
  static const String logout = '/public/auth/logout';

  /// Xoá tài khoản 2 bước (App Store Guideline 5.1.1(v)). Bước 1 `DELETE
  /// /buyer/auth/user/{userId}` (xác minh email+mật khẩu, server gửi mã OTP);
  /// bước 2 `POST /verify-account-deletion` (email+otp) mới xoá thật.
  static const String deleteAccount = '/buyer/auth/user';
  static const String verifyAccountDeletion = '/verify-account-deletion';

  /// Giá trị 1 điểm — web `getValueOfPoint` (header `scope: admin-dashboard` + `x-api-key`).
  static const String appSettings = '/admin/app-settings';
  static const String adminScope = 'admin-dashboard';

  /// Point service — web `src/api/lionpoint` (chỉ header Bearer).
  static String wallet(int userId) =>
      '${AppConfig.pointApiUrl}/v1/wallets/customer/$userId';
  static String ledger(int walletId) =>
      '${AppConfig.pointApiUrl}/v1/transactions/wallets/$walletId/ledger';
}
