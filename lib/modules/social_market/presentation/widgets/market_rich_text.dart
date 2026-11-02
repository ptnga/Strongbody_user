import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

/// Nội dung rich text của service (admin nhập bằng editor HTML, seller nhập chữ
/// thường từng dòng — web `asHtml` / `ItemList`) → đoạn văn + gạch đầu dòng.
class MarketRichText extends StatelessWidget {
  final String content;
  final Color color;

  /// Màu chấm của gạch đầu dòng (Included xanh, Not included đỏ).
  final Color dotColor;

  const MarketRichText(
    this.content, {
    super.key,
    this.color = Colour.textSecondary,
    this.dotColor = Colour.textSecondary,
  });

  static const _entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
  };

  /// Dòng; dòng bắt đầu bằng `•` là gạch đầu dòng.
  static List<String> lines(String raw) {
    var text = raw
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n•')
        .replaceAll(
          RegExp(r'<br\s*/?>|</(p|div|li|h[1-6]|ul|ol)>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]*>'), '');
    _entities.forEach((k, v) => text = text.replaceAll(k, v));
    return text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .where((l) => l.isNotEmpty && l != '•')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: color,
      height: 1.6,
    );
    final items = lines(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, line) in items.indexed) ...[
          if (i > 0) Gap(8.h),
          if (line.startsWith('•'))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(top: 8.h, right: 8.w),
                  width: 6.r,
                  height: 6.r,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(child: Text(line.substring(1).trim(), style: style)),
              ],
            )
          else
            Text(line, style: style),
        ],
      ],
    );
  }
}
