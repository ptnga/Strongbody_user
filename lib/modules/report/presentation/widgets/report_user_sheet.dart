import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';

import '../../domain/entities/report_reason.dart';
import '../bloc/report/report_bloc.dart';

/// Sheet báo cáo một người dùng: chọn lý do + ghi chú (không bắt buộc) → gửi.
class ReportUserSheet extends StatelessWidget {
  final int reportedUserId;
  final String userName;
  final String reportContext;

  const ReportUserSheet._({
    required this.reportedUserId,
    required this.userName,
    required this.reportContext,
  });

  static Future<void> show(
    BuildContext context, {
    required int reportedUserId,
    required String userName,
    String reportContext = 'chat',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).surface(context),
      builder: (_) => BlocProvider(
        create: (_) => getIt<ReportBloc>(),
        child: ReportUserSheet._(
          reportedUserId: reportedUserId,
          userName: userName,
          reportContext: reportContext,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReportBloc, ReportState>(
      listenWhen: (a, b) => a.status != b.status,
      listener: (context, state) {
        if (state.status == ReportStatus.success) {
          Navigator.of(context).pop();
          ToastUtil.showSuccess(LocaleKeys.reportSuccess.tr());
        } else if (state.status == ReportStatus.failure) {
          ToastUtil.showError(state.error ?? LocaleKeys.reportFailed.tr());
        }
      },
      child: _ReportForm(
        reportedUserId: reportedUserId,
        userName: userName,
        reportContext: reportContext,
      ),
    );
  }
}

class _ReportForm extends StatefulWidget {
  final int reportedUserId;
  final String userName;
  final String reportContext;

  const _ReportForm({
    required this.reportedUserId,
    required this.userName,
    required this.reportContext,
  });

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  ReportReason? _selected;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              LocaleKeys.reportTitle.tr(args: [widget.userName]),
              style: AppTextStyle.lightHeadingSmall.copyWith(
                color: theme.textPrimary(context),
              ),
            ),
            Gap(4.h),
            Text(
              LocaleKeys.reportSubtitle.tr(),
              style: AppTextStyle.lightBodySmallRegular.copyWith(
                color: theme.textSecondary(context),
              ),
            ),
            Gap(12.h),
            for (final reason in ReportReason.values)
              _ReasonRow(
                label: reason.labelKey.tr(),
                selected: _selected == reason,
                onTap: () => setState(() => _selected = reason),
              ),
            Gap(12.h),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyle.lightBodyMediumRegular.copyWith(
                color: theme.textPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: LocaleKeys.reportNoteHint.tr(),
                hintStyle: AppTextStyle.lightBodyMediumRegular.copyWith(
                  color: theme.textSecondary(context),
                ),
                filled: true,
                fillColor: theme.muted(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            Gap(20.h),
            BlocBuilder<ReportBloc, ReportState>(
              builder: (context, state) {
                final enabled = _selected != null && !state.isSubmitting;
                return SizedBox(
                  height: 50.h,
                  child: FilledButton(
                    onPressed: enabled
                        ? () => context.read<ReportBloc>().add(
                            ReportSubmitted(
                              reportedUserId: widget.reportedUserId,
                              reason: _selected!,
                              note: _note.text,
                              context: widget.reportContext,
                            ),
                          )
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.primary(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(LocaleKeys.reportSubmit.tr()),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyle.lightBodyMediumRegular.copyWith(
                  color: theme.textPrimary(context),
                ),
              ),
            ),
            if (selected)
              AppIcon(
                AppSvg.check,
                size: 22.r,
                color: theme.primary(context),
              )
            else
              Icon(
                Icons.radio_button_unchecked,
                size: 22.r,
                color: theme.border(context),
              ),
          ],
        ),
      ),
    );
  }
}
