import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../domain/entities/market_feed_entities.dart';
import 'market_ui.dart';

/// Card Health Solution Library (web `SolutionCard`): tiêu đề + category, "Good for"
/// rút gọn; mở ra đủ 4 mục + hashtag + "I want a solution of this type" (vai seeker).
/// Nút "I have an offer of this type" là của provider — app buyer ẩn.
class MarketSolutionCard extends StatelessWidget {
  final HealthSolutionEntity solution;
  final ValueChanged<HealthSolutionEntity> onWant;

  const MarketSolutionCard({
    super.key,
    required this.solution,
    required this.onWant,
  });

  /// Cắt ở ranh giới từ (web `shorten`), bỏ dấu chấm / khoảng trắng cuối.
  static String _shorten(String text, int max) {
    final cut = text.length <= max
        ? text
        : text.substring(0, max).replaceFirst(RegExp(r'\s+\S*$'), '');
    return cut.replaceFirst(RegExp(r'[.\s]+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final s = solution;
    final metaStyle = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );
    final bodyStyle = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textPrimary,
      height: 1.6,
    );
    Widget field(String label, String? value) => value == null
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: metaStyle),
                Gap(2.h),
                Text(value, style: bodyStyle),
              ],
            ),
          );

    return MarketExpandableCard(
      builder: (context, open, toggle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.title,
            style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
              color: Colour.textPrimary,
            ),
          ),
          if (s.categories.isNotEmpty) ...[
            Gap(8.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: [
                for (final c in s.categories) MarketBadge(c.name.trim()),
              ],
            ),
          ],
          if (!open && s.applicableWhen != null) ...[
            Gap(12.h),
            Text(LocaleKeys.marketSolutionGoodFor.tr(), style: metaStyle),
            Gap(2.h),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: _shorten(s.applicableWhen!, 96)),
                  TextSpan(text: '...', style: metaStyle),
                ],
              ),
              style: bodyStyle,
            ),
          ],
          if (!open)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: MarketButton(
                label: LocaleKeys.marketViewDetails.tr(),
                variant: MarketButtonVariant.more,
                onPressed: toggle,
              ),
            ),
          if (open) ...[
            field(LocaleKeys.marketSolutionGoodFor.tr(), s.applicableWhen),
            field(LocaleKeys.marketSolutionHowItWorks.tr(), s.method),
            field(
              LocaleKeys.marketSolutionExpectedResult.tr(),
              s.expectedResult,
            ),
            field(LocaleKeys.marketSolutionImportant.tr(), s.notes),
            if (s.hashtags.isNotEmpty) ...[
              Gap(12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 4.h,
                children: [
                  for (final h in s.hashtags) Text('#$h', style: metaStyle),
                ],
              ),
            ],
            Gap(16.h),
            MarketCardFooter(
              leading: Align(
                alignment: Alignment.centerLeft,
                child: MarketButton(
                  label: LocaleKeys.marketSolutionWant.tr(),
                  variant: MarketButtonVariant.link,
                  onPressed: () => onWant(s),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
