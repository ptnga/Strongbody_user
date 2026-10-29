import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/themes/theme.dart';

import '../common/flow_header.dart';

/// Thẻ lựa chọn ở "What would you like to do?". `primary` = nền tối (Post request).
class HeardActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final bool loading;
  final VoidCallback? onTap;

  const HeardActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.primary = false,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = primary ? Colors.white : theme.textPrimary(context);
    final secondary = primary
        ? Colors.white.withValues(alpha: 0.78)
        : theme.textSecondary(context);
    return Material(
      color: primary ? theme.secondary(context) : theme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: primary
            ? BorderSide.none
            : BorderSide(color: theme.border(context)),
      ),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Row(
            children: [
              loading
                  ? SizedBox.square(
                      dimension: 44.r,
                      child: CupertinoActivityIndicator(
                        color: primary ? Colors.white : null,
                      ),
                    )
                  : FlowIconBox(
                      icon: icon,
                      size: 44.r,
                      background: primary
                          ? Colors.white.withValues(alpha: 0.14)
                          : theme.muted(context),
                      color: foreground,
                    ),
              Gap(14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                    Gap(2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13.sp,
                        height: 1.3,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
