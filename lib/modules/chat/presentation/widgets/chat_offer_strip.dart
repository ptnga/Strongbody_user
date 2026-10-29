import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/modules/checkout/presentation/offer_payment_guard.dart';
import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/request_formatters.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/request_offers_page_args.dart';

import 'package:strongbody_buyer/modules/checkout/presentation/widgets/offer_checkout_sheet.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/my_request_entity.dart';

import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/chat_session_entity.dart';

/// Nhãn + màu trạng thái offer ("Accepted & Paid" xanh…).
(String, bool) offerStatusLabel(ChatOfferEntity offer) =>
    switch (offer.status) {
      'completed' => (LocaleKeys.myRequestsStatusCompleted.tr(), true),
      'accepted' when offer.isPaid => (
        LocaleKeys.chatOfferAcceptedPaid.tr(),
        true,
      ),
      'accepted' => (LocaleKeys.chatOfferAccepted.tr(), true),
      'rejected' => (LocaleKeys.chatOfferDeclined.tr(), false),
      'cancelled' ||
      'canceled' => (LocaleKeys.myRequestsOfferCancelled.tr(), false),
      _ => (LocaleKeys.chatOfferPending.tr(), false),
    };

/// "Sat 24 Oct, 09:00 · at your home" (lịch + nơi của request); không có thì giá · tiêu đề.
String offerSummary(ChatOfferEntity offer, String locale) {
  final when = offer.scheduledAt;
  final where = switch (offer.deliveryType) {
    'at_home' => LocaleKeys.chatOfferWhereHome.tr(),
    'remote' => LocaleKeys.chatOfferWhereOnline.tr(),
    'at_clinic' => LocaleKeys.chatOfferWhereClinic.tr(),
    _ => null,
  };
  final schedule = [
    if (when != null) DateFormat('EEE d MMM, HH:mm', locale).format(when),
    ?where,
  ];
  if (schedule.isNotEmpty) return schedule.join(' · ');
  return [
    if (offer.price case final p? when p > 0) RequestFormatters.money(p, 'USD'),
    if (offer.title.isNotEmpty) offer.title,
  ].join(' · ');
}

/// "Details" / chạm thẻ offer: offer cho request → trang Offers của request, in đậm offer
/// này; offer tạo trong chat → sheet chi tiết.
void openChatOffer(
  BuildContext context,
  ChatOfferEntity offer, {
  ChatPartner? partner,
}) {
  final requestId = offer.requestId;
  AppAnalytics.capture(AnalyticsEvents.chatOfferDetailsTapped, {
    'offer_id': offer.id,
    'request_id': requestId,
  });
  if (requestId == null) {
    showChatOfferSheet(context, offer, partner: partner);
    return;
  }
  context.push(
    RouteName.requestOffers,
    extra: RequestOffersPageArgs(
      requestId: requestId,
      highlightOfferId: offer.id,
    ),
  );
}

/// Dải dưới header: trạng thái offer mới nhất · lịch / nơi · "Details".
class ChatOfferStrip extends StatelessWidget {
  final ChatOfferEntity offer;

  /// Provider của hội thoại — tên / ảnh cho sheet thanh toán.
  final ChatPartner? partner;

  const ChatOfferStrip({super.key, required this.offer, this.partner});

  static const _successBg = Color(0xFFE3F3EA);
  static const _successText = Color(0xFF1F6B45);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, success) = offerStatusLabel(offer);
    final summary = offerSummary(offer, context.locale.languageCode);
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 8.w, 8.h),
      decoration: BoxDecoration(
        color: theme.surface(context),
        border: Border(
          top: BorderSide(color: theme.border(context)),
          bottom: BorderSide(color: theme.border(context)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: success ? _successBg : theme.muted(context),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: success ? _successText : theme.textPrimary(context),
              ),
            ),
          ),
          Gap(10.w),
          Expanded(
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                color: theme.textPrimary(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () => openChatOffer(context, offer, partner: partner),
            style: TextButton.styleFrom(
              foregroundColor: theme.textPrimary(context),
              textStyle: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(LocaleKeys.chatDetails.tr()),
          ),
        ],
      ),
    );
  }
}

/// Chi tiết offer (từ dải đầu chat hoặc thẻ offer trong chat).
Future<void> showChatOfferSheet(
  BuildContext context,
  ChatOfferEntity offer, {
  ChatPartner? partner,
}) {
  final theme = Theme.of(context);
  final rootContext = context;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: theme.surface(context),
    builder: (context) {
      final (label, _) = offerStatusLabel(offer);
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              offer.title.isEmpty
                  ? LocaleKeys.chatOfferTitle.tr()
                  : offer.title,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary(context),
              ),
            ),
            Gap(6.h),
            Text(
              [
                label,
                if (offer.orderNo != null)
                  LocaleKeys.chatOfferOrderNo.tr(args: [offer.orderNo!]),
              ].join(' · '),
              style: TextStyle(
                fontSize: 13.sp,
                color: theme.textSecondary(context),
              ),
            ),
            if (offer.price case final p? when p > 0) ...[
              Gap(12.h),
              Text(
                RequestFormatters.money(p, 'USD'),
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary(context),
                ),
              ),
            ],
            if (offer.description.isNotEmpty) ...[
              Gap(12.h),
              Text(
                offer.description,
                style: TextStyle(
                  fontSize: 14.sp,
                  height: 1.45,
                  color: theme.textPrimary(context),
                ),
              ),
            ],
            if (offer.status == 'pending' &&
                offer.paymentStatus != 'paid' &&
                !OfferPaymentGuard.isSubmitted(offer.id)) ...[
              Gap(20.h),
              SizedBox(
                height: 48.h,
                child: FilledButton(
                  // Offer tạo trong chat → cùng luồng thanh toán như trang Offers.
                  onPressed: () {
                    Navigator.of(context).pop();
                    showOfferCheckoutSheet(
                      rootContext,
                      source: 'chat',
                      offer: RequestOfferEntity(
                        id: offer.id,
                        status: offer.status,
                        sellerId: offer.sellerId ?? partner?.id,
                        sellerName: partner?.name ?? '',
                        sellerAvatar: partner?.avatar,
                        title: offer.title,
                        description: offer.description,
                        price: offer.price,
                        paymentStatus: offer.paymentStatus,
                        createdAt: offer.createdAt,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.secondary(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(LocaleKeys.offersAcceptPay.tr()),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
