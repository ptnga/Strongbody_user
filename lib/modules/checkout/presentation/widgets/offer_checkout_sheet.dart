import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_formatters.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_page_args.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/my_request_entity.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/widgets/my_requests/my_request_formatters.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../bloc/offer_checkout/offer_checkout_bloc.dart';

String? offerSessionLabel(RequestOfferEntity offer, String locale) =>
    MyRequestFormatters.offerSession(offer, locale);

String _money(double value, String currency) =>
    NumberFormat.simpleCurrency(locale: 'en_US', name: currency).format(value);

/// "Accept & Pay" → sheet thanh toán; `true` = đã trả (hoặc đang chờ xác nhận).
/// [source] = offers|chat (analytics).
Future<bool> showOfferCheckoutSheet(
  BuildContext context, {
  required RequestOfferEntity offer,
  required String source,
}) async {
  AppAnalytics.capture(AnalyticsEvents.checkoutOpened, {
    'source': source,
    'offer_id': offer.id,
    'request_id': offer.requestId ?? offer.request?.id,
    'seller_id': offer.sellerId,
    'price': offer.price,
    'currency': 'USD',
  });
  final paid = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    // Vuốt xuống gọi pop thẳng, bỏ qua PopScope → khoá kéo để không đóng giữa lúc trả
    // (Stripe vẫn trừ tiền nhưng kết quả bị bỏ). Chạm nền ngoài vẫn theo PopScope.
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: Theme.of(context).surface(context),
    builder: (_) => BlocProvider(
      create: (_) =>
          getIt<OfferCheckoutBloc>(param1: offer)
            ..add(const OfferCheckoutStarted()),
      child: _OfferCheckoutSheet(offer: offer),
    ),
  );
  if (paid != true) {
    AppAnalytics.capture(AnalyticsEvents.checkoutDismissed, {
      'offer_id': offer.id,
    });
  }
  return paid ?? false;
}

class _OfferCheckoutSheet extends StatelessWidget {
  final RequestOfferEntity offer;

  const _OfferCheckoutSheet({required this.offer});

  String get _first => ChatFormatters.firstName(offer.sellerName);

  void _message(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop(true);
    final sellerId = offer.sellerId;
    if (sellerId == null) return;
    router.push(
      RouteName.chat,
      extra: ChatPageArgs(
        partnerId: sellerId,
        name: offer.sellerName,
        avatar: offer.sellerAvatar,
        profession: offer.profession,
        focusOfferId: offer.id,
        source: 'checkout',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OfferCheckoutBloc, OfferCheckoutState>(
      listenWhen: (a, b) => a.noticeId != b.noticeId && b.notice != null,
      listener: (context, state) => ToastUtil.showError(switch (state.notice!) {
        OfferCheckoutNotice.payFailed => LocaleKeys.checkoutFailed.tr(),
        OfferCheckoutNotice.addCardFailed =>
          LocaleKeys.checkoutAddCardFailed.tr(),
      }),
      // Đang trả tiền → không cho đóng sheet (back / vuốt).
      builder: (context, state) => PopScope(
        canPop: state.status != OfferCheckoutStatus.paying,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: switch (state.status) {
              OfferCheckoutStatus.loading => Padding(
                padding: EdgeInsets.symmetric(vertical: 48.h),
                child: const Center(child: CupertinoActivityIndicator()),
              ),
              OfferCheckoutStatus.paid ||
              OfferCheckoutStatus.pending => _ResultView(
                offer: offer,
                pending: state.status == OfferCheckoutStatus.pending,
                firstName: _first,
                onMessage: () => _message(context),
              ),
              _ => _QuoteView(offer: offer, state: state, firstName: _first),
            },
          ),
        ),
      ),
    );
  }
}

class _QuoteView extends StatelessWidget {
  final RequestOfferEntity offer;
  final OfferCheckoutState state;
  final String firstName;

  const _QuoteView({
    required this.offer,
    required this.state,
    required this.firstName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<OfferCheckoutBloc>();
    final locale = context.locale.languageCode;
    final quote = bloc.quote;
    // BE luôn thu bằng USD (Stripe `usd`); currency của seller chỉ là cài đặt hồ sơ.
    const currency = 'USD';
    final session = offerSessionLabel(offer, locale);
    final paying = state.status == OfferCheckoutStatus.paying;
    final canPay = quote.isFree || state.selectedCardId != null;
    final label = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: theme.textSecondary(context),
    );
    final value = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: theme.textPrimary(context),
    );

    Widget row(String left, Widget right) => Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: [
          Expanded(child: Text(left, style: label)),
          right,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.checkoutAcceptTitle.tr(args: [firstName]),
          style: AppTextStyle.lightHeadingSmall.copyWith(
            color: theme.textPrimary(context),
          ),
        ),
        Gap(14.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: theme.muted(context),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            children: [
              if (session != null)
                row(
                  LocaleKeys.checkoutSession.tr(),
                  Text(session, style: value),
                ),
              row(
                LocaleKeys.checkoutPrice.tr(),
                Text(_money(quote.price, currency), style: value),
              ),
              if (quote.canChoosePoints || quote.pointsDiscount > 0)
                row(
                  LocaleKeys.checkoutLionPoints.tr(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (quote.pointsDiscount > 0)
                        Text(
                          LocaleKeys.checkoutPointsDiscount.tr(
                            args: [
                              _money(quote.pointsDiscount, currency),
                              NumberFormat.decimalPattern(
                                locale,
                              ).format(quote.points),
                            ],
                          ),
                          style: value.copyWith(color: Colour.success),
                        ),
                      if (quote.canChoosePoints)
                        SizedBox(
                          height: 24.h,
                          child: Switch(
                            value: state.usePoints,
                            onChanged: paying
                                ? null
                                : (v) =>
                                      bloc.add(OfferCheckoutPointsToggled(v)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            activeThumbColor: Colors.white,
                            activeTrackColor: theme.secondary(context),
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: theme.border(context),
                            trackOutlineColor: WidgetStateProperty.all(
                              Colors.transparent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (quote.voucherDiscount > 0)
                row(
                  LocaleKeys.checkoutVoucher.tr(
                    args: [offer.voucherCode ?? ''],
                  ),
                  Text(
                    '-${_money(quote.voucherDiscount, currency)}',
                    style: value.copyWith(color: Colour.success),
                  ),
                ),
              Divider(height: 14.h, color: theme.border(context)),
              row(
                LocaleKeys.checkoutTotal.tr(),
                Text(
                  _money(quote.total, currency),
                  style: value.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Gap(14.h),
        if (quote.isFree)
          Text(LocaleKeys.checkoutFreeOrder.tr(), style: label)
        else
          _PaymentMethods(state: state, enabled: !paying),
        Gap(14.h),
        Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: Colour.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 18.r,
                color: Colour.success,
              ),
              Gap(8.w),
              Expanded(
                child: Text(
                  LocaleKeys.checkoutEscrow.tr(args: [firstName]),
                  style: AppTextStyle.lightBodySmallRegular.copyWith(
                    height: 1.35,
                    color: const Color(0xFF1F6B45),
                  ),
                ),
              ),
            ],
          ),
        ),
        Gap(16.h),
        SizedBox(
          height: 50.h,
          child: FilledButton(
            onPressed: paying || !canPay
                ? null
                : () => bloc.add(const OfferCheckoutPayRequested()),
            style: FilledButton.styleFrom(
              backgroundColor: theme.secondary(context),
              disabledBackgroundColor: theme
                  .secondary(context)
                  .withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              textStyle: AppTextStyle.lightBodyMediumBold,
            ),
            child: paying
                ? const CupertinoActivityIndicator(color: Colors.white)
                : Text(
                    LocaleKeys.checkoutPay.tr(
                      args: [_money(quote.total, currency)],
                    ),
                  ),
          ),
        ),
        Gap(10.h),
        SizedBox(
          height: 48.h,
          child: OutlinedButton(
            onPressed: paying ? null : () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.textPrimary(context),
              side: BorderSide(color: theme.border(context)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(LocaleKeys.checkoutCancel.tr()),
          ),
        ),
      ],
    );
  }
}

/// Thẻ đã lưu (chọn một) + "Add card" — như web `PaymentMethod` (thẻ Stripe).
class _PaymentMethods extends StatelessWidget {
  final OfferCheckoutState state;
  final bool enabled;

  const _PaymentMethods({required this.state, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<OfferCheckoutBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.checkoutPaymentMethod.tr(),
          style: AppTextStyle.lightBodyMediumBold.copyWith(
            color: theme.textPrimary(context),
          ),
        ),
        Gap(6.h),
        if (state.cards.isEmpty)
          Text(
            LocaleKeys.checkoutNoCard.tr(),
            style: AppTextStyle.lightBodySmallRegular.copyWith(
              color: theme.textSecondary(context),
            ),
          ),
        for (final card in state.cards)
          InkWell(
            onTap: enabled
                ? () => bloc.add(OfferCheckoutCardSelected(card.id))
                : null,
            borderRadius: BorderRadius.circular(10.r),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              child: Row(
                children: [
                  Icon(
                    card.id == state.selectedCardId
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 20.r,
                    color: card.id == state.selectedCardId
                        ? theme.textPrimary(context)
                        : theme.textTertiary(context),
                  ),
                  Gap(10.w),
                  Icon(
                    Icons.credit_card_rounded,
                    size: 20.r,
                    color: theme.textSecondary(context),
                  ),
                  Gap(8.w),
                  Expanded(
                    child: Text(
                      '${card.brand.isEmpty ? 'Card' : card.brand[0].toUpperCase() + card.brand.substring(1)} •••• ${card.last4}',
                      style: AppTextStyle.lightBodyMediumRegular.copyWith(
                        color: theme.textPrimary(context),
                      ),
                    ),
                  ),
                  if (card.expMonth > 0)
                    Text(
                      LocaleKeys.checkoutCardExpires.tr(
                        args: [
                          '${card.expMonth.toString().padLeft(2, '0')}/${card.expYear % 100}',
                        ],
                      ),
                      style: AppTextStyle.lightBodySmallRegular.copyWith(
                        color: theme.textSecondary(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: enabled && !state.addingCard
                ? () => bloc.add(const OfferCheckoutAddCardRequested())
                : null,
            icon: state.addingCard
                ? const SizedBox.square(
                    dimension: 16,
                    child: CupertinoActivityIndicator(radius: 8),
                  )
                : Icon(Icons.add_rounded, size: 18.r),
            label: Text(LocaleKeys.checkoutAddCard.tr()),
            style: TextButton.styleFrom(
              foregroundColor: theme.textPrimary(context),
              padding: EdgeInsets.zero,
              textStyle: AppTextStyle.lightBodyMediumSemiBold,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Booked with Minh" (đã paid) / "Payment processing" (Stripe xong, chờ backend).
class _ResultView extends StatelessWidget {
  final RequestOfferEntity offer;
  final bool pending;
  final String firstName;
  final VoidCallback onMessage;

  const _ResultView({
    required this.offer,
    required this.pending,
    required this.firstName,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = offerSessionLabel(offer, context.locale.languageCode);
    final message = pending
        ? LocaleKeys.checkoutPendingMessage.tr()
        : [?session, LocaleKeys.checkoutBookedMessage.tr()].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap(8.h),
        Center(
          child: Container(
            width: 64.r,
            height: 64.r,
            decoration: BoxDecoration(
              color: Colour.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              pending ? Icons.hourglass_top_rounded : Icons.check_rounded,
              size: 32.r,
              color: Colour.success,
            ),
          ),
        ),
        Gap(14.h),
        Text(
          pending
              ? LocaleKeys.checkoutPendingTitle.tr()
              : LocaleKeys.checkoutBookedTitle.tr(args: [firstName]),
          textAlign: TextAlign.center,
          style: AppTextStyle.lightHeadingSmall.copyWith(
            color: theme.textPrimary(context),
          ),
        ),
        Gap(6.h),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyle.lightBodySmallRegular.copyWith(
            height: 1.4,
            color: theme.textSecondary(context),
          ),
        ),
        Gap(18.h),
        if (offer.sellerId != null) ...[
          SizedBox(
            height: 50.h,
            child: FilledButton(
              onPressed: onMessage,
              style: FilledButton.styleFrom(
                backgroundColor: theme.secondary(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                textStyle: AppTextStyle.lightBodyMediumBold,
              ),
              child: Text(LocaleKeys.checkoutMessage.tr(args: [firstName])),
            ),
          ),
          Gap(10.h),
        ],
        SizedBox(
          height: 48.h,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.textPrimary(context),
              side: BorderSide(color: theme.border(context)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(LocaleKeys.checkoutDone.tr()),
          ),
        ),
      ],
    );
  }
}
