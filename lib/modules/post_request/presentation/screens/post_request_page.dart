import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';
import 'package:strongbody_buyer/modules/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:strongbody_buyer/modules/auth/presentation/widgets/auth_sheet.dart';

import '../../domain/entities/request_form_values.dart';
import '../../domain/entities/request_options.dart';
import '../bloc/post_request_flow/post_request_flow_bloc.dart';
import '../post_request_flow_args.dart';
import '../widgets/common/flow_header.dart';
import '../widgets/request_form/request_form_fields.dart';
import '../widgets/review/review_fields.dart';

/// "Post a request" (web `/request-assistant` = `RequestAssistantClient` + `RequestForm`):
/// form hiện ngay (đang khoá) kèm thanh tiến trình trong lúc AI xử lý; AI xong thì form
/// mở với nội dung đã điền sẵn để kiểm tra, sửa rồi đăng → trang "Providers for your
/// request". Chưa đăng nhập → popup Sign up, xong thì tự đăng tiếp.
class PostRequestPage extends StatefulWidget {
  final PostRequestFlowArgs args;

  const PostRequestPage({super.key, required this.args});

  @override
  State<PostRequestPage> createState() => _PostRequestPageState();
}

class _PostRequestPageState extends State<PostRequestPage> {
  late final PostRequestFlowBloc _bloc = context.read<PostRequestFlowBloc>();
  final _description = TextEditingController();
  final _budget = TextEditingController();
  final _descriptionFocus = FocusNode();
  final _budgetFocus = FocusNode();

  /// Lỗi mô tả chỉ hiện sau khi bấm gửi; lỗi budget sau khi rời ô (web).
  bool _descriptionSubmitted = false;
  bool _budgetTouched = false;
  List<String> _oversized = const [];

  bool get _isSend => widget.args.isSend;

  @override
  void initState() {
    super.initState();
    _budgetFocus.addListener(() {
      if (!_budgetFocus.hasFocus) setState(() => _budgetTouched = true);
    });
  }

  @override
  void dispose() {
    _description.dispose();
    _budget.dispose();
    _descriptionFocus.dispose();
    _budgetFocus.dispose();
    super.dispose();
  }

  void _update(RequestFormValues values) =>
      _bloc.add(PostRequestFlowValuesChanged(values));

  /// Nạp nội dung mới (câu đã gõ lúc bắt đầu, kết quả AI lúc xong) vào ô chữ.
  void _load(RequestFormValues values) {
    _description.text = values.description;
    _budget.text = values.budget;
  }

  void _submit(PostRequestFlowState state) {
    FocusScope.of(context).unfocus();
    final descriptionBad =
        RequestFormValues.descriptionError(_description.text) != null;
    final budgetBad = !RequestFormValues.isValidBudgetText(_budget.text);
    setState(() {
      _descriptionSubmitted = true;
      if (budgetBad) _budgetTouched = true;
    });
    if (descriptionBad) {
      _descriptionFocus.requestFocus();
      return;
    }
    if (budgetBad) {
      _budgetFocus.requestFocus();
      return;
    }
    _bloc.add(const PostRequestFlowSubmitted());
  }

  Future<void> _pickFiles(RequestFormValues values) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || !mounted) return;
    final ok = <String>[];
    final oversized = <String>[];
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      if (await File(path).length() > RequestFormValues.maxAttachmentBytes) {
        oversized.add(file.name);
      } else {
        ok.add(path);
      }
    }
    setState(() => _oversized = oversized);
    if (ok.isNotEmpty) {
      _update(
        values.copyWith(attachmentPaths: [...values.attachmentPaths, ...ok]),
      );
    }
  }

  Future<void> _onStateChanged(
    BuildContext context,
    PostRequestFlowState state,
  ) async {
    final notice = state.notice;
    if (notice != null) {
      _bloc.add(const PostRequestFlowNoticeConsumed());
      final message = switch (notice) {
        PostRequestNotice.transcribeFailed =>
          LocaleKeys.postRequestErrorTranscribe.tr(),
        PostRequestNotice.rateLimited =>
          LocaleKeys.postRequestErrorRateLimited.tr(),
        PostRequestNotice.emptyVoice =>
          LocaleKeys.postRequestErrorEmptyVoice.tr(),
        PostRequestNotice.draftFailed => LocaleKeys.postRequestErrorDraft.tr(),
        PostRequestNotice.requestFailed =>
          state.noticeMessage?.isNotEmpty == true
              ? state.noticeMessage!
              : LocaleKeys.postRequestFailed.tr(),
        // Lỗi mô tả hiện ngay dưới ô.
        _ => null,
      };
      if (message != null) ToastUtil.showError(message);
    }
    switch (state.submitStatus) {
      case PostRequestSubmitStatus.success:
        final id = state.created?.id;
        if (_isSend) {
          ToastUtil.showSuccess(LocaleKeys.postRequestSent.tr());
          context.pop();
        } else if (id != null) {
          context.pushReplacement(RouteName.requestMatchesPath(id));
        } else {
          // Thiếu id (response đổi shape) → báo như popup cũ của web rồi về My requests.
          ToastUtil.showSuccess(
            state.created?.isLive == true
                ? LocaleKeys.postRequestLive.tr()
                : LocaleKeys.postRequestInReview.tr(),
          );
          context.go(RouteName.myRequests);
        }
      case PostRequestSubmitStatus.pendingAuth:
        final signedIn = await showAuthSheet(
          context,
          source: 'post_request',
          initial: AuthScreen.signup,
          subtitle: LocaleKeys.authRequestSubtitle.tr(),
        );
        if (signedIn) _bloc.add(const PostRequestFlowSubmitted());
      case PostRequestSubmitStatus.idle:
      case PostRequestSubmitStatus.submitting:
      case PostRequestSubmitStatus.failure:
        break;
    }
  }

  String _title(PostRequestFlowState state) {
    if (_isSend) return LocaleKeys.postRequestSendTitle.tr();
    if (state.isWorking) return LocaleKeys.postRequestTitleWorking.tr();
    if (state.outcome == PostRequestDraftOutcome.filled) {
      return LocaleKeys.postRequestTitleReady.tr();
    }
    return LocaleKeys.postRequestTitle.tr();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PostRequestFlowBloc, PostRequestFlowState>(
          listenWhen: (previous, current) =>
              previous.values.description != current.values.description &&
                  current.isWorking ||
              previous.isWorking && !current.isWorking,
          listener: (context, state) => _load(state.values),
        ),
        BlocListener<PostRequestFlowBloc, PostRequestFlowState>(
          listenWhen: (previous, current) =>
              (current.notice != null && previous.notice != current.notice) ||
              previous.submitStatus != current.submitStatus,
          listener: _onStateChanged,
        ),
      ],
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colour.surface,
          body: SafeArea(
            child: BlocBuilder<PostRequestFlowBloc, PostRequestFlowState>(
              builder: (context, state) => Column(
                children: [
                  FlowHeader(title: _title(state), onBack: () => context.pop()),
                  Expanded(
                    child: Stack(
                      children: [
                        _form(context, state),
                        _ProgressOverlay(state: state),
                      ],
                    ),
                  ),
                  _submitBar(state),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, PostRequestFlowState state) {
    final values = state.values;
    final enabled = !state.isWorking;
    final descriptionError = RequestFormValues.descriptionError(
      _description.text,
    );
    final showDescriptionError =
        _descriptionSubmitted &&
        descriptionError != null &&
        descriptionError != DescriptionError.required;
    final showBudgetError =
        _budgetTouched && !RequestFormValues.isValidBudgetText(_budget.text);
    final currencies = state.currencies.isNotEmpty
        ? [for (final c in state.currencies) (code: c.code, id: c.id)]
        : [for (final code in requestCurrencies) (code: code, id: null)];

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: enabled ? 1 : 0.6,
      child: AbsorbPointer(
        absorbing: !enabled,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            // Ô mô tả: chữ → hàng "n/1000" + nút đính kèm (web: trong cùng một khung).
            Container(
              decoration: BoxDecoration(
                color: Colour.surface,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: showDescriptionError
                      ? Colour.error
                      : Colour.lineStrong,
                ),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _description,
                    focusNode: _descriptionFocus,
                    minLines: 4,
                    maxLines: 10,
                    maxLength: RequestFormValues.maxDescription,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTextStyle.lightBodyMediumRegular.copyWith(
                      height: 1.4,
                      color: Colour.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: LocaleKeys.postRequestDetailPlaceholder.tr(),
                      hintStyle: AppTextStyle.lightBodyMediumRegular.copyWith(
                        color: Colour.textTertiary,
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.fromLTRB(
                        14.w,
                        14.h,
                        14.w,
                        6.h,
                      ),
                    ),
                    onChanged: (text) {
                      setState(() {});
                      _update(values.copyWith(description: text));
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 0, 8.w, 8.h),
                    child: Row(
                      children: [
                        Text(
                          '${RequestFormValues.descriptionLength(_description.text)}'
                          '/${RequestFormValues.maxDescription}',
                          style: AppTextStyle.lightBodySmallRegular.copyWith(
                            color: showDescriptionError
                                ? Colour.error
                                : Colour.textTertiary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _pickFiles(values),
                          tooltip: LocaleKeys.postRequestAttach.tr(),
                          style: IconButton.styleFrom(
                            fixedSize: Size.square(32.r),
                            minimumSize: Size.square(32.r),
                            side: const BorderSide(color: Colour.border),
                          ),
                          icon: Icon(
                            Icons.attach_file_rounded,
                            size: 16.r,
                            color: Colour.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (showDescriptionError)
              RequestFieldError(
                descriptionError == DescriptionError.tooShort
                    ? LocaleKeys.postRequestDescTooShort.tr(
                        namedArgs: {
                          'min': '${RequestFormValues.minDescription}',
                        },
                      )
                    : LocaleKeys.postRequestDescTooLong.tr(
                        namedArgs: {
                          'max': '${RequestFormValues.maxDescription}',
                        },
                      ),
              ),
            if (_oversized.isNotEmpty)
              RequestFieldError(
                LocaleKeys.postRequestAttachTooLarge.tr(
                  namedArgs: {
                    'size':
                        '${RequestFormValues.maxAttachmentBytes ~/ 1024 ~/ 1024}',
                    'names': _oversized.join(', '),
                  },
                ),
              ),
            if (values.attachmentPaths.isNotEmpty) ...[
              Gap(8.h),
              Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: [
                  for (final path in values.attachmentPaths)
                    InputChip(
                      label: Text(
                        path.split('/').last,
                        overflow: TextOverflow.ellipsis,
                      ),
                      labelStyle: AppTextStyle.lightBodySmallMedium.copyWith(
                        color: Colour.textPrimary,
                      ),
                      backgroundColor: Colour.mutedWeb,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      onDeleted: () => _update(
                        values.copyWith(
                          attachmentPaths: values.attachmentPaths
                              .where((p) => p != path)
                              .toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (values.hasVoice || state.hasRemovedVoice) ...[
              Gap(12.h),
              ReviewVoiceNoteRow(
                duration: values.voiceDuration ?? state.removedVoiceDuration,
                removed: !values.hasVoice,
                onRemove: () => _bloc.add(const PostRequestFlowVoiceRemoved()),
                onUndo: () => _bloc.add(const PostRequestFlowVoiceRestored()),
              ),
            ],
            Gap(16.h),
            RequestFieldLabel(LocaleKeys.postRequestBudgetLabel.tr()),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _budget,
                    focusNode: _budgetFocus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: AppTextStyle.lightBodyMediumRegular.copyWith(
                      color: Colour.textPrimary,
                    ),
                    decoration: requestInputDecoration(
                      hint: LocaleKeys.postRequestBudgetPlaceholder.tr(),
                      error: showBudgetError,
                    ),
                    onChanged: (text) => _update(values.copyWith(budget: text)),
                  ),
                ),
                Gap(8.w),
                RequestCurrencySelect(
                  value: values.currency,
                  options: currencies,
                  onChanged: (code, id) => _update(
                    values.copyWith(
                      currency: code,
                      currencyId: id,
                      clearCurrencyId: id == null,
                    ),
                  ),
                ),
              ],
            ),
            if (showBudgetError)
              RequestFieldError(LocaleKeys.postRequestBudgetInvalid.tr()),
            Gap(16.h),
            RequestFieldLabel(LocaleKeys.postRequestSupportLabel.tr()),
            RequestDeliveryPicker(
              value: values.deliveryTypes,
              onChanged: (types) =>
                  _update(values.copyWith(deliveryTypes: types)),
            ),
            if (!_isSend) ...[
              Gap(16.h),
              RequestFieldLabel(LocaleKeys.postRequestWorkingLanguage.tr()),
              RequestLanguagePicker(
                value: values.sellerLanguages,
                onChanged: (codes) =>
                    _update(values.copyWith(sellerLanguages: codes)),
              ),
              Gap(12.h),
              Row(
                children: [
                  SizedBox.square(
                    dimension: 24.r,
                    child: Checkbox(
                      value: values.anonymous,
                      activeColor: Colour.buttonPrimary,
                      onChanged: (on) =>
                          _update(values.copyWith(anonymous: on == true)),
                    ),
                  ),
                  Gap(8.w),
                  Flexible(
                    child: GestureDetector(
                      onTap: () => _update(
                        values.copyWith(anonymous: !values.anonymous),
                      ),
                      child: Text(
                        LocaleKeys.postRequestAnonymous.tr(),
                        style: AppTextStyle.lightBodyMediumRegular.copyWith(
                          color: Colour.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: LocaleKeys.postRequestAnonymousHelp.tr(),
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 4),
                    child: Padding(
                      padding: EdgeInsets.all(6.r),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 18.r,
                        color: Colour.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Nút gửi dính ở đáy màn hình (web `stickySubmit`).
  Widget _submitBar(PostRequestFlowState state) {
    final canSubmit =
        _description.text.trim().isNotEmpty &&
        !state.isSubmitting &&
        !state.isWorking;
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      decoration: const BoxDecoration(
        color: Colour.surface,
        border: Border(top: BorderSide(color: Colour.lineSubtle)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48.h,
        child: FilledButton(
          onPressed: canSubmit ? () => _submit(state) : null,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r),
            ),
            textStyle: AppTextStyle.lightBodyLargeMedium,
          ),
          child: state.isSubmitting
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(color: Colors.white),
                    Gap(8.w),
                    Text(LocaleKeys.postRequestPosting.tr()),
                  ],
                )
              : Text(LocaleKeys.postRequestSubmit.tr()),
        ),
      ),
    );
  }
}

/// Thẻ tiến trình nổi giữa form (đang khoá): "AI is analysing your request…" + %.
class _ProgressOverlay extends StatelessWidget {
  final PostRequestFlowState state;

  const _ProgressOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    final working = state.isWorking;
    final percent = state.progress.round();
    return IgnorePointer(
      ignoring: !working,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: working ? 1 : 0,
        child: Container(
          color: Colour.surface.withValues(alpha: 0.5),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Container(
            constraints: BoxConstraints(maxWidth: 360.w),
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colour.surface,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colour.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18.r, color: Colour.primary),
                    Gap(8.w),
                    Expanded(
                      child: Text(
                        state.step == PostRequestDraftStep.transcribing
                            ? LocaleKeys.postRequestStepTranscribing.tr()
                            : LocaleKeys.postRequestStepDrafting.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.lightBodyMediumMedium.copyWith(
                          color: Colour.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                        color: Colour.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Gap(12.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: state.progress / 100,
                    minHeight: 8.h,
                    color: Colour.primary,
                    backgroundColor: Colour.subtle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
