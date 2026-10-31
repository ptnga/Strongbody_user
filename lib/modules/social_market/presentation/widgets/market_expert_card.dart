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

/// Card hồ sơ (web `ExpertCard` biến thể `profile`): avatar + tên (+ Licence
/// verified) + "🇦🇺 Australia · 5 yrs" → "nghề · ★ 4.9 (12)" → giới thiệu 3 dòng →
/// ngôn ngữ → số engagement → "N booked" → "View profile".
class MarketExpertCard extends StatelessWidget {
  final MarketExpertEntity expert;
  final VoidCallback? onViewProfile;

  const MarketExpertCard({super.key, required this.expert, this.onViewProfile});

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
          Gap(12.h),
          MarketEngagementLine(id: e.id, style: metaStyle),
          if (e.booked != null) ...[
            Gap(4.h),
            Text(LocaleKeys.marketBooked.plural(e.booked!), style: metaStyle),
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
