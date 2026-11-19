import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/components/strongbody_logo.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

/// Hero trang chủ mobile (web `HomeHero mobile`): ảnh đội ngũ chuyên gia tràn hết bề ngang
/// (khung 20:9, neo trên) + nhãn "StrongBody.ai" ở góc dưới phải ảnh → tiêu đề (cụm đầu
/// tô xanh) → dòng các nghề. Card trắng, chỉ viền dưới.
class HomeHero extends StatelessWidget {
  const HomeHero({super.key});

  static const imageAsset = 'assets/images/home_hero_team.webp';

  /// Tên thương hiệu trên nhãn ảnh (không dịch).
  static const _brand = 'StrongBody.ai';

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTextStyle.lightHeadingMedium.copyWith(
      height: 1.25,
      color: Colour.textPrimary,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colour.surface,
        border: Border(bottom: BorderSide(color: Colour.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 20 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Ảnh trang trí (tiêu đề đã nói đủ) → không có nhãn đọc màn hình.
                ExcludeSemantics(
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Colour.subtle),
                  ),
                ),
                PositionedDirectional(
                  end: 12.w,
                  bottom: 12.h,
                  child: const _BrandBadge(label: _brand),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: LocaleKeys.boardHeroTitleLead.tr(),
                          style: const TextStyle(color: Colour.buttonPrimary),
                        ),
                        TextSpan(text: LocaleKeys.boardHeroTitleRest.tr()),
                      ],
                    ),
                    style: titleStyle,
                  ),
                ),
                Gap(8.h),
                Text(
                  // Mỗi nghề không gãy giữa chừng: chỉ xuống dòng ở " · ".
                  LocaleKeys.boardHeroRoles
                      .tr()
                      .split('·')
                      .map((r) => r.trim().replaceAll(' ', ' '))
                      .join(' · '),
                  style: AppTextStyle.lightBodyLargeRegular.copyWith(
                    height: 1.45,
                    color: Colour.textSecondary,
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

class _BrandBadge extends StatelessWidget {
  final String label;

  const _BrandBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsetsDirectional.fromSTEB(8.w, 6.h, 14.w, 6.h),
    decoration: BoxDecoration(
      color: Colour.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(999),
      boxShadow: [
        BoxShadow(
          color: Colour.textPrimary.withValues(alpha: 0.12),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: SvgPicture.asset(
            StrongBodyLogo.markAsset,
            width: 24.r,
            height: 24.r,
          ),
        ),
        Gap(8.w),
        Text(
          label,
          style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
            color: Colour.textPrimary,
          ),
        ),
      ],
    ),
  );
}
