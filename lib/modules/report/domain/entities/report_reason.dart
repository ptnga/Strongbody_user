import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';

/// Lý do báo cáo một người dùng (mirror Provider `report/domain/entities`).
/// [code] là giá trị gửi lên `POST /buyer/reports` (`type`).
enum ReportReason {
  spam('spam', LocaleKeys.reportReasonSpam),
  fraud('fraud', LocaleKeys.reportReasonFraud),
  hate('hate', LocaleKeys.reportReasonHate),
  violence('violence', LocaleKeys.reportReasonViolence),
  nudity('nudity', LocaleKeys.reportReasonNudity),
  selfHarm('self_harm', LocaleKeys.reportReasonSelfHarm),
  under18('under_18', LocaleKeys.reportReasonUnder18),
  other('other', LocaleKeys.reportReasonOther);

  const ReportReason(this.code, this.labelKey);

  final String code;

  /// Khoá l10n của nhãn hiển thị (gọi `.tr()` ở presentation).
  final String labelKey;
}
