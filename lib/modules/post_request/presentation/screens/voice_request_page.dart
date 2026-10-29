import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/services/microphone_permission_service.dart';
import 'package:strongbody_buyer/modules/home/presentation/home_composer_focus.dart';

import '../bloc/voice_request/voice_request_bloc.dart';
import '../post_request_flow_args.dart';
import '../voice_request_page_args.dart';
import '../widgets/voice/voice_controls.dart';
import '../widgets/voice/voice_language_chip.dart';
import '../widgets/voice/voice_problem_view.dart';
import '../widgets/voice/voice_status_line.dart';
import '../widgets/voice/voice_transcript.dart';
import '../widgets/voice/voice_waveform.dart';

/// Màn nói yêu cầu: transcript hiện trực tiếp, tự dừng sau 4s im lặng,
/// ✓ → "Here's what I heard" (AI phân tích transcript, voice note gửi kèm request).
class VoiceRequestPage extends StatefulWidget {
  final VoiceRequestPageArgs args;

  const VoiceRequestPage({super.key, required this.args});

  @override
  State<VoiceRequestPage> createState() => _VoiceRequestPageState();
}

class _VoiceRequestPageState extends State<VoiceRequestPage>
    with WidgetsBindingObserver {
  VoiceRequestPageArgs get args => widget.args;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Quay lại từ Cài đặt (đã bật micro) → nghe lại luôn.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final bloc = context.read<VoiceRequestBloc>();
    if (bloc.state.problem == VoiceRequestProblem.micOff) {
      bloc.add(const VoiceRequestRetried());
    }
  }

  /// "Type instead": refine → về màn trước; còn lại → Home, mở bàn phím ô nhập.
  void _typeInstead(BuildContext context) {
    if (args.refine) {
      context.pop();
      return;
    }
    HomeComposerFocus.request(args.attachmentPaths);
    context.go(RouteName.rootScreen);
  }

  void _close(BuildContext context) {
    // Trả file đính kèm về ô nhập ở Home (người dùng huỷ, chưa gửi).
    context.pop(args.refine ? null : args.attachmentPaths);
  }

  void _onStateChanged(BuildContext context, VoiceRequestState state) {
    final bloc = context.read<VoiceRequestBloc>();
    final result = state.result;
    if (result != null) {
      bloc.add(const VoiceRequestOneShotConsumed());
      if (args.refine) {
        context.pop(result.text);
        return;
      }
      context.pushReplacement(
        RouteName.requestHeard,
        extra: PostRequestFlowArgs(
          text: result.text,
          voicePath: result.voicePath,
          voiceDuration: result.voiceDuration,
          languageCode: result.languageCode,
          attachmentPaths: args.attachmentPaths,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<VoiceRequestBloc, VoiceRequestState>(
      listenWhen: (previous, current) =>
          current.result != null && previous.result != current.result,
      listener: _onStateChanged,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close(context);
        },
        child: Scaffold(
          backgroundColor: theme.surface(context),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Gap(8.h),
                  Row(
                    children: [
                      _CloseButton(onTap: () => _close(context)),
                      const Spacer(),
                      const VoiceLanguageChip(),
                    ],
                  ),
                  BlocSelector<
                    VoiceRequestBloc,
                    VoiceRequestState,
                    VoiceRequestProblem?
                  >(
                    selector: (state) => state.problem,
                    builder: (context, problem) => Expanded(
                      child: problem != null
                          ? VoiceProblemView(
                              problem: problem,
                              onTryAgain: () => context
                                  .read<VoiceRequestBloc>()
                                  .add(const VoiceRequestRetried()),
                              onOpenSettings: () =>
                                  getIt<MicrophonePermissionService>()
                                      .openSettings(),
                              onTypeInstead: () => _typeInstead(context),
                            )
                          : _listeningBody(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on _VoiceRequestPageState {
  Widget _listeningBody(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Gap(18.h),
        const VoiceStatusLine(),
        Gap(2.h),
        Text(
          args.refine
              ? LocaleKeys.voiceRequestRefineHint.tr()
              : LocaleKeys.voiceRequestHint.tr(),
          style: TextStyle(
            fontSize: 12.sp,
            color: theme.textSecondary(context),
          ),
        ),
        Gap(16.h),
        const Expanded(child: VoiceTranscript()),
        Gap(12.h),
        const Center(child: VoiceWaveform()),
        Gap(24.h),
        const VoiceControls(),
        Gap(14.h),
        Center(
          child: Text(
            LocaleKeys.voiceRequestFooter.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              color: theme.textSecondary(context),
            ),
          ),
        ),
        Gap(12.h),
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.muted(context),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 44.r,
          child: Icon(
            Icons.close_rounded,
            size: 22.r,
            color: theme.textPrimary(context),
            semanticLabel: LocaleKeys.voiceRequestClose.tr(),
          ),
        ),
      ),
    );
  }
}
