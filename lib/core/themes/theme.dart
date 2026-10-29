import 'package:flutter/material.dart';

import '../design_tokens/colour.dart';
import 'app_font_family.dart';

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
    appBarTheme: const AppBarTheme(
      backgroundColor: Colour.surface,
      foregroundColor: Colour.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    dividerColor: Colour.border,
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
