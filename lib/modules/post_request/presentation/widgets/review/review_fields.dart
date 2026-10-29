import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../../domain/entities/request_form_values.dart';
import '../../../domain/entities/request_options.dart';
import '../../request_formatters.dart';

/// Nhãn field ("What do you need? *").
class ReviewLabel extends StatelessWidget {
  final String text;
  final bool required;
  final Widget? trailing;

  const ReviewLabel(
    this.text, {
    super.key,
    this.required = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Text(
            required ? '$text *' : text,
            style: AppTextStyle.lightBodyMediumBold.copyWith(
              color: theme.textPrimary(context),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Viền / nền chung của ô nhập trên màn Review.
InputDecoration reviewInputDecoration(
  BuildContext context, {
  String? hint,
  bool error = false,
}) {
  final theme = Theme.of(context);
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12.r),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyle.lightBodyMediumRegular.copyWith(
      color: theme.textTertiary(context),
    ),
    isDense: true,
    filled: true,
    fillColor: theme.surface(context),
    counterText: '',
    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
    border: border(theme.border(context)),
    enabledBorder: border(error ? Colour.error : theme.border(context)),
    focusedBorder: border(error ? Colour.error : theme.textPrimary(context)),
  );
}

/// Lỗi đỏ dưới ô (kiểm tra ngay tại form như prototype, không toast).
class ReviewFieldError extends StatelessWidget {
  final String text;

  const ReviewFieldError(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 6.h),
    child: Text(
      text,
      style: AppTextStyle.lightBodySmallRegular.copyWith(color: Colour.error),
    ),
  );
}

/// Dòng voice note: micro · "Your voice note · 0:09" · thùng rác.
class ReviewVoiceNoteRow extends StatelessWidget {
  final Duration? duration;
  final VoidCallback onRemove;

  /// Đã bấm xoá → nút "Undo remove" thay cho thùng rác.
  final bool removed;
  final VoidCallback onUndo;

  const ReviewVoiceNoteRow({
    super.key,
    required this.duration,
    required this.onRemove,
    required this.onUndo,
    this.removed = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 4.w, 12.h),
      decoration: BoxDecoration(
        color: theme.surface(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: theme.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
              color: theme.muted(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mic_none_rounded,
              size: 20.r,
              color: theme.textPrimary(context),
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.reviewVoiceNote.tr(
                    args: [
                      RequestFormatters.duration(duration ?? Duration.zero),
                    ],
                  ),
                  style: AppTextStyle.lightBodyMediumBold.copyWith(
                    color: theme.textPrimary(context),
                  ),
                ),
                Text(
                  LocaleKeys.reviewVoiceNoteHint.tr(),
                  style: AppTextStyle.lightBodySmallRegular.copyWith(
                    color: theme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          if (removed)
            // Co lại được khi chữ dài (ngôn ngữ khác) thay vì tràn hàng.
            Flexible(
              child: Padding(
                padding: EdgeInsets.only(left: 8.w, right: 8.w),
                child: OutlinedButton(
                  onPressed: onUndo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.textPrimary(context),
                    side: BorderSide(color: theme.border(context)),
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    minimumSize: Size(0, 36.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    textStyle: AppTextStyle.lightBodySmallSemiBold,
                  ),
                  child: Text(
                    LocaleKeys.reviewUndoRemoveVoice.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: LocaleKeys.reviewRemoveVoice.tr(),
              onPressed: onRemove,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 22.r,
                color: theme.textSecondary(context),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chip "Online / At my home / At a clinic" — chọn nhiều, chip đã chọn có dấu ✓ và viền đậm.
class ReviewDeliveryChips extends StatelessWidget {
  final List<RequestDeliveryType> value;
  final ValueChanged<List<RequestDeliveryType>> onChanged;

  const ReviewDeliveryChips({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final type in RequestDeliveryType.values)
          Builder(
            builder: (context) {
              final selected = value.contains(type);
              return Material(
                color: selected ? theme.muted(context) : theme.surface(context),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: selected
                        ? theme.secondary(context)
                        : theme.border(context),
                    width: selected ? 1.4 : 1,
                  ),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onChanged(
                    selected
                        ? (List.of(value)..remove(type))
                        : [...value, type],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          Icon(
                            Icons.check_rounded,
                            size: 16.r,
                            color: theme.textPrimary(context),
                          ),
                          Gap(4.w),
                        ],
                        Text(
                          RequestFormatters.delivery(type),
                          style: AppTextStyle.lightBodyMediumMedium.copyWith(
                            color: theme.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Ô "When" — chạm để chọn khoảng ngày (vd Sat 24 – Sun 25 Oct).
class ReviewWhenField extends StatelessWidget {
  final RequestFormValues values;
  final ValueChanged<RequestFormValues> onChanged;

  const ReviewWhenField({
    super.key,
    required this.values,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = values.deadline;
    final initial = start == null || start.isBefore(today)
        ? null
        : DateTimeRange(start: start, end: values.endDate ?? start);
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: initial,
    );
    if (range == null) return;
    onChanged(values.withDateRange(range.start, range.end));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = RequestFormatters.when(values, context.locale.languageCode);
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        height: 50.h,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          color: theme.surface(context),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: theme.border(context)),
        ),
        child: Text(
          text ?? LocaleKeys.reviewWhenPlaceholder.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            color: text == null
                ? theme.textTertiary(context)
                : theme.textPrimary(context),
          ),
        ),
      ),
    );
  }
}

/// Nhãn "Budget (USD) ▾" — chạm để đổi tiền tệ.
class ReviewBudgetLabel extends StatelessWidget {
  final String currency;
  final ValueChanged<String> onChanged;

  const ReviewBudgetLabel({
    super.key,
    required this.currency,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      initialValue: currency,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final c in requestCurrencies)
          PopupMenuItem(value: c, child: Text(c)),
      ],
      child: Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              LocaleKeys.reviewBudgetLabel.tr(args: [currency]),
              style: AppTextStyle.lightBodyMediumBold.copyWith(
                color: theme.textPrimary(context),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 22.r,
              color: theme.textSecondary(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ radio "Who can see it?".
class ReviewVisibilityOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? footer;

  const ReviewVisibilityOption({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.muted(context) : theme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: selected ? theme.secondary(context) : theme.border(context),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: _RadioDot(selected: selected),
              ),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                        color: theme.textPrimary(context),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyle.lightBodySmallRegular.copyWith(
                        color: theme.textSecondary(context),
                      ),
                    ),
                    ?footer,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;

  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.secondary(context)
        : theme.textTertiary(context);
    return Container(
      width: 20.r,
      height: 20.r,
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.6),
      ),
      child: selected
          ? DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            )
          : null,
    );
  }
}

/// Hộp gợi ý xanh của AI ("Clear request. Adding how long…").
class ReviewTipBox extends StatelessWidget {
  final String text;

  const ReviewTipBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colour.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_outlined, size: 18.r, color: Colour.success),
          Gap(10.w),
          Expanded(
            child: Text(
              text,
              style: AppTextStyle.lightBodySmallRegular.copyWith(
                height: 1.4,
                color: theme.textPrimary(context).withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
