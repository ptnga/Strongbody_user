import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/components/initials_avatar.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../domain/entities/market_listing_entities.dart';
import '../market_formatters.dart';
import 'engagement_widgets.dart';
import 'market_ui.dart';

/// Card service (web `ServiceCard`): tiêu đề + lưu →
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

  /// false = ẩn like / save và số engagement (thẻ kết quả của trợ lý AI, web `showEngagement`).
  final bool showEngagement;

  const MarketServiceCard({
    super.key,
    required this.service,
    required this.onInquiry,
    required this.onViewAndBook,
    this.onTap,
    this.onSellerTap,
    this.showImage = false,
    this.showEngagement = true,
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
            if (showEngagement) MarketEngagementButtons(id: s.id),
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
          flag: s.placeFlag,
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
        if (showEngagement) ...[
          Gap(12.h),
          MarketEngagementLine(id: s.id, hideLikes: true, style: metaStyle),
        ],
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
          // Chỉ ảnh bìa (cover), không carousel (web `firstImage(cover_image, image)`).
          _ImageStrip(images: [?s.coverImage], deliveries: s.deliveries),
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
        // Tư vấn: khoảng giá tham khảo, giá chốt sau inquiry (web `card.consultation`).
        if (price.consultation) ...[
          Text(
            LocaleKeys.marketCardConsultation.tr(),
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

/// Card service của lưới trang category + listing (web `ServiceCard` với
/// `deliveryFooter compact showSeller={false} showEngagement={false}`): ảnh bìa 16:9
/// (nút lưu ở góc) → tiêu đề 2 dòng → mô tả 2 dòng → người cung cấp (avatar viền
/// xác minh, tên, cờ + nước · ngôn ngữ) → giá (Tư vấn: nhãn "Consultation" + khoảng
/// giá; Medical Travel: nhãn thay giá) · số lượt lưu. Cả card bấm được.
class MarketServiceGridCard extends StatelessWidget {
  final MarketServiceEntity service;
  final VoidCallback? onTap;

  const MarketServiceGridCard({super.key, required this.service, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = service;
    final seller = s.seller;
    final metaStyle = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );
    final image = s.coverImage;
    return MarketCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image == null)
                  const ColoredBox(
                    color: Colour.subtle,
                    child: Icon(
                      Icons.medical_services_outlined,
                      color: Colour.textTertiary,
                    ),
                  )
                else
                  Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Colour.subtle),
                  ),
                Positioned(
                  top: 4.h,
                  right: 4.w,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colour.surface,
                      shape: BoxShape.circle,
                    ),
                    child: MarketEngagementButtons(id: s.id),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
                    color: Colour.textPrimary,
                  ),
                ),
                Gap(8.h),
                // Mô tả luôn giữ chỗ 2 dòng để các card thẳng hàng.
                Text(
                  '${s.description}\n',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.lightBodyMediumRegular.copyWith(
                    color: Colour.textSecondary,
                  ),
                ),
                Gap(12.h),
                const Divider(height: 1, color: Colour.lineSubtle),
                Gap(12.h),
                MarketProviderLine(seller: seller),
                Gap(12.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: s.isMedicalTravel
                          // Medical Travel: không giá - chi phí báo sau qua yêu cầu khám.
                          ? Row(
                              children: [
                                Icon(
                                  Icons.flight,
                                  size: 16.r,
                                  color: Colour.buttonPrimary,
                                ),
                                Gap(6.w),
                                Flexible(
                                  child: Text(
                                    LocaleKeys.marketMedicalTravelBadge.tr(),
                                    style: AppTextStyle.lightBodyMediumMedium
                                        .copyWith(color: Colour.buttonPrimary),
                                  ),
                                ),
                              ],
                            )
                          : _GridPrice(service: s),
                    ),
                    Gap(8.w),
                    MarketSavedCount(id: s.id, style: metaStyle),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Người cung cấp ở card lưới: avatar 44 (đã xác minh: viền + dấu tick ở góc), tên, cờ +
/// nước · ngôn ngữ trên MỘT dòng (web `deliveryFooter` row).
class MarketProviderLine extends StatelessWidget {
  final MarketSeller seller;

  const MarketProviderLine({super.key, required this.seller});

  @override
  Widget build(BuildContext context) {
    final name = seller.shopName ?? LocaleKeys.marketFallbackSeller.tr();
    final metaStyle = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );
    final languages = seller.languages.join(', ');
    return Row(
      children: [
        MarketVerifiedAvatar(
          name: name,
          avatar: seller.avatar,
          size: 44,
          verified: seller.verified,
        ),
        Gap(12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.lightBodyMediumMedium.copyWith(
                  color: Colour.textPrimary,
                ),
              ),
              if (seller.country != null || languages.isNotEmpty) ...[
                Gap(2.h),
                Text.rich(
                  TextSpan(
                    children: [
                      if (seller.country != null) ...[
                        if (seller.flag != null)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.only(right: 6.w),
                              child: CountryFlag(seller.flag),
                            ),
                          ),
                        TextSpan(text: seller.country),
                      ],
                      if (seller.country != null && languages.isNotEmpty)
                        const TextSpan(text: '\u00a0· '),
                      if (languages.isNotEmpty) ...[
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.only(right: 4.w),
                            child: Icon(
                              Icons.language,
                              size: 16.r,
                              color: Colour.textSecondary,
                            ),
                          ),
                        ),
                        TextSpan(text: languages),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metaStyle,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Avatar tròn; đã xác minh → viền xanh (cách 2px) + dấu tick trắng nền ở góc dưới phải.
class MarketVerifiedAvatar extends StatelessWidget {
  final String name;
  final String? avatar;
  final double size;
  final bool verified;

  /// Thay dấu tick mặc định (vd. huy hiệu đếm số mục xác minh của card chuyên gia).
  final Widget? badge;

  const MarketVerifiedAvatar({
    super.key,
    required this.name,
    required this.avatar,
    required this.size,
    required this.verified,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final image = InitialsAvatar(
      name: name,
      imageUrl: avatar,
      colorSeed: name.hashCode,
      size: size.r,
    );
    if (!verified) return image;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.all(2.r),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colour.buttonPrimary, width: 2.r),
          ),
          child: image,
        ),
        Positioned(
          right: -6.r,
          bottom: -4.r,
          child:
              badge ??
              Container(
                width: 20.r,
                height: 20.r,
                decoration: const BoxDecoration(
                  color: Colour.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified,
                  size: 16.r,
                  color: Colour.buttonPrimary,
                  semanticLabel: LocaleKeys.marketCardVerified.tr(),
                ),
              ),
        ),
      ],
    );
  }
}

/// Giá ở chân card lưới: Tư vấn → "Consultation" cùng dòng với khoảng giá.
class _GridPrice extends StatelessWidget {
  final MarketServiceEntity service;

  const _GridPrice({required this.service});

  @override
  Widget build(BuildContext context) {
    final price = service.price;
    if (price == null) return const SizedBox.shrink();
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 4.w,
      children: [
        if (price.consultation)
          Text(
            LocaleKeys.marketCardConsultation.tr(),
            style: AppTextStyle.lightBodySmallMedium.copyWith(
              color: Colour.textSecondary,
            ),
          ),
        Text(
          price.text,
          style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
            color: Colour.textPrimary,
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
