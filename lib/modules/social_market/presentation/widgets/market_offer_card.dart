import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/modules/social_market/data/mappers/market_mapper.dart';

import '../../domain/entities/market_feed_entities.dart';
import '../market_formatters.dart';
import 'engagement_widgets.dart';
import 'market_clamp_text.dart';
import 'market_image_viewer.dart';
import 'market_ui.dart';

/// Ảnh minh hoạ dãy avatar (web `DEMO_FACES` / `avatarFaces` — chỉ trang trí).
const _demoFaces = [
  'https://i.pravatar.cc/64?img=12',
  'https://i.pravatar.cc/64?img=32',
  'https://i.pravatar.cc/64?img=47',
  'https://i.pravatar.cc/64?img=5',
  'https://i.pravatar.cc/64?img=68',
  'https://i.pravatar.cc/64?img=20',
  'https://i.pravatar.cc/64?img=56',
  'https://i.pravatar.cc/64?img=9',
  'https://i.pravatar.cc/64?img=39',
  'https://i.pravatar.cc/64?img=64',
  'https://i.pravatar.cc/64?img=25',
  'https://i.pravatar.cc/64?img=52',
];

/// Card Public Offer (web `OfferCard`): đóng = người đăng + nội dung; chạm để mở chi
/// tiết (hình thức, lịch, giá theo hình thức, yêu cầu, kết quả…) + "I want this offer".
class MarketOfferCard extends StatelessWidget {
  final MarketOfferEntity offer;

  /// Thứ tự trong list — seed cho dãy avatar minh hoạ.
  final int index;
  final VoidCallback onWantThis;

  const MarketOfferCard({
    super.key,
    required this.offer,
    required this.index,
    required this.onWantThis,
  });

  String? _price() {
    final min = offer.minPrice;
    if (min == null) return null;
    final unit = offer.pricingUnit == null
        ? ''
        : ' / ${MarketFormatters.pricingUnit(offer.pricingUnit!)}';
    return '${MarketMapper.formatMoney(min, offer.currency)}$unit';
  }

  String _location(List<({String key, String value})> parts) => parts
      .map(
        (p) => p.key == 'radius_km'
            ? LocaleKeys.marketOfferRadiusKm.tr(namedArgs: {'radius': p.value})
            : p.value,
      )
      .join(', ');

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final name = o.sellerName ?? LocaleKeys.marketOfferFallbackName.tr();
    final price = _price();
    final metaStyle = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );
    final role = [
      ?o.profession,
      if (o.createdAt != null) MarketFormatters.timeAgo(o.createdAt),
    ].join(' · ');
    final images = [
      for (final m in o.media)
        if (!m.isVideo) m.url,
    ];

    return MarketExpandableCard(
      builder: (context, open, toggle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MarketSellerRow(
                  name: name,
                  avatar: o.sellerAvatar,
                  country: o.country,
                  flag: o.flag,
                  trailingMeta: role.isEmpty ? null : role,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MarketEngagementButtons(id: o.id, showLike: true),
                  if (price != null) ...[
                    Gap(6.h),
                    MarketBadge(price, tone: MarketBadgeTone.seller),
                  ],
                ],
              ),
            ],
          ),
          Gap(16.h),
          MarketClampText(
            text: o.detail,
            open: open,
            onToggle: toggle,
            style: AppTextStyle.lightBodyMediumRegular.copyWith(
              color: Colour.textPrimary,
              height: 1.6,
            ),
          ),
          if (open && o.media.isNotEmpty) ...[
            Gap(16.h),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8.r,
              crossAxisSpacing: 8.r,
              childAspectRatio: 1.4,
              children: [
                for (final m in o.media)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: m.isVideo
                        ? const ColoredBox(
                            color: Colors.black,
                            child: Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: () => showMarketImageViewer(
                              context,
                              images: images,
                              initialIndex: images.indexOf(m.url),
                            ),
                            child: Image.network(
                              m.url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const ColoredBox(color: Colour.subtle),
                            ),
                          ),
                  ),
              ],
            ),
          ],
          if (open) ...[
            Gap(16.h),
            _OfferDetails(offer: o, location: _location),
          ],
          Gap(16.h),
          MarketCardFooter(
            leading: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8.w,
              runSpacing: 4.h,
              children: [
                _AvatarStack(seed: index),
                MarketEngagementLine(id: o.id, style: metaStyle),
              ],
            ),
            trailing: open
                ? MarketButton(
                    label: LocaleKeys.marketOfferWantThis.tr(),
                    variant: MarketButtonVariant.softSeller,
                    onPressed: o.id != null && o.sellerUserId != null
                        ? onWantThis
                        : null,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _OfferDetails extends StatelessWidget {
  final MarketOfferEntity offer;
  final String Function(List<({String key, String value})>) location;

  const _OfferDetails({required this.offer, required this.location});

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final labelStyle = AppTextStyle.lightBodySmallMedium.copyWith(
      color: Colour.textPrimary,
    );
    Widget block(String label, String? value) => value == null
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                Gap(4.h),
                Text(
                  MarketMapper.plainText(value),
                  style: AppTextStyle.lightBodyMediumRegular.copyWith(
                    color: Colour.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colour.mutedWeb,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarketInfoRow(
            icon: Icons.local_shipping_outlined,
            label: LocaleKeys.marketOfferDelivery.tr(),
            value: o.deliveryTypes
                .map(MarketFormatters.formDelivery)
                .join(', '),
          ),
          MarketInfoRow(
            icon: Icons.schedule,
            label: LocaleKeys.marketOfferDuration.tr(),
            value: o.durationValue == null
                ? null
                : '${o.durationValue} ${o.durationUnit == null ? '' : MarketFormatters.durationUnit(o.durationUnit!)}'
                      .trim(),
          ),
          MarketInfoRow(
            icon: Icons.event_outlined,
            label: LocaleKeys.marketOfferAvailability.tr(),
            value: MarketFormatters.schedule(o.schedule),
          ),
          MarketInfoRow(
            icon: Icons.translate,
            label: LocaleKeys.marketOfferLanguages.tr(),
            value: o.languages.map(MarketFormatters.humanize).join(', '),
          ),
          MarketInfoRow(
            icon: Icons.location_on_outlined,
            label: LocaleKeys.marketOfferServiceLocation.tr(),
            value: location(o.serviceLocation),
          ),
          MarketInfoRow(
            icon: Icons.social_distance_outlined,
            label: LocaleKeys.marketOfferCoverageArea.tr(),
            value: location(o.coverageArea),
          ),
          MarketInfoRow(
            icon: Icons.category_outlined,
            label: LocaleKeys.marketOfferCategory.tr(),
            value: o.category,
          ),
          if (o.acceptTravelingPatients)
            MarketInfoRow(
              icon: Icons.flight,
              label: LocaleKeys.marketOfferTravelingPatients.tr(),
              value: LocaleKeys.marketOfferAccepted.tr(),
            ),
          if (o.prices.isNotEmpty) ...[
            Text(LocaleKeys.marketOfferPricing.tr(), style: labelStyle),
            Gap(6.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                for (final p in o.prices)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colour.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colour.seller50),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${MarketFormatters.formDelivery(p.mode)}: ',
                          ),
                          TextSpan(
                            text: MarketMapper.formatMoney(
                              p.amount,
                              o.currency,
                            ),
                            style: AppTextStyle.lightBodySmallBold,
                          ),
                          if (o.pricingUnit != null)
                            TextSpan(
                              text:
                                  ' / ${MarketFormatters.pricingUnit(o.pricingUnit!)}',
                            ),
                        ],
                      ),
                      style: AppTextStyle.lightBodySmallRegular.copyWith(
                        color: Colour.seller800,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          block(
            LocaleKeys.marketOfferBuyerPrepare.tr(),
            o.additionalRequirements,
          ),
          block(LocaleKeys.marketOfferExpectedResult.tr(), o.expectedResult),
          block(LocaleKeys.marketOfferStories.tr(), o.stories),
          if (o.hashtags.isNotEmpty) ...[
            Gap(12.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: [
                for (final tag in o.hashtags)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colour.surface,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      '#${tag.replaceFirst(RegExp(r'^#'), '')}',
                      style: AppTextStyle.lightBodySmallRegular.copyWith(
                        color: Colour.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Dãy 4 avatar chồng nhau (web `AvatarStack`, chỉ trang trí).
class _AvatarStack extends StatelessWidget {
  final int seed;

  const _AvatarStack({required this.seed});

  @override
  Widget build(BuildContext context) {
    final size = 24.r;
    final faces = [
      for (var i = 0; i < 4; i++)
        _demoFaces[(seed * 3 + i * 5) % _demoFaces.length],
    ];
    return SizedBox(
      width: size + (faces.length - 1) * (size - 8.r),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < faces.length; i++)
            Positioned(
              left: i * (size - 8.r),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colour.mutedWeb,
                  border: Border.all(color: Colors.white, width: 2),
                  image: DecorationImage(
                    image: NetworkImage(faces[i]),
                    fit: BoxFit.cover,
                    onError: (_, _) {},
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
