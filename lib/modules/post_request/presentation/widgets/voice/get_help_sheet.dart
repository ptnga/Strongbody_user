import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/services/voice_note_recorder.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../post_request_flow_args.dart';

/// Nút "Get help" (giữa thanh dưới) → sheet ghi âm (web `VoiceRequestSheet` +
/// `RequestComposer startInVoice`): mở ra là bật micro, sóng âm theo giọng nói thật,
/// gửi là sang màn "Post a request" để AI soạn form. Không hiện transcript. Không bật
/// được micro thì còn ô nhập để gõ.
Future<void> showGetHelpSheet(BuildContext context, {required String source}) {
  AppAnalytics.capture(AnalyticsEvents.voiceRequestOpened, {'source': source});
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => const _GetHelpSheet(),
  );
}

class _GetHelpSheet extends StatefulWidget {
  const _GetHelpSheet();

  @override
  State<_GetHelpSheet> createState() => _GetHelpSheetState();
}

enum _Mode { starting, recording, typing }

class _GetHelpSheetState extends State<_GetHelpSheet> {
  /// Giới hạn ghi âm (web `MAX_SECONDS`) — hết giờ tự gửi.
  static const _maxSeconds = 120;
  static const _bars = 32;

  final _recorder = getIt<VoiceNoteRecorder>();
  final _text = TextEditingController();
  final _levels = List<double>.filled(_bars, 0.08);
  StreamSubscription<double>? _levelSub;
  Timer? _clock;
  _Mode _mode = _Mode.starting;
  int _seconds = 0;
  bool _sending = false;

  /// Đang tạm dừng: đồng hồ đứng, sóng phẳng; gửi vẫn được.
  bool _paused = false;

  /// Đã gửi / đã chuyển sang màn kết quả → không huỷ bản ghi khi sheet đóng.
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final ok = await _recorder.start(standalone: true);
    if (!mounted) return;
    if (!ok) {
      setState(() => _mode = _Mode.typing);
      return;
    }
    _levelSub = _recorder.levels.listen((level) {
      if (!mounted || _paused) return;
      setState(() {
        _levels.removeAt(0);
        _levels.add(level.clamp(0.08, 1.0));
      });
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused) return;
      setState(() => _seconds++);
      if (_seconds >= _maxSeconds) _sendVoice();
    });
    setState(() => _mode = _Mode.recording);
  }

  Future<void> _sendVoice() async {
    if (_sending) return;
    setState(() => _sending = true);
    _clock?.cancel();
    await _levelSub?.cancel();
    final note = await _recorder.stop();
    if (!mounted) return;
    if (note == null) {
      // Không có tiếng → cho gõ thay.
      setState(() {
        _sending = false;
        _mode = _Mode.typing;
      });
      return;
    }
    _open(
      PostRequestFlowArgs(
        audioPath: note.path,
        voiceDuration: note.duration,
        attachVoice: getIt<UserPreferences>().attachVoiceToRequests,
      ),
    );
  }

  Future<void> _togglePause() async {
    if (_sending) return;
    final pause = !_paused;
    setState(() => _paused = pause);
    pause ? await _recorder.pause() : await _recorder.resume();
  }

  void _sendText() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _open(PostRequestFlowArgs(text: text));
  }

  void _open(PostRequestFlowArgs args) {
    _handedOff = true;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(RouteName.postRequest, extra: args);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _levelSub?.cancel();
    if (!_handedOff) _recorder.discard();
    _text.dispose();
    super.dispose();
  }

  String get _time {
    final m = _seconds ~/ 60;
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 0.5.sh),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 16.h),
            child: _mode == _Mode.typing ? _typing() : _voice(),
          ),
        ),
      ),
    );
  }

  Widget _voice() {
    final recording = _mode == _Mode.recording;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Gap(24.h),
        Text(
          !recording
              ? LocaleKeys.getHelpStarting.tr()
              : _paused
              ? LocaleKeys.getHelpPaused.tr()
              : LocaleKeys.getHelpListening.tr(),
          textAlign: TextAlign.center,
          style: AppTextStyle.lightBodyLargeMedium.copyWith(
            color: Colour.textPrimary,
          ),
        ),
        Gap(28.h),
        SizedBox(
          height: 64.h,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final level in _levels)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  width: 3.w,
                  height: 64.h * (recording && !_paused ? level : 0.08),
                  margin: EdgeInsets.symmetric(horizontal: 1.5.w),
                  decoration: BoxDecoration(
                    color: Colour.buttonPrimary.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
            ],
          ),
        ),
        Gap(8.h),
        Text(
          _time,
          style: AppTextStyle.lightBodyMediumMedium.copyWith(
            color: Colour.textSecondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        // Câu mẫu ngay dưới sóng âm để người dùng biết nói gì (web `VoiceExamples`).
        Gap(24.h),
        _VoiceExamples(active: recording),
        Gap(28.h),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: _sending
                      ? null
                      : () => Navigator.of(context).pop(),
                  tooltip: LocaleKeys.getHelpCancel.tr(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colour.muted,
                    fixedSize: Size.square(48.r),
                  ),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 24.r,
                    color: Colour.textPrimary,
                  ),
                ),
              ),
            ),
            Gap(24.w),
            // Giữa: tạm dừng / tiếp tục ghi âm.
            Material(
              color: Colour.buttonPrimary,
              shape: const CircleBorder(),
              elevation: 3,
              shadowColor: Colour.buttonPrimary.withValues(alpha: 0.4),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: recording && !_sending ? _togglePause : null,
                child: Tooltip(
                  message: _paused
                      ? LocaleKeys.getHelpContinue.tr()
                      : LocaleKeys.getHelpPause.tr(),
                  child: SizedBox.square(
                    dimension: 64.r,
                    child: Center(
                      child: !recording
                          ? const CupertinoActivityIndicator(
                              color: Colors.white,
                            )
                          : Icon(
                              _paused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              size: 32.r,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            Gap(24.w),
            // Phải: gửi bản ghi.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: recording && !_sending ? _sendVoice : null,
                  tooltip: LocaleKeys.getHelpSend.tr(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colour.buttonPrimary,
                    disabledBackgroundColor: Colour.muted,
                    fixedSize: Size.square(48.r),
                  ),
                  icon: _sending
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : AppIcon(
                          AppSvg.arrowUp,
                          size: 22.r,
                          color: recording ? Colors.white : Colour.textTertiary,
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _typing() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.getHelpMicUnavailable.tr(),
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            color: Colour.textSecondary,
          ),
        ),
        Gap(12.h),
        TextField(
          controller: _text,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            color: Colour.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: LocaleKeys.getHelpPlaceholder.tr(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        Gap(12.h),
        SizedBox(
          height: 48.h,
          child: FilledButton(
            onPressed: _text.text.trim().isEmpty ? null : _sendText,
            child: Text(LocaleKeys.getHelpSend.tr()),
          ),
        ),
      ],
    );
  }
}

/// Câu mẫu khi ghi âm (web `VoiceExamples`): hiện TỪNG câu một, mỗi câu ~3,5 giây rồi mờ
/// dần sang câu kế. Mọi câu xếp chồng trong cùng một ô → khung cao bằng câu dài nhất, đổi
/// câu không làm nhảy bố cục. Chỉ chạy khi đang ghi âm ([active]).
class _VoiceExamples extends StatefulWidget {
  final bool active;

  const _VoiceExamples({required this.active});

  @override
  State<_VoiceExamples> createState() => _VoiceExamplesState();
}

class _VoiceExamplesState extends State<_VoiceExamples> {
  static const _interval = Duration(milliseconds: 3500);

  Timer? _timer;
  int _index = 0;

  static List<String> get _examples => [
    LocaleKeys.getHelpExample1.tr(),
    LocaleKeys.getHelpExample2.tr(),
    LocaleKeys.getHelpExample3.tr(),
  ];

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _VoiceExamples oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (!widget.active) return;
    _timer = Timer.periodic(_interval, (_) {
      if (mounted) setState(() => _index = (_index + 1) % _examples.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final examples = _examples;
    final style = AppTextStyle.lightBodyMediumRegular.copyWith(
      height: 1.35,
      color: Colour.textSecondary,
    );
    return Column(
      children: [
        Text(
          LocaleKeys.getHelpExamplesLabel.tr(),
          textAlign: TextAlign.center,
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            color: Colour.textTertiary,
          ),
        ),
        Gap(8.h),
        Stack(
          alignment: Alignment.topCenter,
          children: [
            for (final (i, example) in examples.indexed)
              AnimatedSlide(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                offset: i == _index ? Offset.zero : const Offset(0, 0.08),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  opacity: i == _index ? 1 : 0,
                  child: ExcludeSemantics(
                    excluding: i != _index,
                    child: Text(
                      example,
                      textAlign: TextAlign.center,
                      style: style,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
