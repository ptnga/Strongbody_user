import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';

import '../../../domain/entities/request_category.dart';
import '../../../domain/entities/request_form_values.dart';
import '../../bloc/post_request_flow/post_request_flow_bloc.dart';
import '../../request_formatters.dart';
import '../common/flow_header.dart';
import '../review/review_fields.dart';

enum _Field { what, category, where, when, budget }

/// "✦ I understood" — các ý AI rút ra từ lời người dùng. Chạm dòng để sửa ngay tại chỗ
/// (Save / Cancel) như prototype; lưu vào cùng `PostRequestFlowBloc` (Review dùng lại).
class UnderstoodCard extends StatefulWidget {
  const UnderstoodCard({super.key});

  @override
  State<UnderstoodCard> createState() => _UnderstoodCardState();
}

class _UnderstoodCardState extends State<UnderstoodCard> {
  _Field? _editing;

  /// Bản nháp khi đang sửa (description / budget / delivery / when / category).
  RequestFormValues? _draft;
  int? _draftCategory;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _edit(_Field field, PostRequestFlowState state) {
    setState(() {
      _editing = field;
      _draft = state.values;
      _draftCategory = state.assistant?.categoryIds.firstOrNull;
      _text.text = switch (field) {
        _Field.what => state.values.description,
        _Field.budget => state.values.budget,
        _ => '',
      };
    });
  }

  void _cancel() => setState(() => _editing = null);

  bool get _canSave => switch (_editing) {
    _Field.what => _text.text.trim().isNotEmpty,
    _Field.budget => RequestFormValues.isValidBudgetText(_text.text),
    _Field.where => (_draft?.deliveryTypes.isNotEmpty ?? false),
    _Field.category => _draftCategory != null,
    _ => true,
  };

  void _save() {
    final bloc = context.read<PostRequestFlowBloc>();
    final draft = _draft;
    if (draft == null || !_canSave) return;
    switch (_editing) {
      case _Field.category:
        bloc.add(PostRequestFlowCategoryChanged(_draftCategory!));
      case _Field.what:
        final text = _text.text.trim();
        bloc.add(
          PostRequestFlowValuesChanged(
            draft.copyWith(
              description: text.length > RequestFormValues.maxDescription
                  ? text.substring(0, RequestFormValues.maxDescription)
                  : text,
            ),
          ),
        );
      case _Field.budget:
        bloc.add(
          PostRequestFlowValuesChanged(
            draft.copyWith(budget: _text.text.trim()),
          ),
        );
      case _Field.where || _Field.when:
        bloc.add(PostRequestFlowValuesChanged(draft));
      case null:
        break;
    }
    setState(() => _editing = null);
  }

  Widget _editor(_Field field) {
    final theme = Theme.of(context);
    final draft = _draft!;
    return switch (field) {
      _Field.what || _Field.budget => TextField(
        controller: _text,
        autofocus: true,
        minLines: field == _Field.what ? 2 : 1,
        maxLines: field == _Field.what ? 5 : 1,
        keyboardType: field == _Field.budget
            ? TextInputType.text
            : TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: 15.sp, color: theme.textPrimary(context)),
        decoration: reviewInputDecoration(
          context,
          hint: field == _Field.budget
              ? LocaleKeys.reviewBudgetPlaceholder.tr()
              : LocaleKeys.reviewWhatPlaceholder.tr(),
          error:
              field == _Field.budget &&
              !RequestFormValues.isValidBudgetText(_text.text),
        ),
      ),
      _Field.category => Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          for (final category in RequestCategory.values)
            ChoiceChip(
              label: Text(RequestFormatters.category(category)),
              selected: _draftCategory == category.id,
              onSelected: (_) => setState(() => _draftCategory = category.id),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 13.sp,
                color: theme.textPrimary(context),
              ),
              backgroundColor: theme.surface(context),
              selectedColor: theme.muted(context),
              side: BorderSide(
                color: _draftCategory == category.id
                    ? theme.secondary(context)
                    : theme.border(context),
              ),
            ),
        ],
      ),
      _Field.where => ReviewDeliveryChips(
        value: draft.deliveryTypes,
        onChanged: (types) =>
            setState(() => _draft = draft.copyWith(deliveryTypes: types)),
      ),
      _Field.when => ReviewWhenField(
        values: draft,
        onChanged: (values) => setState(() => _draft = values),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.languageCode;
    return BlocBuilder<PostRequestFlowBloc, PostRequestFlowState>(
      buildWhen: (previous, current) =>
          previous.isAnalyzing != current.isAnalyzing ||
          previous.values != current.values ||
          previous.assistant != current.assistant,
      builder: (context, state) {
        final values = state.values;
        final notSpecified = LocaleKeys.heardNotSpecified.tr();
        final rows = [
          (
            _Field.what,
            Icons.favorite_border_rounded,
            LocaleKeys.heardRowWhat.tr(),
            RequestFormatters.headline(values.description),
            2,
          ),
          (
            _Field.category,
            Icons.sell_outlined,
            LocaleKeys.heardRowCategory.tr(),
            RequestFormatters.categories(
                  state.assistant?.categoryIds ?? const [],
                ) ??
                notSpecified,
            1,
          ),
          (
            _Field.where,
            Icons.location_on_outlined,
            LocaleKeys.heardRowWhere.tr(),
            RequestFormatters.where(values) ?? notSpecified,
            2,
          ),
          (
            _Field.when,
            Icons.event_outlined,
            LocaleKeys.heardRowWhen.tr(),
            RequestFormatters.when(values, locale) ??
                LocaleKeys.heardFlexible.tr(),
            1,
          ),
          (
            _Field.budget,
            Icons.payments_outlined,
            LocaleKeys.heardRowBudget.tr(),
            RequestFormatters.budget(values) ?? notSpecified,
            1,
          ),
        ];

        return FlowCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 12.h),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 18.r,
                      color: theme.textPrimary(context),
                    ),
                    Gap(8.w),
                    Text(
                      LocaleKeys.heardUnderstood.tr(),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary(context),
                      ),
                    ),
                    Gap(12.w),
                    // Trạng thái bên phải co lại (ellipsis) thay vì bóp tiêu đề.
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (state.isAnalyzing) ...[
                            const CupertinoActivityIndicator(radius: 7),
                            Gap(6.w),
                          ],
                          Flexible(
                            child: Text(
                              state.isAnalyzing
                                  ? LocaleKeys.heardAnalyzing.tr()
                                  : LocaleKeys.heardTapToFix.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: theme.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              for (final (field, icon, label, value, maxLines) in rows)
                if (_editing == field)
                  _InlineEditor(
                    label: label,
                    canSave: _canSave,
                    onSave: _save,
                    onCancel: _cancel,
                    child: _editor(field),
                  )
                else
                  _UnderstoodRow(
                    icon: icon,
                    label: label,
                    value: value,
                    maxLines: maxLines,
                    loading: state.isAnalyzing,
                    onTap: state.isAnalyzing ? null : () => _edit(field, state),
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// Ô sửa một dòng: nhãn · nội dung · Save / Cancel.
class _InlineEditor extends StatelessWidget {
  final String label;
  final Widget child;
  final bool canSave;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _InlineEditor({
    required this.label,
    required this.child,
    required this.canSave,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.r),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
      decoration: BoxDecoration(
        color: theme.muted(context).withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: theme.border(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: theme.textSecondary(context),
            ),
          ),
          Gap(8.h),
          child,
          Gap(10.h),
          Row(
            children: [
              FilledButton(
                onPressed: canSave ? onSave : null,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.secondary(context),
                  shape: shape,
                ),
                child: Text(LocaleKeys.accountSave.tr()),
              ),
              Gap(8.w),
              OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textPrimary(context),
                  side: BorderSide(color: theme.border(context)),
                  shape: shape,
                ),
                child: Text(LocaleKeys.chatCancel.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnderstoodRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;
  final bool loading;
  final VoidCallback? onTap;

  const _UnderstoodRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.maxLines,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.border(context))),
        ),
        child: Row(
          children: [
            FlowIconBox(icon: icon, size: 36.r),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: theme.textSecondary(context),
                    ),
                  ),
                  Gap(2.h),
                  if (loading)
                    _Shimmer(width: 170.w, height: 14.h)
                  else
                    Text(
                      value,
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary(context),
                      ),
                    ),
                ],
              ),
            ),
            Gap(8.w),
            Icon(
              Icons.edit_outlined,
              size: 18.r,
              color: theme.textTertiary(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khối xám nhấp nháy thay cho giá trị khi AI đang phân tích.
class _Shimmer extends StatefulWidget {
  final double width;
  final double height;

  const _Shimmer({required this.width, required this.height});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.45,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        margin: EdgeInsets.only(top: 3.h),
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Theme.of(context).border(context),
          borderRadius: BorderRadius.circular(6.r),
        ),
      ),
    );
  }
}
