import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../domain/entities/market_listing_entities.dart';
import '../market_formatters.dart';
import 'engagement_widgets.dart';
import 'market_ui.dart';

/// Card service (web `ServiceCard`, trang category không có ảnh): tiêu đề + lưu →
/// badge hình thức → seller → mô tả → meta → số engagement → giá + "Send Inquiry".
/// Service Medical Travel: ẩn giá (badge), nút "View & book".
class MarketServiceCard extends StatelessWidget {
  final MarketServiceEntity service;
  final VoidCallback? onTap;
  final VoidCallback? onSellerTap;
  final VoidCallback onInquiry;
  final VoidCallback onViewAndBook;

  /// Dải ảnh đầu card — web chỉ hiện ở các trang Medical Travel (`serviceCardHasImage`).
  final bool showImage;

  const MarketServiceCard({
    super.key,
    required this.service,
    required this.onInquiry,
    required this.onViewAndBook,
    this.onTap,
    this.onSellerTap,
    this.showImage = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = service;
    final seller = s.seller;
    final sellerName = seller.shopName ?? LocaleKeys.marketFallbackSeller.tr();
    final where = s.place ?? LocaleKeys.marketOnline.tr();
    final meta = [
      if (s.coverage != null)
        LocaleKeys.marketDeliveryWithin.tr(namedArgs: {'radius': s.coverage!}),
      ?s.languages,
    ].join(' · ');
    final metaStyle = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                // Luôn chiếm đúng 2 dòng để các card thẳng hàng.
                '${s.title}\n',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
                  color: Colour.textPrimary,
                ),
              ),
            ),
            MarketEngagementButtons(id: s.id),
          ],
        ),
        // Không có ảnh → nhãn hình thức ngay dưới tiêu đề; có ảnh thì nằm trên ảnh.
        if (!showImage && s.deliveries.isNotEmpty) ...[
          Gap(8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              for (final d in s.deliveries)
                MarketBadge(
                  MarketFormatters.serviceDelivery(d.type),
                  icon: MarketFormatters.deliveryIcon(d.type),
                ),
            ],
          ),
        ],
        Gap(12.h),
        MarketSellerRow(
          name: sellerName,
          avatar: seller.avatar,
          country: where,
          flag: where == seller.country ? seller.flag : null,
          trailingMeta: seller.profession,
          onTap: onSellerTap,
        ),
        if (s.description.isNotEmpty) ...[
          Gap(12.h),
          Text(
            '${s.description}\n',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.lightBodyMediumRegular.copyWith(
              color: Colour.textPrimary,
              height: 1.6,
            ),
          ),
        ],
        if (meta.isNotEmpty) ...[Gap(6.h), Text(meta, style: metaStyle)],
        Gap(12.h),
        MarketEngagementLine(id: s.id, hideLikes: true, style: metaStyle),
        Gap(12.h),
        MarketCardFooter(
          leading: s.isMedicalTravel
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: MarketBadge(
                    LocaleKeys.marketMedicalTravelBadge.tr(),
                    tone: MarketBadgeTone.info,
                    icon: Icons.flight,
                  ),
                )
              : _Price(service: s),
          trailing: s.isMedicalTravel
              ? MarketButton(
                  label: LocaleKeys.marketViewAndBook.tr(),
                  onPressed: onViewAndBook,
                )
              : MarketButton(
                  label: LocaleKeys.marketSendInquiry.tr(),
                  variant: MarketButtonVariant.softSeller,
                  onPressed: s.id != null && seller.id != null
                      ? onInquiry
                      : null,
                ),
        ),
      ],
    );
    if (!showImage) return MarketCard(onTap: onTap, child: content);
    return MarketCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ImageStrip(images: s.images, deliveries: s.deliveries),
          Padding(padding: EdgeInsets.all(20.r), child: content),
        ],
      ),
    );
  }
}

/// Ảnh dạng dải nông (h-24), vuốt qua lại; badge hình thức ở góc trên phải (web
/// `CardImageCarousel` + overlay).
class _ImageStrip extends StatefulWidget {
  final List<String> images;
  final List<MarketDelivery> deliveries;

  const _ImageStrip({required this.images, required this.deliveries});

  @override
  State<_ImageStrip> createState() => _ImageStripState();
}

class _ImageStripState extends State<_ImageStrip> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return SizedBox(
      height: 96.h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (images.isEmpty)
            const ColoredBox(
              color: Colour.subtle,
              child: Icon(
                Icons.medical_services_outlined,
                color: Colour.textTertiary,
              ),
            )
          else
            PageView.builder(
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => Image.network(
                images[i],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Colour.subtle),
              ),
            ),
          if (widget.deliveries.isNotEmpty)
            Positioned(
              top: 8.h,
              right: 8.w,
              left: 8.w,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 4.w,
                runSpacing: 4.h,
                children: [
                  for (final d in widget.deliveries)
                    MarketBadge(
                      MarketFormatters.serviceDelivery(d.type),
                      icon: MarketFormatters.deliveryIcon(d.type),
                      tone: MarketBadgeTone.overlay,
                    ),
                ],
              ),
            ),
          if (images.length > 1)
            Positioned(
              bottom: 6.h,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < images.length && i < 8; i++)
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 2.w),
                      width: 6.r,
                      height: 6.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Price extends StatelessWidget {
  final MarketServiceEntity service;

  const _Price({required this.service});

  @override
  Widget build(BuildContext context) {
    final price = service.price;
    if (price == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Nhiều cách cung cấp = nhiều mức giá → nói rõ đây là giá thấp nhất.
        if (price.from) ...[
          Text(
            LocaleKeys.marketPriceFrom.tr(),
            style: AppTextStyle.lightBodySmallMedium.copyWith(
              color: Colour.textSecondary,
            ),
          ),
          Gap(4.h),
        ],
        Text(
          price.text,
          style: AppTextStyle.lightBodyXLargeSemiBold.copyWith(
            color: Colour.textPrimary,
            height: 1,
          ),
        ),
        if (service.strikePrice != null)
          Text(
            service.strikePrice!,
            style: AppTextStyle.lightBodyMediumRegular.copyWith(
              color: Colour.textSecondary,
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }
}
