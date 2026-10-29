import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/request_formatters.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

/// Ô "Message Minh..." + nút đỏ: mic (trống) / gửi (có chữ) / gửi voice (đang ghi).
class ChatComposer extends StatefulWidget {
  final String hint;
  final String footer;
  final bool enabled;
  final bool recording;
  final Duration recordElapsed;
  final ValueChanged<String> onSend;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordSend;
  final VoidCallback onRecordCancel;

  const ChatComposer({
    super.key,
    required this.hint,
    required this.footer,
    required this.enabled,
    required this.recording,
    required this.recordElapsed,
    required this.onSend,
    required this.onRecordStart,
    required this.onRecordSend,
    required this.onRecordCancel,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String icon, VoidCallback action) = widget.recording
        ? (AppSvg.arrowUp, widget.onRecordSend)
        : _hasText
        ? (AppSvg.arrowUp, _send)
        : (AppSvg.microphone, widget.onRecordStart);

    return Container(
      color: theme.surface(context),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 6.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(minHeight: 48.h),
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: theme.muted(context),
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      child: widget.recording
                          ? Row(
                              children: [
                                Container(
                                  width: 8.r,
                                  height: 8.r,
                                  decoration: BoxDecoration(
                                    color: theme.primary(context),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Gap(8.w),
                                Expanded(
                                  child: Text(
                                    LocaleKeys.chatRecording.tr(
                                      args: [
                                        RequestFormatters.duration(
                                          widget.recordElapsed,
                                        ),
                                      ],
                                    ),
                                    style: AppTextStyle.lightBodyMediumRegular
                                        .copyWith(
                                          color: theme.textPrimary(context),
                                        ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: widget.onRecordCancel,
                                  child: Text(
                                    LocaleKeys.chatCancel.tr(),
                                    style: AppTextStyle.lightBodyMediumSemiBold
                                        .copyWith(
                                          color: theme.textSecondary(context),
                                        ),
                                  ),
                                ),
                              ],
                            )
                          : TextField(
                              controller: _controller,
                              enabled: widget.enabled,
                              minLines: 1,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              style: AppTextStyle.lightBodyMediumRegular
                                  .copyWith(color: theme.textPrimary(context)),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: widget.hint,
                                hintStyle: AppTextStyle.lightBodyMediumRegular
                                    .copyWith(
                                      color: theme.textSecondary(context),
                                    ),
                              ),
                            ),
                    ),
                  ),
                  Gap(10.w),
                  Material(
                    color: theme.primary(context),
                    shape: const CircleBorder(),
                    elevation: 2,
                    shadowColor: theme.primary(context).withValues(alpha: 0.4),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: widget.enabled ? action : null,
                      child: SizedBox.square(
                        dimension: 54.r,
                        child: AppIcon(icon, size: 22.r, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              Gap(8.h),
              Text(
                widget.recording
                    ? LocaleKeys.chatRecordingHint.tr()
                    : widget.footer,
                textAlign: TextAlign.center,
                style: AppTextStyle.lightBodySmallRegular.copyWith(
                  color: theme.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
