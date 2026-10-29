import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../../domain/entities/my_request_entity.dart';
import '../../request_formatters.dart';
import 'my_request_formatters.dart';
import 'offer_avatar.dart';

/// Thẻ request — tab Active: số offer mới, ngày đăng, chip, dải provider + "Compare";
/// bấm thẻ → trang Offers. Tab Closed: "Completed" / "Booked with …" hoặc trạng thái đóng.
class MyRequestCard extends StatelessWidget {
  final MyRequestEntity request;

  /// null = chưa tải (hoặc request không có offer).
  final List<RequestOfferEntity>? offers;

  /// Mở trang "Offers" (bấm thẻ hoặc "Compare").
  final VoidCallback? onOpen;

  const MyRequestCard({
    super.key,
    required this.request,
    this.offers,
    this.onOpen,
  });

  RequestOfferEntity? get _booking {
    final booked = offers?.where((o) => o.isBooked).toList() ?? const [];
    if (booked.isEmpty) return null;
    return booked.firstWhere(
      (o) => o.status == 'completed',
      orElse: () => booked.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.languageCode;
    final closed = request.isClosed;
    final booking = _booking;
    final liveOffers = (offers ?? const <RequestOfferEntity>[])
        .where((o) => o.status != 'cancelled')
        .toList();

    final subtitle = closed
        ? _closedSubtitle(locale, booking)
        : [
            if (request.createdAt != null)
              MyRequestFormatters.posted(request.createdAt!, locale),
            MyRequestFormatters.responded(request.respondersCount),
          ].whereType<String>().join(' · ');

    final details = request.details;
    final chips = <Widget>[
      if (!closed && request.hasVoice)
        _Chip(
          icon: Icons.mic_none_rounded,
          label: LocaleKeys.myRequestsVoiceNote.tr(),
        ),
      for (final type in details.deliveryTypes)
        _Chip(label: MyRequestFormatters.delivery(type)),
      if (!closed)
        for (final text in [
          MyRequestFormatters.when(details, locale),
          MyRequestFormatters.budget(details),
        ])
          if (text != null) _Chip(label: text),
    ];

    return Material(
      color: theme.surface(context),
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: onOpen,
        child: Container(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: theme.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      RequestFormatters.headline(request.description),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.lightBodyLargeBold.copyWith(
                        height: 1.3,
                        color: theme.textPrimary(context),
                      ),
                    ),
                  ),
                  Gap(10.w),
                  _StatusBadge(
                    request: request,
                    offers: offers,
                    booking: booking,
                  ),
                ],
              ),
              if (subtitle.isNotEmpty) ...[
                Gap(4.h),
                Text(
                  subtitle,
                  style: AppTextStyle.lightBodySmallRegular.copyWith(
                    height: 1.35,
                    color: theme.textSecondary(context),
                  ),
                ),
              ],
              if (chips.isNotEmpty) ...[
                Gap(10.h),
                Wrap(spacing: 6.w, runSpacing: 6.h, children: chips),
              ],
              if (!closed && liveOffers.isNotEmpty) ...[
                Gap(12.h),
                Divider(height: 1, color: theme.border(context)),
                Gap(10.h),
                _OffersStrip(
                  offers: liveOffers,
                  currency: details.currency,
                  onCompare: onOpen,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "Booked with Hana Le · 12 Oct" hoặc "Closed · 12 Oct".
  String _closedSubtitle(String locale, RequestOfferEntity? booking) {
    if (booking != null) {
      final date = booking.paidAt ?? booking.createdAt;
      return [
        LocaleKeys.myRequestsBookedWith.tr(args: [booking.sellerName]),
        if (date != null) MyRequestFormatters.shortDate(date, locale),
      ].join(' · ');
    }
    final date = request.updatedAt ?? request.createdAt;
    return [
      _closedStatusLabel(request.status),
      if (date != null) MyRequestFormatters.shortDate(date, locale),
    ].join(' · ');
  }
}

String _closedStatusLabel(String status) => switch (status) {
  'expired' => LocaleKeys.myRequestsStatusExpired.tr(),
  'canceled' || 'cancelled' => LocaleKeys.myRequestsStatusCanceled.tr(),
  _ => LocaleKeys.myRequestsStatusClosed.tr(),
};

class _StatusBadge extends StatelessWidget {
  final MyRequestEntity request;
  final List<RequestOfferEntity>? offers;
  final RequestOfferEntity? booking;

  const _StatusBadge({
    required this.request,
    required this.offers,
    required this.booking,
  });

  static const _successBg = Color(0xFFE3F3EA);
  static const _successText = Color(0xFF1F6B45);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String label, bool success) = switch (booking?.status) {
      'completed' => (LocaleKeys.myRequestsStatusCompleted.tr(), true),
      'accepted' ||
      'delivered' => (LocaleKeys.myRequestsStatusBooked.tr(), true),
      _ when request.isClosed => (_closedStatusLabel(request.status), false),
      _ => (_activeLabel(), false),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: success ? _successBg : theme.muted(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyle.lightBodySmallSemiBold.copyWith(
          color: success ? _successText : theme.textPrimary(context),
        ),
      ),
    );
  }

  /// "3 new offers" → "3 offers" → "In review" (chờ duyệt) → "Waiting for offers".
  String _activeLabel() {
    final loaded = offers;
    final fresh = loaded?.where((o) => o.isNew).length ?? 0;
    if (fresh > 0) {
      return fresh == 1
          ? LocaleKeys.myRequestsNewOffersOne.tr()
          : LocaleKeys.myRequestsNewOffersMany.tr(args: ['$fresh']);
    }
    final total = loaded?.length ?? request.offersCount;
    if (total > 0) {
      return total == 1
          ? LocaleKeys.myRequestsOffersOne.tr()
          : LocaleKeys.myRequestsOffersMany.tr(args: ['$total']);
    }
    if (request.status == 'pending') {
      return LocaleKeys.myRequestsStatusPending.tr();
    }
    return LocaleKeys.myRequestsWaiting.tr();
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _Chip({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: theme.muted(context),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13.r, color: theme.textPrimary(context)),
            Gap(3.w),
          ],
          Text(
            label,
            style: AppTextStyle.lightBodySmallMedium.copyWith(
              color: theme.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar chồng nhau + "From $55 to $80 · best rated 4.9" + "Compare".
class _OffersStrip extends StatelessWidget {
  final List<RequestOfferEntity> offers;
  final String currency;
  final VoidCallback? onCompare;

  const _OffersStrip({
    required this.offers,
    required this.currency,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = offers.take(3).toList();
    final size = 28.r;
    final overlap = 8.r;
    final summary = [
      MyRequestFormatters.priceRange(offers, currency),
      MyRequestFormatters.bestRated(offers),
    ].whereType<String>().join(' · ');
    return Row(
      children: [
        SizedBox(
          width: size + (shown.length - 1) * (size - overlap),
          height: size,
          child: Stack(
            children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: i * (size - overlap),
                  child: OfferAvatar(offer: shown[i], index: i, size: size),
                ),
            ],
          ),
        ),
        Gap(10.w),
        Expanded(
          child: Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.lightBodySmallRegular.copyWith(
              height: 1.35,
              color: theme.textSecondary(context),
            ),
          ),
        ),
        Gap(8.w),
        GestureDetector(
          onTap: onCompare,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 6.h),
            child: Text(
              LocaleKeys.myRequestsCompare.tr(),
              style: AppTextStyle.lightBodyMediumBold.copyWith(
                color: theme.textPrimary(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
