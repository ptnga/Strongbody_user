import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

/// Ô nhập dính đáy chat (cùng kiểu ô "Ask StrongBody" của Home): ô trống → micro, có
/// chữ → gửi, đang trả lời → nút Dừng ở cùng chỗ (web `RequestComposer` `onStop`).
/// Gửi xong ô tự xoá để gõ tiếp (`clearOnSend`).
class AssistantComposer extends StatefulWidget {
  final bool busy;
  final ValueChanged<String> onSend;
  final VoidCallback onVoice;
  final VoidCallback onStop;

  const AssistantComposer({
    super.key,
    required this.busy,
    required this.onSend,
    required this.onVoice,
    required this.onStop,
  });

  @override
  State<AssistantComposer> createState() => _AssistantComposerState();
}

class _AssistantComposerState extends State<AssistantComposer> {
  static const _maxText = 2000;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.busy) return;
    widget.onSend(text);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final (IconData? icon, String? svg, VoidCallback onTap) = widget.busy
        ? (Icons.stop_rounded, null, widget.onStop)
        : _hasText
        ? (null, AppSvg.arrowUp, _send)
        : (null, AppSvg.microphone, widget.onVoice);
    final tooltip = LocaleKeys.assistantStop.tr();
    final button = Material(
      color: Colour.buttonPrimary,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colour.buttonPrimary.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 44.r,
          child: Center(
            child: svg != null
                ? AppIcon(svg, size: 24.r, color: Colors.white)
                : Icon(icon, size: 24.r, color: Colors.white),
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
      child: Container(
        padding: EdgeInsets.fromLTRB(18.w, 6.h, 6.w, 6.h),
        decoration: BoxDecoration(
          color: Colour.muted,
          borderRadius: BorderRadius.circular(28.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 2.h),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: _maxText,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _send(),
                  style: AppTextStyle.lightBodyLargeRegular.copyWith(
                    color: Colour.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: LocaleKeys.homeAskPlaceholder.tr(),
                    hintStyle: AppTextStyle.lightBodyLargeRegular.copyWith(
                      color: Colour.textTertiary,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
            ),
            Gap(6.w),
            if (widget.busy)
              Tooltip(message: tooltip, child: button)
            else
              button,
          ],
        ),
      ),
    );
  }
}
