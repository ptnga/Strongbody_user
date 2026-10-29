import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';

import '../../bloc/voice_request/voice_request_bloc.dart';

/// Transcript cỡ lớn với con trỏ đỏ nhấp nháy ở cuối. Khi không nghe,
/// chạm vào để sửa tay (sửa xong vẫn có thể bấm ▶ nói tiếp).
class VoiceTranscript extends StatefulWidget {
  const VoiceTranscript({super.key});

  @override
  State<VoiceTranscript> createState() => _VoiceTranscriptState();
}

class _VoiceTranscriptState extends State<VoiceTranscript> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) setState(() => _editing = false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  TextStyle _style(BuildContext context) => TextStyle(
    fontSize: 25.sp,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: Theme.of(context).textPrimary(context),
  );

  void _startEditing(String transcript) {
    _textController.text = transcript;
    _textController.selection = TextSelection.collapsed(
      offset: transcript.length,
    );
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<VoiceRequestBloc, VoiceRequestState>(
      listenWhen: (previous, current) =>
          previous.transcript != current.transcript ||
          previous.status != current.status,
      listener: (context, state) {
        // Bắt đầu nghe lại → thoát chế độ sửa.
        if (state.isListening && _editing) {
          _focusNode.unfocus();
          setState(() => _editing = false);
        }
        if (state.isListening) _scrollToEnd();
      },
      buildWhen: (previous, current) =>
          previous.transcript != current.transcript ||
          previous.status != current.status,
      builder: (context, state) {
        if (_editing) {
          return SingleChildScrollView(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              maxLines: null,
              style: _style(context),
              cursorColor: theme.primary(context),
              cursorWidth: 2.5,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
              onChanged: (text) => context.read<VoiceRequestBloc>().add(
                VoiceRequestTextEdited(text),
              ),
            ),
          );
        }

        final transcript = state.transcript;
        final canEdit =
            !state.isListening &&
            state.status != VoiceRequestStatus.initializing;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canEdit ? () => _startEditing(transcript) : null,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Text.rich(
              TextSpan(
                style: _style(context),
                children: [
                  if (transcript.isEmpty)
                    TextSpan(
                      text: LocaleKeys.voiceRequestPlaceholder.tr(),
                      style: TextStyle(color: theme.textTertiary(context)),
                    )
                  else
                    TextSpan(text: '$transcript '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: _BlinkingCursor(
                      color: theme.primary(context),
                      height: 28.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  final Color color;
  final double height;

  const _BlinkingCursor({required this.color, required this.height});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Opacity(opacity: _controller.value < 0.55 ? 1 : 0, child: child),
      child: Container(width: 2.5, height: widget.height, color: widget.color),
    );
  }
}
