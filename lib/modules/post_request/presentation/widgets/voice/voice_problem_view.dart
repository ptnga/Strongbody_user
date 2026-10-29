import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';

import '../../bloc/voice_request/voice_request_bloc.dart';

/// Màn lỗi thay cho snackbar: "Sorry, I didn't catch that" / "Turn on your microphone" /
/// máy không nhận giọng nói. Nút chính: Try again / Open settings; phụ: Type instead.
class VoiceProblemView extends StatelessWidget {
  final VoiceRequestProblem problem;
  final VoidCallback onTryAgain;
  final VoidCallback onOpenSettings;
  final VoidCallback onTypeInstead;

  const VoiceProblemView({
    super.key,
    required this.problem,
    required this.onTryAgain,
    required this.onOpenSettings,
    required this.onTypeInstead,
  });

  static const _amberBg = Color(0xFFFCF1DE);
  static const _amber = Color(0xFF9A5B0B);
  static const _pinkBg = Color(0xFFFBE7E8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (
      IconData icon,
      Color bg,
      Color fg,
      String title,
      String message,
    ) = switch (problem) {
      VoiceRequestProblem.noSpeech => (
        Icons.volume_off_outlined,
        _amberBg,
        _amber,
        LocaleKeys.voiceProblemNoSpeechTitle.tr(),
        LocaleKeys.voiceProblemNoSpeechMessage.tr(),
      ),
      VoiceRequestProblem.micOff => (
        Icons.mic_off_outlined,
        _pinkBg,
        theme.primary(context),
        LocaleKeys.voiceProblemMicTitle.tr(),
        LocaleKeys.voiceProblemMicMessage.tr(),
      ),
      VoiceRequestProblem.unavailable => (
        Icons.mic_off_outlined,
        theme.muted(context),
        theme.textSecondary(context),
        LocaleKeys.voiceProblemUnavailableTitle.tr(),
        LocaleKeys.voiceProblemUnavailableMessage.tr(),
      ),
    };
    final primary = switch (problem) {
      VoiceRequestProblem.noSpeech => (
        LocaleKeys.voiceProblemTryAgain.tr(),
        Icons.mic_none_rounded,
        onTryAgain,
      ),
      VoiceRequestProblem.micOff => (
        LocaleKeys.voiceProblemOpenSettings.tr(),
        null,
        onOpenSettings,
      ),
      VoiceRequestProblem.unavailable => null,
    };
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.r),
    );
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 22.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 80.r,
                height: 80.r,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 34.r, color: fg),
              ),
            ),
            Gap(18.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary(context),
              ),
            ),
            Gap(8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                height: 1.4,
                color: theme.textSecondary(context),
              ),
            ),
            Gap(22.h),
            if (primary != null) ...[
              SizedBox(
                height: 48.h,
                child: FilledButton(
                  onPressed: primary.$3,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary(context),
                    shape: shape,
                    textStyle: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (primary.$2 != null) ...[
                        Icon(primary.$2, size: 20.r),
                        Gap(6.w),
                      ],
                      Text(primary.$1),
                    ],
                  ),
                ),
              ),
              Gap(10.h),
            ],
            SizedBox(
              height: 48.h,
              child: OutlinedButton(
                onPressed: onTypeInstead,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textPrimary(context),
                  side: BorderSide(color: theme.border(context)),
                  shape: shape,
                  textStyle: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(LocaleKeys.voiceProblemTypeInstead.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
