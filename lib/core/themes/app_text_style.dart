import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../design_tokens/colour.dart';
import 'app_font_family.dart';

/// Thang chữ — giống hệt Multime `core/themes/app_text_style.dart` (cùng tên, cỡ, weight).
///
/// Heading 48/40/32/24/20/18 Bold · Body XLarge 18 · Large 16 · Medium 14 · Small 12 ·
/// XSmall 10, mỗi cỡ Bold 700 / SemiBold 600 / Medium 500 / Regular 400.
/// Dùng: `AppTextStyle.lightBodyMediumRegular.copyWith(color: ...)` hoặc
/// `Theme.of(context).textTheme.lightBodyMediumRegular` (như Multime). Không tự đặt
/// `fontSize` / `fontWeight` lệch thang.
abstract final class AppTextStyle {
  static TextStyle _style(double size, FontWeight weight) => TextStyle(
    color: Colour.textPrimary,
    fontSize: size.sp,
    fontFamily: AppFontFamily.plusJakartaSans,
    fontWeight: weight,
  );

  // Heading
  static TextStyle get lightHeadingXLarge => _style(48, FontWeight.w700);
  static TextStyle get lightHeadingLarge => _style(40, FontWeight.w700);
  static TextStyle get lightHeadingMediumLarge => _style(32, FontWeight.w700);
  static TextStyle get lightHeadingMedium => _style(24, FontWeight.w700);
  static TextStyle get lightHeadingSmall => _style(20, FontWeight.w700);
  static TextStyle get lightHeadingXSmall => _style(18, FontWeight.w700);

  // Body · X Large
  static TextStyle get lightBodyXLargeBold => _style(18, FontWeight.w700);
  static TextStyle get lightBodyXLargeSemiBold => _style(18, FontWeight.w600);
  static TextStyle get lightBodyXLargeMedium => _style(18, FontWeight.w500);
  static TextStyle get lightBodyXLargeRegular => _style(18, FontWeight.w400);

  // Body · Large
  static TextStyle get lightBodyLargeBold => _style(16, FontWeight.w700);
  static TextStyle get lightBodyLargeSemiBold => _style(16, FontWeight.w600);
  static TextStyle get lightBodyLargeMedium => _style(16, FontWeight.w500);
  static TextStyle get lightBodyLargeRegular => _style(16, FontWeight.w400);

  // Body · Medium
  static TextStyle get lightBodyMediumBold => _style(14, FontWeight.w700);
  static TextStyle get lightBodyMediumSemiBold => _style(14, FontWeight.w600);
  static TextStyle get lightBodyMediumMedium => _style(14, FontWeight.w500);
  static TextStyle get lightBodyMediumRegular => _style(14, FontWeight.w400);

  // Body · Small
  static TextStyle get lightBodySmallBold => _style(12, FontWeight.w700);
  static TextStyle get lightBodySmallSemiBold => _style(12, FontWeight.w600);
  static TextStyle get lightBodySmallMedium => _style(12, FontWeight.w500);
  static TextStyle get lightBodySmallRegular => _style(12, FontWeight.w400);

  // Body · X Small
  static TextStyle get lightBodyXSmallBold => _style(10, FontWeight.w700);
  static TextStyle get lightBodyXSmallSemiBold => _style(10, FontWeight.w600);
  static TextStyle get lightBodyXSmallMedium => _style(10, FontWeight.w500);
  static TextStyle get lightBodyXSmallRegular => _style(10, FontWeight.w400);
}

/// `Theme.of(context).textTheme.lightBodyMediumBold` — cùng API Multime `CustomTextStyles`.
extension CustomTextStyles on TextTheme {
  TextStyle get lightHeadingXLarge => AppTextStyle.lightHeadingXLarge;
  TextStyle get lightHeadingLarge => AppTextStyle.lightHeadingLarge;
  TextStyle get lightHeadingMediumLarge => AppTextStyle.lightHeadingMediumLarge;
  TextStyle get lightHeadingMedium => AppTextStyle.lightHeadingMedium;
  TextStyle get lightHeadingSmall => AppTextStyle.lightHeadingSmall;
  TextStyle get lightHeadingXSmall => AppTextStyle.lightHeadingXSmall;

  TextStyle get lightBodyXLargeBold => AppTextStyle.lightBodyXLargeBold;
  TextStyle get lightBodyXLargeSemiBold => AppTextStyle.lightBodyXLargeSemiBold;
  TextStyle get lightBodyXLargeMedium => AppTextStyle.lightBodyXLargeMedium;
  TextStyle get lightBodyXLargeRegular => AppTextStyle.lightBodyXLargeRegular;

  TextStyle get lightBodyLargeBold => AppTextStyle.lightBodyLargeBold;
  TextStyle get lightBodyLargeSemiBold => AppTextStyle.lightBodyLargeSemiBold;
  TextStyle get lightBodyLargeMedium => AppTextStyle.lightBodyLargeMedium;
  TextStyle get lightBodyLargeRegular => AppTextStyle.lightBodyLargeRegular;

  TextStyle get lightBodyMediumBold => AppTextStyle.lightBodyMediumBold;
  TextStyle get lightBodyMediumSemiBold => AppTextStyle.lightBodyMediumSemiBold;
  TextStyle get lightBodyMediumMedium => AppTextStyle.lightBodyMediumMedium;
  TextStyle get lightBodyMediumRegular => AppTextStyle.lightBodyMediumRegular;

  TextStyle get lightBodySmallBold => AppTextStyle.lightBodySmallBold;
  TextStyle get lightBodySmallSemiBold => AppTextStyle.lightBodySmallSemiBold;
  TextStyle get lightBodySmallMedium => AppTextStyle.lightBodySmallMedium;
  TextStyle get lightBodySmallRegular => AppTextStyle.lightBodySmallRegular;

  TextStyle get lightBodyXSmallBold => AppTextStyle.lightBodyXSmallBold;
  TextStyle get lightBodyXSmallSemiBold => AppTextStyle.lightBodyXSmallSemiBold;
  TextStyle get lightBodyXSmallMedium => AppTextStyle.lightBodyXSmallMedium;
  TextStyle get lightBodyXSmallRegular => AppTextStyle.lightBodyXSmallRegular;
}
