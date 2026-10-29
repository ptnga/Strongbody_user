import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';

import '../../../domain/entities/my_request_entity.dart';
import '../../../domain/entities/request_form_values.dart';
import '../../request_formatters.dart';
import '../common/voice_note_player.dart';
import 'my_request_formatters.dart';
import 'offer_avatar.dart';

/// Thẻ offer ở trang "Offers": provider, giá, nơi làm, voice + lời nhắn, Reply / Accept & Pay.
class OfferCard extends StatelessWidget {
  final RequestOfferEntity offer;

  /// Cách nhận của request — dựng dòng "At your home" / "Online".
  final List<RequestDeliveryType> deliveryTypes;
  final String fallbackCurrency;

  /// Thẻ đầu danh sách (khớp nhất theo cách sắp xếp đang chọn) — viền đậm.
  final bool highlighted;
  final int index;
  final VoidCallback onReply;
  final VoidCallback onAccept;

  const OfferCard({
    super.key,
    required this.offer,
    required this.deliveryTypes,
    required this.fallbackCurrency,
    required this.index,
    required this.onReply,
    required this.onAccept,
    this.highlighted = false,
  });

  /// "At your home" / "Online" / "At a clinic, District 3" / chỉ địa chỉ.
  String? get _where {
    final address = offer.address;
    final type = deliveryTypes.length == 1 ? deliveryTypes.first : null;
    return switch (type) {
      RequestDeliveryType.atHome => LocaleKeys.offersWhereHome.tr(),
      RequestDeliveryType.remote => LocaleKeys.requestDeliveryOnline.tr(),
      RequestDeliveryType.atClinic => [
        LocaleKeys.offersWhereClinic.tr(),
        ?address,
      ].join(', '),
      null => address,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = offer.rating ?? 0;
    final reviews = offer.reviewCount ?? 0;
    final meta = [
      if (rating > 0)
        reviews > 0
            ? '${rating.toStringAsFixed(1)} ($reviews)'
            : rating.toStringAsFixed(1),
      ?offer.profession,
    ].join(' · ');
    final price = offer.price;
    final where = _where;
    final session = MyRequestFormatters.offerSession(
      offer,
      context.locale.languageCode,
    );
    final voice = offer.voiceUrl;
    final message = offer.description.isNotEmpty
        ? offer.description
        : offer.title;

    return Opacity(
      opacity: offer.isCancelled ? 0.55 : 1,
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: theme.surface(context),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: highlighted
                ? theme.textPrimary(context)
                : theme.border(context),
            width: highlighted ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OfferAvatar(offer: offer, index: index, size: 42.r),
                Gap(10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              offer.sellerName.isEmpty ? '—' : offer.sellerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                color: theme.textPrimary(context),
                              ),
                            ),
                          ),
                          if (offer.sellerVerified) ...[
                            Gap(4.w),
                            Icon(
                              Icons.verified_rounded,
                              size: 15.r,
                              color: Colour.success,
                              semanticLabel: LocaleKeys.offersVerified.tr(),
                            ),
                          ],
                        ],
                      ),
                      if (meta.isNotEmpty) ...[
                        Gap(2.h),
                        Text.rich(
                          TextSpan(
                            children: [
                              if (rating > 0)
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 2.w),
                                    child: Icon(
                                      Icons.star_rounded,
                                      size: 14.r,
                                      color: theme.textPrimary(context),
                                    ),
                                  ),
                                ),
                              TextSpan(text: meta),
                            ],
                          ),
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 13.sp,
                            height: 1.3,
                            color: theme.textSecondary(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (price != null && price > 0) ...[
                  Gap(8.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        RequestFormatters.money(
                          price,
                          (offer.currency?.isNotEmpty ?? false)
                              ? offer.currency!
                              : fallbackCurrency,
                        ),
                        style: TextStyle(
                          fontSize: 20.sp,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary(context),
                        ),
                      ),
                      Text(
                        LocaleKeys.offersPerSession.tr(),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: theme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            if (session != null) ...[
              Gap(10.h),
              _InfoRow(icon: Icons.calendar_today_outlined, text: session),
            ],
            if (where != null && where.isNotEmpty) ...[
              Gap(session == null ? 10.h : 6.h),
              _InfoRow(icon: Icons.location_on_outlined, text: where),
            ],
            if (voice != null || message.isNotEmpty) ...[
              Gap(10.h),
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: theme.muted(context),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (voice != null) VoiceNotePlayer(path: voice),
                    if (voice != null && message.isNotEmpty) Gap(10.h),
                    if (message.isNotEmpty)
                      Text(
                        '“$message”',
                        style: TextStyle(
                          fontSize: 14.sp,
                          height: 1.4,
                          color: theme.textPrimary(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            Gap(12.h),
            _Actions(offer: offer, onReply: onReply, onAccept: onAccept),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16.r, color: theme.textSecondary(context)),
        Gap(6.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.sp,
              color: theme.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Reply + Accept & Pay; offer đã đặt / đã huỷ thì nút phải thành nhãn trạng thái.
class _Actions extends StatelessWidget {
  final RequestOfferEntity offer;
  final VoidCallback onReply;
  final VoidCallback onAccept;

  const _Actions({
    required this.offer,
    required this.onReply,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.r),
    );
    final textStyle = TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700);
    final closedLabel = switch (offer.status) {
      'completed' => LocaleKeys.myRequestsStatusCompleted.tr(),
      'accepted' || 'delivered' => LocaleKeys.myRequestsStatusBooked.tr(),
      'cancelled' || 'canceled' => LocaleKeys.myRequestsOfferCancelled.tr(),
      _ => null,
    };
    return SizedBox(
      height: 44.h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 4,
            child: OutlinedButton(
              onPressed: onReply,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.textPrimary(context),
                side: BorderSide(color: theme.border(context)),
                shape: shape,
                textStyle: textStyle,
              ),
              child: Text(LocaleKeys.offersReply.tr()),
            ),
          ),
          Gap(8.w),
          Expanded(
            flex: 5,
            child: FilledButton(
              onPressed: closedLabel == null ? onAccept : null,
              style: FilledButton.styleFrom(
                backgroundColor: theme.secondary(context),
                foregroundColor: Colors.white,
                disabledBackgroundColor: theme.muted(context),
                disabledForegroundColor: theme.textSecondary(context),
                shape: shape,
                textStyle: textStyle,
              ),
              child: Text(closedLabel ?? LocaleKeys.offersAcceptPay.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
