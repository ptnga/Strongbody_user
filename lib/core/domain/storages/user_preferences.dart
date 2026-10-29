import 'package:hive_flutter/hive_flutter.dart';

/// Tuỳ chọn trên máy ở tab Account ("Voice & language") — không gắn với phiên đăng nhập.
abstract class UserPreferences {
  Future<void> init();

  /// Mã ngôn ngữ khi nói (vd `vi`); null = Auto-detect.
  String? get speakingLanguage;

  /// Hội thoại mới tự bật "Translate on" (đã đồng ý dịch AI ở Account).
  bool get autoTranslateChats;

  /// Tự phát voice / đọc to tin mới của provider khi đang mở chat.
  bool get readRepliesAloud;

  /// Đính kèm bản ghi giọng nói khi đăng request bằng giọng nói.
  bool get attachVoiceToRequests;

  /// Từ khoá đã tìm ở Home (mới nhất trước, tối đa [maxRecentSearches]).
  List<String> get recentSearches;

  static const maxRecentSearches = 5;

  Future<void> addRecentSearch(String text);

  /// Đăng xuất → không để người dùng sau trên máy thấy từ khoá của người trước.
  Future<void> clearRecentSearches();

  Future<void> setSpeakingLanguage(String? code);
  Future<void> setAutoTranslateChats(bool value);
  Future<void> setReadRepliesAloud(bool value);
  Future<void> setAttachVoiceToRequests(bool value);
}

class UserPreferencesImpl implements UserPreferences {
  static const _boxName = 'userPreferences';
  static const _speakingLanguage = 'speaking_language';
  static const _autoTranslate = 'auto_translate_chats';
  static const _readAloud = 'read_replies_aloud';
  static const _attachVoice = 'attach_voice_to_requests';
  static const _recentSearches = 'recent_searches';

  late Box _box;

  @override
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  @override
  String? get speakingLanguage => _box.get(_speakingLanguage) as String?;

  @override
  bool get autoTranslateChats =>
      _box.get(_autoTranslate, defaultValue: false) as bool;

  @override
  bool get readRepliesAloud =>
      _box.get(_readAloud, defaultValue: false) as bool;

  @override
  bool get attachVoiceToRequests =>
      _box.get(_attachVoice, defaultValue: true) as bool;

  @override
  List<String> get recentSearches =>
      (_box.get(_recentSearches) as List?)?.whereType<String>().toList() ??
      const [];

  @override
  Future<void> addRecentSearch(String text) {
    final query = text.trim();
    if (query.isEmpty) return Future.value();
    final list = [
      query,
      ...recentSearches.where((s) => s.toLowerCase() != query.toLowerCase()),
    ].take(UserPreferences.maxRecentSearches).toList();
    return _box.put(_recentSearches, list);
  }

  @override
  Future<void> clearRecentSearches() => _box.delete(_recentSearches);

  @override
  Future<void> setSpeakingLanguage(String? code) => code == null
      ? _box.delete(_speakingLanguage)
      : _box.put(_speakingLanguage, code);

  @override
  Future<void> setAutoTranslateChats(bool value) =>
      _box.put(_autoTranslate, value);

  @override
  Future<void> setReadRepliesAloud(bool value) => _box.put(_readAloud, value);

  @override
  Future<void> setAttachVoiceToRequests(bool value) =>
      _box.put(_attachVoice, value);
}
