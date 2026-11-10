import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/components/initials_avatar.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/modules/social_market/data/mappers/market_mapper.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/market_navigation.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_ui.dart';

import '../../../domain/entities/board_entities.dart';

/// Dòng offer của board (web `OfferRow`): ảnh · tên · nhà cung cấp (cờ, "Verified") ·
/// mô tả → giá (Tư vấn: khoảng giá) · hình thức → "Book" (Tư vấn: "Send inquiry") /
/// "Free consult". Chạm cả thẻ = mở dịch vụ.
class BoardOfferRow extends StatelessWidget {
  final BoardOffer offer;

  const BoardOfferRow({super.key, required this.offer});

  static String delivery(String type) => switch (type) {
    'remote' => LocaleKeys.boardDeliveryRemote.tr(),
    'at_office' => LocaleKeys.boardDeliveryAtOffice.tr(),
    'at_home' => LocaleKeys.boardDeliveryAtHome.tr(),
    _ => type,
  };

  /// Web `servicePrice`: 1 giá (Đặt ngay) hoặc "Consultation $a – $b" (Tư vấn).
  static String? priceLabel(BoardOffer offer, String? currency) {
    final price = offer.price;
    if (price == null) return null;
    final max = offer.priceMax;
    final text = max != null && max != price
        ? '${MarketMapper.formatMoney(price, currency)} – '
              '${MarketMapper.formatMoney(max, currency)}'
        : MarketMapper.formatMoney(price, currency);
    return offer.consultation
        ? '${LocaleKeys.boardCardConsultation.tr()} $text'
        : text;
  }

  @override
  Widget build(BuildContext context) {
    final s = offer.service;
    final seller = s.seller;
    final name = seller.shopName ?? LocaleKeys.boardCardFallbackSeller.tr();
    final image = s.images.firstOrNull;
    final priceText = s.isMedicalTravel
        ? '✈ ${LocaleKeys.boardCardMedicalTravel.tr()}'
        : priceLabel(offer, s.price?.currency);
    final footer = [
      ?priceText,
      if (offer.deliveryTypes.isNotEmpty)
        offer.deliveryTypes.map(delivery).join(', '),
    ].join(' · ');
    final metaStyle = AppTextStyle.lightBodySmallRegular.copyWith(
      color: Colour.textSecondary,
    );

    return MarketCard(
      padding: EdgeInsets.all(12.r),
      onTap: () => MarketNavigation.openService(context, s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: SizedBox.square(
                  dimension: 96.r,
                  child: image == null
                      ? const _ImageFallback()
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _ImageFallback(),
                        ),
                ),
              ),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                        color: Colour.textPrimary,
                      ),
                    ),
                    Gap(6.h),
                    Row(
                      children: [
                        InitialsAvatar(
                          name: name,
                          imageUrl: seller.avatar,
                          colorSeed: name.hashCode,
                          size: 22.r,
                        ),
                        Gap(6.w),
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.lightBodySmallMedium.copyWith(
                              color: Colour.textPrimary,
                            ),
                          ),
                        ),
                        if (seller.flag != null) ...[
                          Gap(6.w),
                          CountryFlag(seller.flag),
                        ],
                        if (offer.verifiedChecks > 0) ...[
                          Gap(6.w),
                          Icon(
                            Icons.verified,
                            size: 14.r,
                            color: Colour.seller,
                          ),
                          Gap(2.w),
                          Text(
                            '${LocaleKeys.boardCardVerified.tr()} '
                            '${offer.verifiedChecks}',
                            style: AppTextStyle.lightBodyXSmallMedium.copyWith(
                              color: Colour.seller800,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (s.description.isNotEmpty) ...[
                      Gap(6.h),
                      Text(
                        s.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: metaStyle,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Gap(10.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  footer,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.lightBodySmallMedium.copyWith(
                    color: Colour.textPrimary,
                  ),
                ),
              ),
              if (offer.freeConsultation && !s.isMedicalTravel) ...[
                Gap(8.w),
                MarketButton(
                  label: LocaleKeys.boardCardFreeConsult.tr(),
                  variant: MarketButtonVariant.outline,
                  onPressed: () => MarketNavigation.inquireService(
                    context,
                    s,
                    message: LocaleKeys.boardConsultMessage.tr(
                      namedArgs: {'title': s.title},
                    ),
                  ),
                ),
              ],
              Gap(8.w),
              // Tư vấn: không đặt mua — gửi inquiry, seller báo giá sau (web).
              offer.consultation
                  ? MarketButton(
                      label: LocaleKeys.boardCardSendInquiry.tr(),
                      onPressed: () =>
                          MarketNavigation.inquireService(context, s),
                    )
                  : MarketButton(
                      label: LocaleKeys.boardCardBook.tr(),
                      onPressed: () => MarketNavigation.openService(context, s),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colour.subtle,
    child: Icon(
      Icons.health_and_safety_outlined,
      size: 32.r,
      color: Colour.textTertiary,
    ),
  );
}
