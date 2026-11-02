class UserBlockApiConfig {
  UserBlockApiConfig._();

  /// strongbody-api (base đã có `/v1`, Scope `strongbody-ai` tự gắn,
  /// `blocker_id` lấy từ JWT).
  static const String userBlocks = '/buyer/user_blocks';
  static const String myBlocked = '$userBlocks/my-blocked';

  static String byId(int recordId) => '$userBlocks/$recordId';
  static String check(int userId) => '$userBlocks/check/$userId';
}
