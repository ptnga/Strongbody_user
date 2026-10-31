import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';

import 'market_ui.dart';

/// Mô tả giới hạn 2 dòng, "Show more / Show less" khi tràn — đồng bộ trạng thái mở
/// của card (web `ClampText`).
class MarketClampText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final bool open;
  final VoidCallback onToggle;
  final int lines;

  const MarketClampText({
    super.key,
    required this.text,
    required this.style,
    required this.open,
    required this.onToggle,
    this.lines = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: lines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflow = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              maxLines: open ? null : lines,
              overflow: open ? null : TextOverflow.ellipsis,
              style: style,
            ),
            if (overflow)
              Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: MarketButton(
                  label: open
                      ? LocaleKeys.marketShowLess.tr()
                      : LocaleKeys.marketShowMore.tr(),
                  variant: MarketButtonVariant.more,
                  onPressed: onToggle,
                ),
              ),
          ],
        );
      },
    );
  }
}
