import 'package:easy_localization/easy_localization.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';

import '../domain/entities/request_category.dart';
import '../domain/entities/request_form_values.dart';
import '../domain/entities/request_options.dart';

/// Chuỗi hiển thị cho request (dùng chung ở Heard / Review / Posted / My requests).
class RequestFormatters {
  RequestFormatters._();

  static String delivery(RequestDeliveryType type) => switch (type) {
    RequestDeliveryType.remote => LocaleKeys.requestDeliveryOnline.tr(),
    RequestDeliveryType.atHome => LocaleKeys.requestDeliveryAtHome.tr(),
    RequestDeliveryType.atClinic => LocaleKeys.requestDeliveryAtClinic.tr(),
  };

  static String category(RequestCategory category) => switch (category) {
    RequestCategory.fitness => LocaleKeys.requestCategoryFitness.tr(),
    RequestCategory.healthPro => LocaleKeys.requestCategoryHealthPro.tr(),
    RequestCategory.longevity => LocaleKeys.requestCategoryLongevity.tr(),
    RequestCategory.mentalWellness =>
      LocaleKeys.requestCategoryMentalWellness.tr(),
    RequestCategory.beauty => LocaleKeys.requestCategoryBeauty.tr(),
    RequestCategory.medicalTravel =>
      LocaleKeys.requestCategoryMedicalTravel.tr(),
    RequestCategory.massageTherapy =>
      LocaleKeys.requestCategoryMassageTherapy.tr(),
    RequestCategory.personalHelper =>
      LocaleKeys.requestCategoryPersonalHelper.tr(),
  };

  /// "Massage & Therapy, Fitness & Movement"; null nếu AI chưa phân loại.
  static String? categories(List<int> ids) {
    final names = ids
        .map(RequestCategory.fromId)
        .whereType<RequestCategory>()
        .map(category)
        .toList();
    return names.isEmpty ? null : names.join(', ');
  }

  /// "At my home · At a clinic"; null nếu chưa chọn.
  static String? where(RequestFormValues values) => values.deliveryTypes.isEmpty
      ? null
      : values.deliveryTypes.map(delivery).join(' · ');

  /// "Sat 24 – Sun 25 Oct" / "Sat 24 Oct"; null nếu không có ngày.
  static String? when(RequestFormValues values, String locale) {
    final start = values.deadline;
    if (start == null) return null;
    final end = values.endDate;
    final dayFormat = DateFormat('EEE d', locale);
    final monthFormat = DateFormat('MMM', locale);
    if (end == null) {
      return '${dayFormat.format(start)} ${monthFormat.format(start)}';
    }
    final sameMonth = start.month == end.month && start.year == end.year;
    final left = sameMonth
        ? dayFormat.format(start)
        : '${dayFormat.format(start)} ${monthFormat.format(start)}';
    return '$left – ${dayFormat.format(end)} ${monthFormat.format(end)}';
  }

  /// "$60–80" (USD/EUR/GBP có ký hiệu) hoặc "60–80 VND"; null nếu không có ngân sách.
  static String? budget(RequestFormValues values) {
    final parsed = values.parsedBudget;
    final min = parsed.min;
    final max = parsed.max;
    if (min == null && max == null) return null;
    final amount = min != null && max != null && min != max
        ? '${_amount(min)}–${_amount(max)}'
        : _amount(max ?? min!);
    return _withCurrency(amount, values.currency);
  }

  /// "$55" (USD/EUR/GBP có ký hiệu) hoặc "550000 VND".
  static String money(double value, String currency) =>
      _withCurrency(_amount(value), currency);

  static String _amount(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : '$v';

  static String _withCurrency(String amount, String currency) {
    final symbol = switch (currency.toUpperCase()) {
      'USD' => r'$',
      'EUR' => '€',
      'GBP' => '£',
      _ => null,
    };
    return symbol == null ? '$amount $currency' : '$symbol$amount';
  }

  /// Một dòng tóm tắt: "At my home · Sat 24 – Sun 25 Oct · $60–80".
  static String summary(RequestFormValues values, String locale) => [
    where(values),
    when(values, locale),
    budget(values),
  ].whereType<String>().join(' · ');

  /// Câu đầu của mô tả — làm "tiêu đề" ngắn cho thẻ request.
  static String headline(String description) {
    final text = description.trim();
    final match = RegExp(r'^(.+?[.!?。！？])(\s|$)').firstMatch(text);
    // Bỏ dấu chấm cuối cho gọn như tiêu đề (giữ ? / !).
    return (match?.group(1) ?? text).trim().replaceFirst(RegExp(r'[.。]$'), '');
  }

  /// Tên ngôn ngữ (tiếng Anh) theo mã của app, vd `vi` → "Vietnamese".
  static String? languageName(String? code) =>
      code == null ? null : requestLanguageByCode(code)?.name;

  /// 0:09 / 1:05
  static String duration(Duration duration) {
    final seconds = duration.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
