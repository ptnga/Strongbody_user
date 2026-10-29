import 'package:easy_localization/easy_localization.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';

import '../../../domain/entities/request_form_values.dart';
import '../../../domain/entities/request_options.dart';
import '../../bloc/matching_providers/matching_providers_bloc.dart';
import '../../request_formatters.dart';

/// Nhãn ngắn trên màn Matching providers (chip lọc, tag thẻ, giá, lịch rảnh).
class ProviderFormatters {
  ProviderFormatters._();

  static String delivery(RequestDeliveryType type) => switch (type) {
    RequestDeliveryType.remote => LocaleKeys.providersChipOnline.tr(),
    RequestDeliveryType.atHome => LocaleKeys.providersChipAtHome.tr(),
    RequestDeliveryType.atClinic => LocaleKeys.providersChipAtClinic.tr(),
  };

  /// Tên ngôn ngữ theo giao diện: tiếng Anh dùng tên tiếng Anh, còn lại dùng tên bản địa.
  static String languageName(String code, String uiLocale) {
    final option =
        requestLanguageByCode(code) ??
        requestLanguages
            .where((l) => code.toLowerCase().startsWith(l.code.toLowerCase()))
            .firstOrNull;
    if (option == null) return code;
    return uiLocale == 'en' ? option.name : option.nativeName;
  }

  static String chip(
    ProviderFilter filter,
    ProviderRequestContext context,
    String uiLocale,
  ) {
    switch (filter) {
      case ProviderFilter.delivery:
        return context.deliveryTypes.map(delivery).join(' · ');
      case ProviderFilter.dates:
        final start = context.startDate!;
        if (_isUpcomingWeekend(start, context.endDate)) {
          return LocaleKeys.providersChipThisWeekend.tr();
        }
        return RequestFormatters.when(
              RequestFormValues(deadline: start, endDate: context.endDate),
              uiLocale,
            ) ??
            '';
      case ProviderFilter.budget:
        return LocaleKeys.providersChipUnder.tr(
          args: [money(context.maxBudget!, context.currency)],
        );
      case ProviderFilter.language:
        return LocaleKeys.providersChipSpeaks.tr(
          args: [languageName(context.languageCode!, uiLocale)],
        );
      case ProviderFilter.topRated:
        return LocaleKeys.providersChipTopRated.tr();
    }
  }

  /// Khoảng ngày là thứ 7 – CN của tuần này / tuần tới (trong 7 ngày).
  static bool _isUpcomingWeekend(DateTime start, DateTime? end) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final days = startDay.difference(today).inDays;
    final last = end ?? start;
    return start.weekday == DateTime.saturday &&
        (last.weekday == DateTime.sunday ||
            last.weekday == DateTime.saturday) &&
        days >= 0 &&
        days <= 6;
  }

  /// "$65" / "€40" / "500000 VND".
  static String money(double amount, String? currency) {
    final value = amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    return switch ((currency ?? 'USD').toUpperCase()) {
      'USD' || '' => '\$$value',
      'EUR' => '€$value',
      'GBP' => '£$value',
      final code => '$value $code',
    };
  }

  /// "Sat 24 Oct, 09:00"
  static String slot(DateTime time, String uiLocale) =>
      DateFormat('EEE d MMM, HH:mm', uiLocale).format(time);
}
