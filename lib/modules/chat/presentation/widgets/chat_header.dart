import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/components/initials_avatar.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

/// Back · avatar · tên + "Physiotherapist · speaks Vietnamese" · nút "Translate on".
class ChatHeader extends StatelessWidget {
  final int partnerId;
  final String name;
  final String? avatar;
  final String? subtitle;
  final bool translateOn;
  final bool translateBusy;
  final VoidCallback? onTranslate;
  final VoidCallback onBack;

  const ChatHeader({
    super.key,
    required this.partnerId,
    required this.name,
    required this.translateOn,
    required this.onBack,
    this.avatar,
    this.subtitle,
    this.translateBusy = false,
    this.onTranslate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 12.w, 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: theme.textPrimary(context),
            ),
          ),
          InitialsAvatar(
            name: name,
            imageUrl: avatar,
            colorSeed: partnerId,
            size: 40.r,
          ),
          Gap(10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? '—' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.lightBodyLargeBold.copyWith(
                    color: theme.textPrimary(context),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.lightBodySmallRegular.copyWith(
                      height: 1.25,
                      color: theme.textSecondary(context),
                    ),
                  ),
              ],
            ),
          ),
          Gap(8.w),
          OutlinedButton(
            onPressed: translateBusy ? null : onTranslate,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.textPrimary(context),
              side: BorderSide(
                color: translateOn
                    ? theme.textPrimary(context)
                    : theme.border(context),
              ),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              minimumSize: Size(0, 34.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                translateBusy
                    ? SizedBox.square(
                        dimension: 14.r,
                        child: const CupertinoActivityIndicator(radius: 7),
                      )
                    : Icon(Icons.translate_rounded, size: 16.r),
                Gap(5.w),
                Text(
                  translateOn
                      ? LocaleKeys.chatTranslateOn.tr()
                      : LocaleKeys.chatTranslateOff.tr(),
                  style: AppTextStyle.lightBodySmallSemiBold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
