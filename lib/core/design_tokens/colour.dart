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
}
