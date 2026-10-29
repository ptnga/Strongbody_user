import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/themes/theme.dart';

/// Header "← Tiêu đề" căn trái + vạch dưới (màn Heard / Review / Providers / My requests).
class FlowHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  const FlowHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface(context),
        border: Border(bottom: BorderSide(color: theme.border(context))),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(4.w, 4.h, 12.w, 4.h),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_rounded,
                size: 24.r,
                color: theme.textPrimary(context),
              ),
            ),
            Gap(2.w),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary(context),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Thẻ trắng bo góc có viền mảnh — khung chung của các khối trong luồng request.
class FlowCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const FlowCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: theme.surface(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: theme.border(context)),
      ),
      child: child,
    );
  }
}

/// Ô vuông bo góc nền xám chứa icon (đầu dòng "I understood", thẻ hành động...).
class FlowIconBox extends StatelessWidget {
  final IconData icon;
  final Color? background;
  final Color? color;
  final double? size;

  const FlowIconBox({
    super.key,
    required this.icon,
    this.background,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimension = size ?? 40.r;
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: background ?? theme.muted(context),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Icon(
        icon,
        size: dimension * 0.5,
        color: color ?? theme.textPrimary(context),
      ),
    );
  }
}
