import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

/// Tiêu đề nhóm ("Voice & language").
class AccountSectionTitle extends StatelessWidget {
  final String title;

  const AccountSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(4.w, 18.h, 4.w, 8.h),
    child: Text(
      title,
      style: AppTextStyle.lightBodySmallBold.copyWith(
        color: Theme.of(context).textSecondary(context),
      ),
    ),
  );
}

/// Thẻ trắng bo góc chứa các dòng, có vạch ngăn.
class AccountGroup extends StatelessWidget {
  final List<Widget> children;

  const AccountGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.surface(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: theme.border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: theme.border(context)),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Dòng điều hướng: icon · nhãn · giá trị · ›
class AccountNavRow extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final String label;
  final String? value;
  final VoidCallback onTap;

  const AccountNavRow({
    super.key,
    this.icon,
    this.iconAsset,
    required this.label,
    required this.onTap,
    this.value,
  }) : assert(icon != null || iconAsset != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
        child: Row(
          children: [
            iconAsset != null
                ? AppIcon(
                    iconAsset!,
                    size: 21.r,
                    color: theme.textPrimary(context),
                  )
                : Icon(icon, size: 21.r, color: theme.textPrimary(context)),
            Gap(14.w),
            Expanded(
              child: Text(
                label,
                style: AppTextStyle.lightBodyMediumRegular.copyWith(
                  color: theme.textPrimary(context),
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: AppTextStyle.lightBodyMediumRegular.copyWith(
                  color: theme.textSecondary(context),
                ),
              ),
            Gap(6.w),
            AppIcon(
              AppSvg.chevronRight,
              size: 22.r,
              color: theme.textTertiary(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dòng bật/tắt: tiêu đề + mô tả · Switch.
class AccountSwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const AccountSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 10.w, 10.h),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyle.lightBodyMediumRegular.copyWith(
                      color: theme.textPrimary(context),
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    subtitle,
                    style: AppTextStyle.lightBodySmallRegular.copyWith(
                      height: 1.3,
                      color: theme.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Gap(10.w),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: theme.secondary(context),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: theme.border(context),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}
