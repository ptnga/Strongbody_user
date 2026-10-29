import 'package:strongbody_buyer/core/config/environment.dart';

class AccountApiConfig {
  AccountApiConfig._();

  /// strongbody-api (base đã có `/v1`) — web `getAuthMe` / `addSocialLink` / `Logout`.
  static const String me = '/buyer/auth/me';
  static const String profile = '/buyer/auth/profile';
  static const String logout = '/public/auth/logout';

  /// Giá trị 1 điểm — web `getValueOfPoint` (header `scope: admin-dashboard` + `x-api-key`).
  static const String appSettings = '/admin/app-settings';
  static const String adminScope = 'admin-dashboard';

  /// Point service — web `src/api/lionpoint` (chỉ header Bearer).
  static String wallet(int userId) =>
      '${AppConfig.pointApiUrl}/v1/wallets/customer/$userId';
  static String ledger(int walletId) =>
      '${AppConfig.pointApiUrl}/v1/transactions/wallets/$walletId/ledger';
}
