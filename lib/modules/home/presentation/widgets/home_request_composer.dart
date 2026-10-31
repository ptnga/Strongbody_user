import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/utils/app_logger.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/voice_request_page_args.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

typedef RequestSendCallback =
    void Function(String text, List<String> attachmentPaths);

/// Ô "Ask StrongBody" (mirror `RequestComposer.tsx` của web):
/// - Ô trống → nút micro mở màn nói yêu cầu (transcript trực tiếp); có chữ → nút gửi.
/// - Nút "+": đính kèm ảnh / file, đi kèm sang form Post Request.
class HomeRequestComposer extends StatefulWidget {
  final RequestSendCallback onSend;

  /// Chữ trong ô đổi (gõ, điền gợi ý, xoá sau khi gửi) → gợi ý theo chữ đó.
  final ValueChanged<String>? onTextChanged;

  /// Ô được / mất focus (focus mà chưa gõ → "Recent searches").
  final ValueChanged<bool>? onFocusChanged;

  /// Chữ gợi ý trong ô (mặc định "Ask StrongBody" của Home).
  final String? hintText;

  /// Nơi mở màn nói (analytics `VoiceRequestPageArgs.source`).
  final String source;

  /// Nền ô nhập (mặc định xám nhạt); đặt trên khối xám thì dùng trắng.
  final Color? background;

  const HomeRequestComposer({
    super.key,
    required this.onSend,
    this.onTextChanged,
    this.onFocusChanged,
    this.hintText,
    this.source = 'home',
    this.background,
  });

  @override
  State<HomeRequestComposer> createState() => HomeRequestComposerState();
}

class HomeRequestComposerState extends State<HomeRequestComposer> {
  static const _maxText = 2000;

  final _textController = TextEditingController();
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => widget.onFocusChanged?.call(_focusNode.hasFocus),
    );
    _textController.addListener(() {
      final text = _textController.text;
      if (text == _lastText) return;
      _lastText = text;
      widget.onTextChanged?.call(text);
    });
  }

  final _focusNode = FocusNode();
  List<String> _attachments = [];

  bool get _hasText => _textController.text.trim().isNotEmpty;

  /// Điền câu gợi ý vào ô nhập (thẻ gợi ý ở Home).
  void setText(String text) {
    _textController.text = text;
    _textController.selection = TextSelection.collapsed(offset: text.length);
    _focusNode.requestFocus();
    setState(() {});
  }

  /// Gửi một gợi ý: lấy file đính kèm hiện có và xoá ô nhập (như khi bấm gửi).
  List<String> takeAttachments() {
    final attachments = _attachments;
    _focusNode.unfocus();
    _textController.clear();
    setState(() => _attachments = []);
    return attachments;
  }

  /// "Type instead" từ màn nói: mở bàn phím, gắn lại file đính kèm.
  void focusForTyping(List<String> attachments) {
    setState(() => _attachments = {..._attachments, ...attachments}.toList());
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      final picked = result?.files.map((f) => f.path).whereType<String>() ?? [];
      if (picked.isEmpty) return;
      setState(() => _attachments = {..._attachments, ...picked}.toList());
    } catch (e) {
      AppLogger.e('Pick attachments failed', e);
    }
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _focusNode.unfocus();
    widget.onSend(text, _attachments);
    _textController.clear();
    setState(() => _attachments = []);
  }

  Future<void> _openVoice() async {
    _focusNode.unfocus();
    final attachments = _attachments;
    setState(() => _attachments = []);
    // Huỷ ghi âm (X) → màn voice trả lại file đính kèm; gửi xong thì null.
    final returned = await context.push<List<String>>(
      RouteName.voiceRequest,
      extra: VoiceRequestPageArgs(
        attachmentPaths: attachments,
        source: widget.source,
      ),
    );
    if (!mounted || returned == null || returned.isEmpty) return;
    setState(() => _attachments = returned);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 12.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachments.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: InputChip(
                avatar: Icon(Icons.attach_file, size: 16.r),
                label: Text(
                  LocaleKeys.homeAttachmentsCount.tr(
                    args: ['${_attachments.length}'],
                  ),
                ),
                onDeleted: () => setState(() => _attachments = []),
                backgroundColor: theme.muted(context),
                side: BorderSide.none,
                shape: const StadiumBorder(),
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(4.w, 6.h, 6.w, 6.h),
            decoration: BoxDecoration(
              color: widget.background ?? theme.muted(context),
              borderRadius: BorderRadius.circular(28.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _pickAttachments,
                  icon: Icon(
                    Icons.add,
                    size: 26.r,
                    color: theme.textPrimary(context),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 2.h),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 6,
                      maxLength: _maxText,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _sendText(),
                      style: AppTextStyle.lightBodyLargeRegular.copyWith(
                        color: theme.textPrimary(context),
                      ),
                      decoration: InputDecoration(
                        hintText:
                            widget.hintText ??
                            LocaleKeys.homeAskPlaceholder.tr(),
                        hintStyle: AppTextStyle.lightBodyLargeRegular.copyWith(
                          color: theme.textTertiary(context),
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
                _MicSendButton(
                  hasText: _hasText,
                  onTap: _hasText ? _sendText : _openVoice,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút tròn đỏ: micro (ô trống) ↔ gửi (có chữ).
class _MicSendButton extends StatelessWidget {
  final bool hasText;
  final VoidCallback onTap;

  const _MicSendButton({required this.hasText, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.primary(context),
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: theme.primary(context).withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 44.r,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween(begin: 0.75, end: 1.0).animate(animation),
              child: child,
            ),
            child: Icon(
              hasText ? Icons.arrow_upward_rounded : Icons.mic_none_rounded,
              key: ValueKey(hasText),
              size: 24.r,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
