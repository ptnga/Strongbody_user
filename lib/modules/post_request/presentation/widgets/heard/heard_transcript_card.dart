import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';

import '../../bloc/post_request_flow/post_request_flow_bloc.dart';
import '../../request_formatters.dart';
import '../common/flow_header.dart';
import '../common/voice_note_player.dart';

/// Thẻ trên cùng: voice note (nếu có) + câu đã nói trong ngoặc kép + "Detected: …".
class HeardTranscriptCard extends StatelessWidget {
  const HeardTranscriptCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<PostRequestFlowBloc, PostRequestFlowState>(
      buildWhen: (previous, current) =>
          previous.transcript != current.transcript ||
          previous.values.voicePath != current.values.voicePath ||
          previous.isAnalyzing != current.isAnalyzing,
      builder: (context, state) {
        final voicePath = state.values.voicePath;
        final language = RequestFormatters.languageName(state.languageCode);
        final detected = switch ((language, voicePath != null)) {
          (final String name, true) => LocaleKeys.heardDetectedVoiceKept.tr(
            args: [name],
          ),
          (final String name, false) => LocaleKeys.heardDetected.tr(
            args: [name],
          ),
          (null, true) => LocaleKeys.heardVoiceKept.tr(),
          (null, false) => null,
        };
        final transcribing = state.isAnalyzing && state.transcript.isEmpty;

        return FlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (voicePath != null) ...[
                VoiceNotePlayer(
                  path: voicePath,
                  duration: state.values.voiceDuration,
                ),
                Gap(14.h),
              ],
              Text(
                transcribing
                    ? LocaleKeys.heardTranscribing.tr()
                    : '“${state.transcript}”',
                style: TextStyle(
                  fontSize: 16.sp,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: transcribing
                      ? theme.textTertiary(context)
                      : theme.textPrimary(context),
                ),
              ),
              if (detected != null) ...[
                Gap(8.h),
                Text(
                  detected,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: theme.textSecondary(context),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
