import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';

/// Hỏi lại trước khi chặn, kèm ba hệ quả (mirror Multime `block_user_confirm_sheet`).
class BlockUserConfirmSheet extends StatelessWidget {
  const BlockUserConfirmSheet._({required this.userName});

  final String userName;

  /// Trả `true` khi người dùng xác nhận chặn.
  static Future<bool> show(
    BuildContext context, {
    required String userName,
  }) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).surface(context),
      builder: (_) => BlockUserConfirmSheet._(userName: userName),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.blockUserQuestion.tr(args: [userName]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.lightHeadingSmall.copyWith(
              color: theme.textPrimary(context),
            ),
          ),
          Gap(14.h),
          _bullet(context, LocaleKeys.blockUserBullet1.tr()),
          Gap(8.h),
          _bullet(context, LocaleKeys.blockUserBullet2.tr()),
          Gap(8.h),
          _bullet(context, LocaleKeys.blockUserBullet3.tr()),
          Gap(22.h),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50.h,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.textPrimary(context),
                      side: BorderSide(color: theme.border(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(LocaleKeys.commonCancel.tr()),
                  ),
                ),
              ),
              Gap(10.w),
              Expanded(
                child: SizedBox(
                  height: 50.h,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colour.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(LocaleKeys.blockConfirm.tr()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 7.h),
          child: Container(
            width: 5.w,
            height: 5.w,
            decoration: BoxDecoration(
              color: theme.textSecondary(context),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Gap(10.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyle.lightBodySmallRegular.copyWith(
              height: 1.45,
              color: theme.textSecondary(context),
            ),
          ),
        ),
      ],
    );
  }
}
