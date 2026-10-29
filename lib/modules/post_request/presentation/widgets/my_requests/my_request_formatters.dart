import 'package:easy_localization/easy_localization.dart';

import 'package:strongbody_buyer/components/initials_avatar.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';

import '../../../domain/entities/my_request_entity.dart';
import '../../../domain/entities/request_form_values.dart';
import '../../request_formatters.dart';

/// Chuỗi trên thẻ "My requests": ngày đăng, chip, khoảng giá offer.
class MyRequestFormatters {
  MyRequestFormatters._();

  /// "Posted today, 08:12" / "Posted yesterday, 08:12" / "Posted 12 Oct, 08:12".
  static String posted(DateTime createdAt, String locale, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final time = DateFormat.Hm(locale).format(createdAt);
    final days = today.difference(_day(createdAt)).inDays;
    return switch (days) {
      0 => LocaleKeys.myRequestsPostedToday.tr(args: [time]),
      1 => LocaleKeys.myRequestsPostedYesterday.tr(args: [time]),
      _ => LocaleKeys.myRequestsPostedOn.tr(
        args: ['${shortDate(createdAt, locale, now: now)}, $time'],
      ),
    };
  }

  /// "12 Oct" (thêm năm nếu khác năm nay).
  static String shortDate(DateTime date, String locale, {DateTime? now}) {
    final sameYear = date.year == (now ?? DateTime.now()).year;
    return DateFormat(sameYear ? 'd MMM' : 'd MMM y', locale).format(date);
  }

  /// "12 providers responded"; null khi chưa ai phản hồi.
  static String? responded(int count) => switch (count) {
    <= 0 => null,
    1 => LocaleKeys.myRequestsRespondedOne.tr(),
    _ => LocaleKeys.myRequestsRespondedMany.tr(args: ['$count']),
  };

  /// Chip ngắn: "Online" / "At home" / "At a clinic".
  static String delivery(RequestDeliveryType type) => switch (type) {
    RequestDeliveryType.remote => LocaleKeys.requestDeliveryOnline.tr(),
    RequestDeliveryType.atHome => LocaleKeys.myRequestsChipAtHome.tr(),
    RequestDeliveryType.atClinic => LocaleKeys.myRequestsChipAtClinic.tr(),
  };

  /// "Today" / "Tomorrow" / "This weekend" / "Sat 24 – Sun 25 Oct"; null nếu không có ngày.
  static String? when(
    RequestFormValues details,
    String locale, {
    DateTime? now,
  }) {
    final start = details.deadline;
    if (start == null) return null;
    final first = _day(start);
    final last = _day(details.endDate ?? start);
    final today = _day(now ?? DateTime.now());
    if (first == last) {
      final days = first.difference(today).inDays;
      if (days == 0) return LocaleKeys.myRequestsWhenToday.tr();
      if (days == 1) return LocaleKeys.myRequestsWhenTomorrow.tr();
    }
    // Cuối tuần này: T7–CN của tuần hiện tại (hôm nay là CN thì chỉ còn hôm nay).
    final saturday = today.weekday == DateTime.sunday
        ? today
        : today.add(Duration(days: DateTime.saturday - today.weekday));
    final sunday = today.weekday == DateTime.sunday
        ? today
        : saturday.add(const Duration(days: 1));
    if (!first.isBefore(saturday) && !last.isAfter(sunday)) {
      return LocaleKeys.myRequestsWhenWeekend.tr();
    }
    return RequestFormatters.when(details, locale);
  }

  /// "$60–80" / "Under $100" (min = 0); null nếu không có ngân sách.
  static String? budget(RequestFormValues details) {
    final parsed = details.parsedBudget;
    final max = parsed.max;
    if (parsed.min == 0 && max != null && max > 0) {
      return LocaleKeys.myRequestsBudgetUnder.tr(
        args: [RequestFormatters.money(max, details.currency)],
      );
    }
    return RequestFormatters.budget(details);
  }

  /// "From $55 to $80" / "From $55"; null nếu offer không có giá.
  static String? priceRange(
    List<RequestOfferEntity> offers,
    String fallbackCurrency,
  ) {
    final priced = offers.where((o) => (o.price ?? 0) > 0).toList()
      ..sort((a, b) => a.price!.compareTo(b.price!));
    if (priced.isEmpty) return null;
    String money(RequestOfferEntity o) => RequestFormatters.money(
      o.price!,
      (o.currency?.isNotEmpty ?? false) ? o.currency! : fallbackCurrency,
    );
    final low = money(priced.first);
    final high = money(priced.last);
    return low == high
        ? LocaleKeys.myRequestsPriceFrom.tr(args: [low])
        : LocaleKeys.myRequestsPriceRange.tr(args: [low, high]);
  }

  /// "best rated 4.9"; null nếu chưa offer nào có đánh giá.
  static String? bestRated(List<RequestOfferEntity> offers) {
    final ratings = offers.map((o) => o.rating ?? 0).where((r) => r > 0);
    if (ratings.isEmpty) return null;
    final best = ratings.reduce((a, b) => a > b ? a : b);
    return LocaleKeys.myRequestsBestRated.tr(args: [best.toStringAsFixed(1)]);
  }

  /// Buổi hẹn của offer theo request: "Sat 24 Oct · 09:00–10:00"; null nếu request không có ngày.
  static String? offerSession(RequestOfferEntity offer, String locale) {
    final details = offer.request?.details;
    final date = details?.deadline;
    if (details == null || date == null) return null;
    final day = DateFormat('EEE d MMM', locale).format(date);
    final range = details.schedule[WeekDay.fromDate(date)]?.firstOrNull;
    return range == null ? day : '$day · ${range.from}–${range.to}';
  }

  /// "Mai Pham" → "MP".
  static String initials(String name) => InitialsAvatar.initials(name);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
