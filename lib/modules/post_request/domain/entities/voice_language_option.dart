import 'package:equatable/equatable.dart';

import 'request_options.dart';

/// Ngôn ngữ nói cho màn ghi âm: mã của app (vd `vi`) + locale nhận dạng của máy (vd `vi_VN`).
class VoiceLanguageOption extends Equatable {
  final String code;
  final String localeId;
  final String nativeName;

  const VoiceLanguageOption({
    required this.code,
    required this.localeId,
    required this.nativeName,
  });

  /// Ghép danh sách ngôn ngữ của app với locale máy hỗ trợ. Máy không trả danh
  /// sách (một số Android) → dùng luôn mã của app làm locale.
  static List<VoiceLanguageOption> fromDeviceLocales(
    List<String> deviceLocaleIds,
  ) {
    final normalized = {
      for (final id in deviceLocaleIds)
        id.toLowerCase().replaceAll('_', '-'): id,
    };
    final options = <VoiceLanguageOption>[];
    for (final language in requestLanguages) {
      final target = language.code.toLowerCase();
      String? localeId;
      if (normalized.isEmpty) {
        localeId = language.code;
      } else {
        for (final entry in normalized.entries) {
          if (entry.key == target || entry.key.startsWith('$target-')) {
            localeId = entry.value;
            break;
          }
        }
      }
      if (localeId != null) {
        options.add(
          VoiceLanguageOption(
            code: language.code,
            localeId: localeId,
            nativeName: language.nativeName,
          ),
        );
      }
    }
    return options;
  }

  /// `vi_VN` / `en-US` / `zh_TW` → mã ngôn ngữ của app (`vi`, `en`, `zh-TW`).
  static String? appCodeForLocale(String localeId) {
    final normalized = localeId.toLowerCase().replaceAll('_', '-');
    final codes = requestLanguages.map((l) => l.code).toList();
    for (final code in codes) {
      if (normalized == code.toLowerCase()) return code;
    }
    for (final code in codes) {
      if (normalized.startsWith('${code.toLowerCase()}-')) return code;
    }
    final base = normalized.split('-').first;
    for (final code in codes) {
      if (code.toLowerCase().startsWith('$base-')) return code;
    }
    return null;
  }

  @override
  List<Object?> get props => [code, localeId, nativeName];
}
