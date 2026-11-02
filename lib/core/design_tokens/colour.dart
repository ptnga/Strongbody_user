import 'package:flutter/material.dart';

/// Design tokens màu — dùng cho component không có `BuildContext`.
/// Trong widget ưu tiên extension `Theme.of(context).primary(context)`.
class Colour {
  Colour._();

  // Brand
  static const Color primary = Color(0xFFDA1F27);
  static const Color primaryLight = Color(0xFFFDECEC);
  static const Color secondary = Color(0xFF1F2C43);

  // Text — như Multime `AppColors.textPrimary` / `textSecondary`.
  static const Color textPrimary = Color(0xFF1F2D44);
  static const Color textSecondary = Color(0xFF738093);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Surface
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);

  /// Nền xám nhạt: ô nhập "Ask StrongBody", pill, avatar.
  static const Color muted = Color(0xFFF2F3F5);
  static const Color border = Color(0xFFE5E7EB);

  // Semantic
  static const Color success = Color(0xFF1C906C);
  static const Color error = Color(0xFFE03137);

  // Marketplace — token web `src/styles/tokens.css` (Social Market dùng y nguyên).
  static const Color brand50 = Color(0xFFFFEAEE);
  static const Color seller = Color(0xFF1C906C);
  static const Color seller25 = Color(0xFFF0F9F6);
  static const Color seller50 = Color(0xFFE0F1EC);
  static const Color seller800 = Color(0xFF0C6445);
  static const Color subtle = Color(0xFFF3F4F6);
  static const Color mutedWeb = Color(0xFFF9FAFB);
  static const Color lineStrong = Color(0xFFD1D5DB);
  static const Color lineSubtle = Color(0xFFF1F2F4);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber700 = Color(0xFFB45309);
  static const Color info50 = Color(0xFFEAF4FE);
  static const Color blue700 = Color(0xFF1D4ED8);
}
