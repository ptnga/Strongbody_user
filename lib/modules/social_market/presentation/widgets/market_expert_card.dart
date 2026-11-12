import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/utils/plural_tr.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../domain/entities/market_listing_entities.dart';
import '../market_formatters.dart';
import 'engagement_widgets.dart';
import 'market_service_card.dart' show MarketVerifiedAvatar;
import 'market_ui.dart';

/// Card hồ sơ (web `ExpertCard` biến thể `profile`): avatar + tên (+ Licence
/// verified) + "🇦🇺 Australia · 5 yrs" → "nghề · ★ 4.9 (12)" → giới thiệu 3 dòng →
/// ngôn ngữ → số engagement → "N booked" → "View profile".
class MarketExpertCard extends StatelessWidget {
  final MarketExpertEntity expert;
  final VoidCallback? onViewProfile;

  /// false = ẩn like / save và số engagement (thẻ kết quả của trợ lý AI, web `showEngagement`).
  final bool showEngagement;

  const MarketExpertCard({
    super.key,
    required this.expert,
    this.onViewProfile,
    this.showEngagement = true,
  });

  @override
  Widget build(BuildContext context) {
    final e = expert;
    final name = e.name.isEmpty ? LocaleKeys.marketFallbackSeller.tr() : e.name;
    // Không có nghề → nhãn Medical Travel, hoặc đơn vị trực thuộc của coordinator.
    final subtitle =
        e.subtitle ??
        (e.medicalTravel ? LocaleKeys.marketMedicalTravel.tr() : null) ??
        (e.representativeOf != null
            ? LocaleKeys.marketCardRepresentativeOf.tr(
                namedArgs: {'org': e.representativeOf!},
              )
            : e.independent
            ? LocaleKeys.marketCardIndependent.tr()
            : null);
    final years = MarketFormatters.years(e.yearsOfExperience);
    final metaStyle = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );

    return MarketCard(
      onTap: onViewProfile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarketSellerRow(
                      name: name,
                      avatar: e.avatar,
                      verified: e.verified,
                      avatarSize: 56,
                      large: true,
                      country: e.country,
                      flag: e.flag,
                      trailingMeta: years.isEmpty ? null : years,
                    ),
                    Gap(8.h),
                    // Luôn giữ chỗ để mô tả các card bắt đầu cùng độ cao.
                    SizedBox(
                      height: 24.h,
                      child: Row(
                        children: [
                          if (subtitle != null)
                            Flexible(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: metaStyle,
                              ),
                            ),
                          if (subtitle != null && e.hasRating)
                            Text('  ·  ', style: metaStyle),
                          if (e.hasRating) ...[
                            Icon(
                              Icons.star_rounded,
                              size: 16.r,
                              color: Colour.amber,
                            ),
                            Gap(2.w),
                            Text(
                              e.ratingValue.toStringAsFixed(1),
                              style: AppTextStyle.lightBodyMediumMedium
                                  .copyWith(color: Colour.textPrimary),
                            ),
                            Text(' (${e.ratingCount})', style: metaStyle),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (showEngagement)
                MarketEngagementButtons(id: e.id, showLike: true),
            ],
          ),
          if (e.about != null) ...[
            Gap(12.h),
            Text(
              '${e.about}\n\n',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.lightBodyMediumRegular.copyWith(
                color: Colour.textPrimary,
                height: 1.6,
              ),
            ),
          ],
          if (e.languages.isNotEmpty) ...[
            Gap(6.h),
            Text(e.languages.join(', '), style: metaStyle),
          ],
          if (showEngagement) ...[
            Gap(12.h),
            MarketEngagementLine(id: e.id, style: metaStyle),
          ],
          if (e.booked != null) ...[
            Gap(4.h),
            Text(
              pluralTr(
                e.booked!,
                one: LocaleKeys.marketBookedOne,
                other: LocaleKeys.marketBookedOther,
              ),
              style: metaStyle,
            ),
          ],
          if (onViewProfile != null) ...[
            Gap(12.h),
            MarketCardFooter(
              leading: Align(
                alignment: Alignment.centerLeft,
                child: MarketButton(
                  label: LocaleKeys.marketViewProfile.tr(),
                  variant: MarketButtonVariant.more,
                  onPressed: onViewProfile,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card chân dung của lưới trang category + listing provider (web `ExpertCard`
/// biến thể `spotlight`): căn giữa — avatar 72 (đã xác minh: viền + huy hiệu số mục ở
/// góc), tên 2 dòng, nghề / tổ chức · số năm, cờ + nước · ngôn ngữ, rating, giới thiệu
/// 2 dòng. Chỉ có nút lưu (không like).
class MarketExpertSpotlightCard extends StatelessWidget {
  final MarketExpertEntity expert;
  final VoidCallback? onTap;

  const MarketExpertSpotlightCard({
    super.key,
    required this.expert,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final e = expert;
    final name = e.name.isEmpty ? LocaleKeys.marketFallbackSeller.tr() : e.name;
    final subtitle =
        e.subtitle ??
        (e.medicalTravel ? LocaleKeys.marketMedicalTravel.tr() : null) ??
        (e.representativeOf != null
            ? LocaleKeys.marketCardRepresentativeOf.tr(
                namedArgs: {'org': e.representativeOf!},
              )
            : e.independent
            ? LocaleKeys.marketCardIndependent.tr()
            : null);
    // Tổ chức khác tên provider thì đứng thay nghề.
    final profession = e.organization != null && e.organization != e.name
        ? e.organization
        : subtitle;
    final years = MarketFormatters.years(e.yearsOfExperience);
    final languages = e.languages.join(', ');
    final v = e.cardVerifications;
    final metaStyle = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );

    return MarketCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 16.h),
            child: Column(
              children: [
                MarketVerifiedAvatar(
                  name: name,
                  avatar: e.avatar,
                  size: 72,
                  verified: v?.any ?? false,
                  badge: v == null ? null : _VerificationBadge(v),
                ),
                Gap(12.h),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
                    color: Colour.textPrimary,
                  ),
                ),
                if (profession != null || years.isNotEmpty) ...[
                  Gap(2.h),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (profession != null)
                          TextSpan(
                            text: profession,
                            style: AppTextStyle.lightBodyMediumMedium.copyWith(
                              color: Colour.buttonPrimary,
                            ),
                          ),
                        if (profession != null && years.isNotEmpty)
                          const TextSpan(text: '\u00a0· '),
                        if (years.isNotEmpty) TextSpan(text: years),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: metaStyle,
                  ),
                ],
                if (e.country != null || languages.isNotEmpty) ...[
                  Gap(6.h),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (e.country != null) ...[
                          if (e.flag != null)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.only(right: 6.w),
                                child: CountryFlag(e.flag),
                              ),
                            ),
                          TextSpan(text: e.country),
                        ],
                        if (e.country != null && languages.isNotEmpty)
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: metaStyle,
                  ),
                ],
                if (e.hasRating) ...[
                  Gap(4.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 16.r, color: Colour.amber),
                      Gap(2.w),
                      Text(
                        e.ratingValue.toStringAsFixed(1),
                        style: AppTextStyle.lightBodyMediumMedium.copyWith(
                          color: Colour.textPrimary,
                        ),
                      ),
                      Text(' (${e.ratingCount})', style: metaStyle),
                    ],
                  ),
                ],
                Gap(8.h),
                // Giới thiệu 2 dòng — luôn giữ chỗ để các card thẳng hàng.
                Text(
                  '${e.about ?? ''}\n',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.lightBodyMediumRegular.copyWith(
                    color: Colour.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 4.h,
            right: 4.w,
            child: MarketEngagementButtons(id: e.id),
          ),
        ],
      ),
    );
  }
}

/// Huy hiệu xác minh gọn ở góc avatar (web `VerificationSummary compact`): icon
/// verified + chấm số mục đã xác minh.
class _VerificationBadge extends StatelessWidget {
  final MarketVerifications v;

  const _VerificationBadge(this.v);

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(2.r),
    decoration: const BoxDecoration(
      color: Colour.surface,
      shape: BoxShape.circle,
    ),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          Icons.verified,
          size: 18.r,
          color: Colour.buttonPrimary,
          semanticLabel: LocaleKeys.marketCardVerified.tr(),
        ),
        Positioned(
          right: -4.r,
          bottom: -4.r,
          child: Container(
            width: 12.r,
            height: 12.r,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colour.textPrimary,
              shape: BoxShape.circle,
              border: Border.all(color: Colour.surface),
            ),
            child: Text(
              '${v.count}',
              style: AppTextStyle.lightBodyXSmallMedium.copyWith(
                color: Colour.surface,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
