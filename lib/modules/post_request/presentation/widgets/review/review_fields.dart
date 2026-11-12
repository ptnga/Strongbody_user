import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../request_formatters.dart';

/// Dòng voice note: micro · "Your voice note · 0:09" · thùng rác.
class ReviewVoiceNoteRow extends StatelessWidget {
  final Duration? duration;
  final VoidCallback onRemove;

  /// Đã bấm xoá → nút "Undo remove" thay cho thùng rác.
  final bool removed;
  final VoidCallback onUndo;

  const ReviewVoiceNoteRow({
    super.key,
    required this.duration,
    required this.onRemove,
    required this.onUndo,
    this.removed = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 4.w, 12.h),
      decoration: BoxDecoration(
        color: theme.surface(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: theme.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
              color: theme.muted(context),
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              AppSvg.microphone,
              size: 20.r,
              color: theme.textPrimary(context),
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.reviewVoiceNote.tr(
                    args: [
                      RequestFormatters.duration(duration ?? Duration.zero),
                    ],
                  ),
                  style: AppTextStyle.lightBodyMediumBold.copyWith(
                    color: theme.textPrimary(context),
                  ),
                ),
                Text(
                  LocaleKeys.reviewVoiceNoteHint.tr(),
                  style: AppTextStyle.lightBodySmallRegular.copyWith(
                    color: theme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          if (removed)
            // Co lại được khi chữ dài (ngôn ngữ khác) thay vì tràn hàng.
            Flexible(
              child: Padding(
                padding: EdgeInsets.only(left: 8.w, right: 8.w),
                child: OutlinedButton(
                  onPressed: onUndo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.textPrimary(context),
                    side: BorderSide(color: theme.border(context)),
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    minimumSize: Size(0, 36.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    textStyle: AppTextStyle.lightBodySmallSemiBold,
                  ),
                  child: Text(
                    LocaleKeys.reviewUndoRemoveVoice.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: LocaleKeys.reviewRemoveVoice.tr(),
              onPressed: onRemove,
              icon: AppIcon(
                AppSvg.trash,
                size: 22.r,
                color: theme.textSecondary(context),
              ),
            ),
        ],
      ),
    );
  }
}
