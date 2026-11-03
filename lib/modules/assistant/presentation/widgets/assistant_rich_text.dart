import 'package:flutter/material.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';

/// Câu trả lời của tài liệu (RAG) có Markdown nhẹ (web `RichText` của chat trợ lý): giữ
/// xuống dòng, bỏ ** / #, bỏ số trích nguồn [1][2]; link `[chữ](url)` và URL trơn tô màu.
/// Chữ chọn được để khách chép link (app chưa có trình mở link ngoài).
class AssistantRichText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Widget? trailing;

  const AssistantRichText({
    super.key,
    required this.text,
    required this.style,
    this.trailing,
  });

  static final _link = RegExp(
    r'''\[([^\]]+)\]\((https?://[^)\s]+)\)|(https?://[^\s<>"')\]]*[^\s<>"')\].,;:!?])''',
  );
  static final _citation = RegExp(r'\s*(?:\[\d{1,2}\])+(?!\()');

  static String clean(String text) => text
      .replaceAll(_citation, '')
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!)
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');

  @override
  Widget build(BuildContext context) {
    final value = clean(text);
    final linkStyle = style.copyWith(
      color: Colour.primary,
      decoration: TextDecoration.underline,
      decorationColor: Colour.primary.withValues(alpha: 0.4),
    );
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _link.allMatches(value)) {
      if (m.start > last) {
        spans.add(TextSpan(text: value.substring(last, m.start)));
      }
      final label = m[1];
      final url = m[2] ?? m[3]!;
      spans.add(TextSpan(text: label ?? url, style: linkStyle));
      if (label != null) spans.add(TextSpan(text: ' ($url)'));
      last = m.end;
    }
    spans.add(TextSpan(text: value.substring(last)));
    if (trailing != null) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: trailing,
          ),
        ),
      );
    }
    return SelectableText.rich(TextSpan(style: style, children: spans));
  }
}
