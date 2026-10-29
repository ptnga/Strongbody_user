import 'package:hive_flutter/hive_flutter.dart';

class GlobalStorageKey {
  GlobalStorageKey._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String isLoggedIn = 'is_logged_in';
  static const String userId = 'user_id';
  static const String userName = 'user_name';
  static const String userEmail = 'user_email';

  /// Mã giới thiệu (deep link / affiliate) — gửi kèm khi đăng ký, giống web cookie `referral_code`.
  static const String referralCode = 'referral_code';
  static const String locale = 'locale';

  /// Request đang chờ đăng (khách chưa đăng nhập) — đăng nhập xong thì gửi tiếp.
  static const String pendingRequest = 'pending_request';
}

abstract class GlobalStorage {
  Future<void> init();

  String? get accessToken;
  String? get refreshToken;
  bool get isLoggedIn;
  int? get userId;
  String? get userName;
  String? get userEmail;
  String? get referralCode;
  String get locale;
  Map<String, dynamic>? get pendingRequest;

  Future<void> saveTokens({required String accessToken, String? refreshToken});
  Future<void> saveUser({required int id, String? name, String? email});
  Future<void> saveAccessToken(String accessToken, {String? refreshToken});
  Future<void> saveLocale(String locale);
  Future<void> savePendingRequest(Map<String, dynamic> json);
  Future<void> clearPendingRequest();
  Future<void> clearUser();
}

class GlobalStorageImpl implements GlobalStorage {
  static const String _boxName = 'globalStorage';
  late Box _box;

  @override
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  @override
  String? get accessToken => _box.get(GlobalStorageKey.accessToken) as String?;

  @override
  String? get refreshToken =>
      _box.get(GlobalStorageKey.refreshToken) as String?;

  @override
  bool get isLoggedIn =>
      _box.get(GlobalStorageKey.isLoggedIn, defaultValue: false) as bool;

  @override
  int? get userId => _box.get(GlobalStorageKey.userId) as int?;

  @override
  String? get userName => _box.get(GlobalStorageKey.userName) as String?;

  @override
  String? get userEmail => _box.get(GlobalStorageKey.userEmail) as String?;

  @override
  String? get referralCode =>
      _box.get(GlobalStorageKey.referralCode) as String?;

  @override
  String get locale =>
      _box.get(GlobalStorageKey.locale, defaultValue: 'en') as String;

  @override
  Map<String, dynamic>? get pendingRequest {
    final raw = _box.get(GlobalStorageKey.pendingRequest);
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _box.put(GlobalStorageKey.accessToken, accessToken);
    if (refreshToken != null) {
      await _box.put(GlobalStorageKey.refreshToken, refreshToken);
    }
    await _box.put(GlobalStorageKey.isLoggedIn, true);
  }

  @override
  Future<void> saveUser({required int id, String? name, String? email}) async {
    await _box.put(GlobalStorageKey.userId, id);
    await _box.put(GlobalStorageKey.userName, name);
    await _box.put(GlobalStorageKey.userEmail, email);
  }

  /// Chỉ thay token (refresh) — giữ nguyên trạng thái đăng nhập.
  @override
  Future<void> saveAccessToken(
    String accessToken, {
    String? refreshToken,
  }) async {
    await _box.put(GlobalStorageKey.accessToken, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _box.put(GlobalStorageKey.refreshToken, refreshToken);
    }
  }

  @override
  Future<void> saveLocale(String locale) =>
      _box.put(GlobalStorageKey.locale, locale);

  @override
  Future<void> savePendingRequest(Map<String, dynamic> json) =>
      _box.put(GlobalStorageKey.pendingRequest, json);

  @override
  Future<void> clearPendingRequest() =>
      _box.delete(GlobalStorageKey.pendingRequest);

  /// Xoá phiên đăng nhập, giữ lại cài đặt thiết bị (locale...) và request đang chờ.
  @override
  Future<void> clearUser() async {
    await _box.deleteAll([
      GlobalStorageKey.accessToken,
      GlobalStorageKey.refreshToken,
      GlobalStorageKey.isLoggedIn,
      GlobalStorageKey.userId,
      GlobalStorageKey.userName,
      GlobalStorageKey.userEmail,
    ]);
  }
}
