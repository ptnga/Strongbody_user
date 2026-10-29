import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';

import '../../bloc/voice_request/voice_request_bloc.dart';

/// "● Listening…" (đỏ) / "● Got it. Tap ✓ to continue" (xanh) / tạm dừng (xám).
class VoiceStatusLine extends StatelessWidget {
  const VoiceStatusLine({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocSelector<
      VoiceRequestBloc,
      VoiceRequestState,
      VoiceRequestStatus
    >(
      // Dừng mà chưa nghe được chữ nào → không báo "Got it".
      selector: (state) =>
          state.status == VoiceRequestStatus.done && state.transcript.isEmpty
          ? VoiceRequestStatus.paused
          : state.status,
      builder: (context, status) {
        final nothingHeard =
            status == VoiceRequestStatus.paused &&
            context.read<VoiceRequestBloc>().state.status ==
                VoiceRequestStatus.done;
        final (String text, Color color) = switch (status) {
          VoiceRequestStatus.listening => (
            LocaleKeys.voiceRequestListening.tr(),
            theme.primary(context),
          ),
          VoiceRequestStatus.done => (
            LocaleKeys.voiceRequestGotIt.tr(),
            Colour.success,
          ),
          VoiceRequestStatus.paused => (
            nothingHeard
                ? LocaleKeys.voiceRequestNothing.tr()
                : LocaleKeys.voiceRequestPaused.tr(),
            theme.textSecondary(context),
          ),
          VoiceRequestStatus.initializing || VoiceRequestStatus.unavailable => (
            LocaleKeys.voiceRequestStarting.tr(),
            theme.textSecondary(context),
          ),
        };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Row(
            key: ValueKey(status),
            children: [
              _Dot(color: color, pulse: status == VoiceRequestStatus.listening),
              Gap(8.w),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final bool pulse;

  const _Dot({required this.color, required this.pulse});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Tạo ngay trong initState (không lazy) để dispose không tạo ticker lúc đã deactivate.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.35,
    );
    if (widget.pulse) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.pulse ? _controller : const AlwaysStoppedAnimation(1),
      child: Container(
        width: 8.r,
        height: 8.r,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
