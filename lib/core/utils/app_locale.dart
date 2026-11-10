import 'dart:ui' show Locale, PlatformDispatcher;

/// Ngôn ngữ giao diện của app (khớp `supportedLocales` ở `main.dart`).
abstract final class AppLocale {
  static const supported = ['en', 'vi'];
  static const fallback = 'en';

  /// Như web `proxy.ts`: ngôn ngữ đã lưu → ngôn ngữ thiết bị đầu tiên app hỗ trợ
  /// (web `detectSupportedLocaleFromAcceptLanguage`, theo thứ tự ưu tiên) → `en`.
  static String resolve(String? saved, List<Locale> deviceLocales) {
    final stored = _normalize(saved);
    if (stored != null) return stored;
    for (final locale in deviceLocales) {
      final code = _normalize(locale.languageCode);
      if (code != null) return code;
    }
    return fallback;
  }

  /// Ngôn ngữ thiết bị (danh sách ưu tiên của hệ điều hành).
  static List<Locale> get deviceLocales => PlatformDispatcher.instance.locales;

  static String? _normalize(String? value) {
    final code = value?.trim().toLowerCase().split(RegExp('[-_]')).first;
    return code != null && supported.contains(code) ? code : null;
  }
}
