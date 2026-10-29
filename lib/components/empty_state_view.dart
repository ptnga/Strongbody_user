import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

/// Trạng thái trống / lỗi giữa màn: vòng tròn hồng + icon đỏ, tiêu đề, mô tả, nút đỏ.
/// Là ListView cuộn được để vẫn kéo-làm-mới trong `RefreshIndicator`.
class EmptyStateView extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final String? actionIconAsset;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    this.icon,
    this.iconAsset,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.actionIconAsset,
    this.onAction,
  }) : assert(icon != null || iconAsset != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(28.w, 88.h, 28.w, 32.h),
      children: [
        Center(
          child: Container(
            width: 76.r,
            height: 76.r,
            decoration: BoxDecoration(
              color: theme.primaryLight(context),
              shape: BoxShape.circle,
            ),
            child: iconAsset != null
                ? AppIcon(iconAsset!, size: 32.r, color: theme.primary(context))
                : Icon(icon, size: 32.r, color: theme.primary(context)),
          ),
        ),
        Gap(18.h),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyle.lightBodyXLargeBold.copyWith(
            color: theme.textPrimary(context),
          ),
        ),
        Gap(6.h),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            height: 1.4,
            color: theme.textSecondary(context),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          Gap(20.h),
          Center(
            child: FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary(context),
                padding: EdgeInsets.symmetric(horizontal: 22.w),
                minimumSize: Size(0, 46.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                textStyle: AppTextStyle.lightBodyMediumBold,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (actionIconAsset != null) ...[
                    AppIcon(actionIconAsset!, size: 19.r),
                    Gap(8.w),
                  ] else if (actionIcon != null) ...[
                    Icon(actionIcon, size: 19.r),
                    Gap(8.w),
                  ],
                  Text(actionLabel!),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
