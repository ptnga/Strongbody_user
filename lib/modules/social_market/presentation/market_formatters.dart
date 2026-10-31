import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_options.dart';

import '../domain/entities/market_category.dart';
import '../domain/entities/market_feed_entities.dart';
import '../domain/entities/market_listing_entities.dart';

/// Chữ hiển thị của Social Market (nhãn đã dịch từ messages web).
class MarketFormatters {
  MarketFormatters._();

  static String categoryLabel(MarketCategory c) => switch (c) {
    MarketCategory.longevity => LocaleKeys.marketLongevity.tr(),
    MarketCategory.healthProAdvisory => LocaleKeys.marketHealthProAdvisory.tr(),
    MarketCategory.personalHelper => LocaleKeys.marketPersonalHelper.tr(),
  };

  /// Tên marketplace trên header (web `categoryMarketplace.<key>.brand`).
  static String brand(MarketCategory c) => switch (c) {
    MarketCategory.longevity => LocaleKeys.marketBrandLongevity.tr(),
    MarketCategory.healthProAdvisory =>
      LocaleKeys.marketBrandHealthProAdvisory.tr(),
    MarketCategory.personalHelper => LocaleKeys.marketBrandPersonalHelper.tr(),
  };

  /// Hero riêng của category; thiếu thì dùng copy trang chủ (web `categoryHero`).
  static ({String tagline, String title, String? subtitle}) hero(
    MarketCategory c,
  ) => switch (c) {
    MarketCategory.longevity => (
      tagline: LocaleKeys.marketHeroTagline.tr(),
      title: LocaleKeys.marketLongevityHeroTitle.tr(),
      subtitle: LocaleKeys.marketLongevityHeroSubtitle.tr(),
    ),
    _ => (
      tagline: LocaleKeys.marketHeroTagline.tr(),
      title: LocaleKeys.marketHeroTitle.tr(),
      subtitle: null,
    ),
  };

  // ------------------------------------------------------------- delivery

  static String serviceDelivery(MarketDeliveryType type) => switch (type) {
    MarketDeliveryType.remote => LocaleKeys.marketDeliveryRemote.tr(),
    MarketDeliveryType.atOffice => LocaleKeys.marketDeliveryAtOffice.tr(),
    MarketDeliveryType.atHome => LocaleKeys.marketDeliveryAtHome.tr(),
  };

  /// Icon theo hình thức (web `DELIVERY_ICON`).
  static IconData deliveryIcon(MarketDeliveryType type) => switch (type) {
    MarketDeliveryType.remote => Icons.videocam_outlined,
    MarketDeliveryType.atOffice => Icons.storefront_outlined,
    MarketDeliveryType.atHome => Icons.home_outlined,
  };

  /// `forms.deliveryTypes.*` (request / offer): remote, at_home, at_clinic, at_office, all.
  static String formDelivery(String value) => switch (value) {
    'remote' => LocaleKeys.marketFormDeliveryRemote.tr(),
    'at_home' => LocaleKeys.marketFormDeliveryAtHome.tr(),
    'at_clinic' => LocaleKeys.marketFormDeliveryAtClinic.tr(),
    'at_office' => LocaleKeys.marketFormDeliveryAtOffice.tr(),
    'all' => LocaleKeys.marketFormDeliveryAll.tr(),
    _ => humanize(value),
  };

  /// Hình thức của request: "all" → liệt kê ra (web `deliveryLabel`).
  static String requestDelivery(String value) => value == 'all'
      ? ['remote', 'at_home', 'at_clinic'].map(formDelivery).join(', ')
      : formDelivery(value);

  static String pricingUnit(String value) => switch (value) {
    'service' => LocaleKeys.marketPricingUnitService.tr(),
    'session' => LocaleKeys.marketPricingUnitSession.tr(),
    'package' => LocaleKeys.marketPricingUnitPackage.tr(),
    'day' => LocaleKeys.marketPricingUnitDay.tr(),
    'week' => LocaleKeys.marketPricingUnitWeek.tr(),
    'month' => LocaleKeys.marketPricingUnitMonth.tr(),
    _ => humanize(value),
  };

  static String durationUnit(String value) => switch (value) {
    'min' => LocaleKeys.marketDurationUnitMin.tr(),
    'hour' => LocaleKeys.marketDurationUnitHour.tr(),
    'day' => LocaleKeys.marketDurationUnitDay.tr(),
    'week' => LocaleKeys.marketDurationUnitWeek.tr(),
    'month' => LocaleKeys.marketDurationUnitMonth.tr(),
    _ => humanize(value),
  };

  static const weekDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  static String weekDay(String day) => switch (day) {
    'mon' => LocaleKeys.marketWeekDayMon.tr(),
    'tue' => LocaleKeys.marketWeekDayTue.tr(),
    'wed' => LocaleKeys.marketWeekDayWed.tr(),
    'thu' => LocaleKeys.marketWeekDayThu.tr(),
    'fri' => LocaleKeys.marketWeekDayFri.tr(),
    'sat' => LocaleKeys.marketWeekDaySat.tr(),
    'sun' => LocaleKeys.marketWeekDaySun.tr(),
    _ => humanize(day),
  };

  static String schedule(List<MarketScheduleSlot> slots) =>
      slots.map((s) => '${weekDay(s.day)} ${s.times}').join(' · ');

  /// "at_office" → "At Office".
  static String humanize(String value) => value
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'\b\w'), (m) => m[0]!.toUpperCase());

  /// Mã ngôn ngữ (form request lưu code) → tên; giá trị cũ là tên thì giữ.
  static String languageName(String code) =>
      requestLanguageByCode(code)?.name ??
      requestLanguageByCode(code.split('-').first)?.name ??
      humanize(code);

  /// "5 yrs"; rỗng khi chưa khai.
  static String years(int? years) =>
      years == null || years <= 0 ? '' : LocaleKeys.marketYears.plural(years);

  static String budget(MarketBudget budget) => switch (budget) {
    BudgetExact(:final amount) => amount,
    BudgetRange(:final min, :final max) => '$min – $max',
    BudgetFrom(:final min) => LocaleKeys.marketBudgetFrom.tr(
      namedArgs: {'min': min},
    ),
    BudgetUpTo(:final max) => LocaleKeys.marketBudgetUpTo.tr(
      namedArgs: {'max': max},
    ),
  };

  /// Thời gian tương đối như `Intl.RelativeTimeFormat(numeric: 'auto')` của web.
  static String timeAgo(DateTime? date, {DateTime? now}) {
    if (date == null) return LocaleKeys.marketAgoNow.tr();
    final diff = (now ?? DateTime.now()).difference(date);
    final minutes = diff.inMinutes;
    final hours = diff.inHours;
    final days = diff.inDays;
    if (diff.inSeconds < 60) return LocaleKeys.marketAgoNow.tr();
    if (minutes < 60) return LocaleKeys.marketAgoMinutes.plural(minutes);
    if (hours < 24) return LocaleKeys.marketAgoHours.plural(hours);
    if (days < 7) {
      return days == 1
          ? LocaleKeys.marketAgoYesterday.tr()
          : LocaleKeys.marketAgoDays.plural(days);
    }
    if (days < 30) {
      final weeks = days ~/ 7;
      return weeks == 1
          ? LocaleKeys.marketAgoLastWeek.tr()
          : LocaleKeys.marketAgoWeeks.plural(weeks);
    }
    if (days < 365) {
      final months = days ~/ 30;
      return months == 1
          ? LocaleKeys.marketAgoLastMonth.tr()
          : LocaleKeys.marketAgoMonths.plural(months);
    }
    final years = days ~/ 365;
    return years == 1
        ? LocaleKeys.marketAgoLastYear.tr()
        : LocaleKeys.marketAgoYears.plural(years);
  }

  /// Dòng "N interested · N saved · N contacted" (web `EngagementCounts`).
  static String engagement(EngagementState s, {bool hideLikes = false}) => [
    if (!hideLikes && s.likes > 0)
      LocaleKeys.marketInterested.tr(namedArgs: {'count': '${s.likes}'}),
    if (s.saves > 0)
      LocaleKeys.marketSaved.tr(namedArgs: {'count': '${s.saves}'}),
    if (s.contacts > 0)
      LocaleKeys.marketContacted.tr(namedArgs: {'count': '${s.contacts}'}),
  ].join(' · ');
}
