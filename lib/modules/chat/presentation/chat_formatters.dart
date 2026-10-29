import 'package:easy_localization/easy_localization.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_options.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/request_formatters.dart';

import '../domain/entities/chat_message_entity.dart';
import '../domain/entities/conversation_entity.dart';

/// Chuỗi hiển thị của Messages / Chat.
class ChatFormatters {
  ChatFormatters._();

  /// `vi` → "Vietnamese" (UI tiếng Anh) / "Tiếng Việt" (UI tiếng Việt); `zh` khớp `zh-CN`.
  static String? languageName(String? code, String uiLocale) {
    if (code == null || code.isEmpty) return null;
    final normalized = code.replaceAll('_', '-').toLowerCase();
    RequestLanguageOption? match;
    for (final option in requestLanguages) {
      final c = option.code.toLowerCase();
      if (c == normalized) {
        match = option;
        break;
      }
      if (match == null && c.split('-').first == normalized.split('-').first) {
        match = option;
      }
    }
    // Không khớp: mã ngắn → viết hoa, còn lại coi là tên sẵn ("English").
    if (match == null) return code.length <= 3 ? code.toUpperCase() : code;
    return uiLocale == 'vi' ? match.nativeName : match.name;
  }

  /// Tên gọi trong câu ("Minh") — chữ đầu của tên.
  static String firstName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? name : parts.first;
  }

  /// Giờ ở danh sách: hôm nay "09:41", cùng tuần "Mon", còn lại "12 Oct".
  static String listTime(DateTime time, String locale, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final days = today.difference(_day(time)).inDays;
    if (days == 0) return DateFormat.Hm(locale).format(time);
    if (days > 0 && days < 7) return DateFormat.E(locale).format(time);
    final sameYear = time.year == today.year;
    return DateFormat(sameYear ? 'd MMM' : 'd MMM y', locale).format(time);
  }

  /// Nhãn ngăn ngày trong chat: "Today" / "Yesterday" / "Sat 24 Oct".
  static String dayLabel(DateTime time, String locale, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final days = today.difference(_day(time)).inDays;
    if (days == 0) return LocaleKeys.chatToday.tr();
    if (days == 1) return LocaleKeys.chatYesterday.tr();
    final sameYear = time.year == today.year;
    return DateFormat(
      sameYear ? 'EEE d MMM' : 'EEE d MMM y',
      locale,
    ).format(time);
  }

  static String time(DateTime time, String locale) =>
      DateFormat.Hm(locale).format(time);

  static bool sameDay(DateTime a, DateTime b) => _day(a) == _day(b);

  /// Dòng xem trước: text / "Voice message · 0:14" / "Photo"… (+ "You: " nếu mình gửi).
  static String preview(ConversationEntity c, int myUserId) {
    final body = switch (c.lastType) {
      ChatMessageType.voice => [
        LocaleKeys.messagesVoiceMessage.tr(),
        if (c.lastVoiceDuration case final d?) RequestFormatters.duration(d),
      ].join(' · '),
      ChatMessageType.image => LocaleKeys.messagesPhoto.tr(),
      ChatMessageType.file => LocaleKeys.messagesFile.tr(),
      ChatMessageType.offer => LocaleKeys.messagesOffer.tr(
        args: [c.lastText.isEmpty ? '—' : c.lastText],
      ),
      ChatMessageType.text =>
        c.lastText.isEmpty ? LocaleKeys.messagesOtherType.tr() : c.lastText,
      ChatMessageType.other => LocaleKeys.messagesOtherType.tr(),
    };
    return c.lastSenderId == myUserId && c.lastType == ChatMessageType.text
        ? LocaleKeys.messagesYou.tr(args: [body])
        : body;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
