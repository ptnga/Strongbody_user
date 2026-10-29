import 'package:flutter/material.dart';

import '../design_tokens/colour.dart';
import 'app_font_family.dart';
import 'app_text_style.dart';

class AppThemeClass {
  AppThemeClass._();

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: AppFontFamily.plusJakartaSans,
    scaffoldBackgroundColor: Colour.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colour.primary,
      primary: Colour.primary,
      secondary: Colour.secondary,
      surface: Colour.surface,
      error: Colour.error,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colour.surface,
      foregroundColor: Colour.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyle.lightBodyLargeBold,
    ),
    dividerColor: Colour.border,
    hintColor: Colour.textTertiary,
    // Thang chữ + map vào TextTheme giống Multime `AppThemeClass.lightTheme`.
    textTheme: TextTheme(
      headlineLarge: AppTextStyle.lightHeadingLarge,
      headlineMedium: AppTextStyle.lightHeadingMedium,
      headlineSmall: AppTextStyle.lightHeadingSmall,
      titleLarge: AppTextStyle.lightBodyLargeBold,
      titleMedium: AppTextStyle.lightBodyMediumBold,
      titleSmall: AppTextStyle.lightBodySmallBold,
      bodyLarge: AppTextStyle.lightBodyLargeMedium,
      bodyMedium: AppTextStyle.lightBodyMediumMedium,
      bodySmall: AppTextStyle.lightBodySmallMedium,
      displayLarge: AppTextStyle.lightBodyXLargeMedium,
      displayMedium: AppTextStyle.lightBodyLargeMedium,
      displaySmall: AppTextStyle.lightBodyMediumMedium,
      labelLarge: AppTextStyle.lightBodyLargeMedium,
      labelMedium: AppTextStyle.lightBodyMediumMedium,
      labelSmall: AppTextStyle.lightBodySmallMedium,
    ),
    inputDecorationTheme: InputDecorationTheme(
      errorMaxLines: 2,
      hintStyle: AppTextStyle.lightBodySmallMedium.copyWith(
        color: Colour.textTertiary,
        fontWeight: FontWeight.w400,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      contentTextStyle: AppTextStyle.lightBodyMediumRegular.copyWith(
        color: Colour.surface,
      ),
    ),
  );
}

/// Màu theo theme — gọi `Theme.of(context).primary(context)`.
/// Nhận [BuildContext] để sau này hỗ trợ dark mode mà không đổi API.
extension LightTheme on ThemeData {
  Color primary(BuildContext context) => Colour.primary;
  Color primaryLight(BuildContext context) => Colour.primaryLight;
  Color secondary(BuildContext context) => Colour.secondary;
  Color textPrimary(BuildContext context) => Colour.textPrimary;
  Color textSecondary(BuildContext context) => Colour.textSecondary;
  Color textTertiary(BuildContext context) => Colour.textTertiary;
  Color background(BuildContext context) => Colour.background;
  Color surface(BuildContext context) => Colour.surface;
  Color muted(BuildContext context) => Colour.muted;
  Color border(BuildContext context) => Colour.border;
}
