import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:strongbody_buyer/core/themes/theme.dart';

/// Ảnh tròn; không có ảnh (hoặc lỗi tải) → chữ viết tắt trên nền pastel.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;

  /// Chọn màu nền (vị trí trong danh sách, id người dùng…).
  final int colorSeed;
  final double size;
  final bool border;

  const InitialsAvatar({
    super.key,
    required this.name,
    required this.size,
    this.imageUrl,
    this.colorSeed = 0,
    this.border = false,
  });

  static const _palette = [
    (Color(0xFFE3F3EA), Color(0xFF1F6B45)),
    (Color(0xFFE6EEFB), Color(0xFF2F5AA8)),
    (Color(0xFFFBE7EC), Color(0xFFB4234B)),
    (Color(0xFFEEE9FB), Color(0xFF5B3FA8)),
    (Color(0xFFFDF1DC), Color(0xFF8A5A0B)),
    (Color(0xFFF1F2F4), Color(0xFF3B4352)),
  ];

  /// "Mai Pham" → "MP"; một từ → 2 chữ đầu; rỗng → "?".
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final letters = parts.length == 1
        ? parts.first.characters.take(2).toString()
        : '${parts.first.characters.first}${parts.last.characters.first}';
    return letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) =
        _palette[colorSeed.abs() % _palette.length];
    final fallback = Padding(
      padding: EdgeInsets.all(size * 0.18),
      child: FittedBox(
        child: Text(
          initials(name),
          style: TextStyle(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
    final url = imageUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: border
            ? Border.all(color: theme.surface(context), width: 2.r)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
