import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/modules/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:strongbody_buyer/modules/auth/presentation/widgets/auth_sheet.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../domain/entities/request_form_values.dart';
import '../bloc/post_request_flow/post_request_flow_bloc.dart';
import '../matching_providers_page_args.dart';
import '../request_formatters.dart';
import '../request_posted_page_args.dart';
import '../widgets/common/flow_header.dart';
import '../widgets/review/review_fields.dart';
import 'request_heard_page.dart';

/// "Review your request" — form Post Request (giá trị AI đã điền sẵn) trước khi đăng.
class RequestReviewPage extends StatefulWidget {
  const RequestReviewPage({super.key});

  @override
  State<RequestReviewPage> createState() => _RequestReviewPageState();
}

class _RequestReviewPageState extends State<RequestReviewPage> {
  late final PostRequestFlowBloc _bloc = context.read<PostRequestFlowBloc>();
  late final TextEditingController _description = TextEditingController(
    text: _bloc.state.values.description,
  );
  late final TextEditingController _budget = TextEditingController(
    text: _bloc.state.values.budget,
  );

  /// Đã bấm Post request → hiện lỗi mô tả / cách nhận ngay dưới ô.
  bool _tried = false;

  static const _minDescription = 10;

  bool get _descriptionBad => _description.text.trim().length < _minDescription;
  bool get _budgetBad => !RequestFormValues.isValidBudgetText(_budget.text);

  void _submit(PostRequestFlowState state) {
    FocusScope.of(context).unfocus();
    setState(() => _tried = true);
    if (_descriptionBad || state.values.deliveryTypes.isEmpty || _budgetBad) {
      AppAnalytics.capture(AnalyticsEvents.requestReviewInvalid, {
        'missing': [
          if (_descriptionBad) 'description',
          if (state.values.deliveryTypes.isEmpty) 'delivery',
          if (_budgetBad) 'budget',
        ].join(','),
      });
      return;
    }
    _bloc.add(const PostRequestFlowSubmitted());
  }

  @override
  void dispose() {
    _description.dispose();
    _budget.dispose();
    super.dispose();
  }

  void _update(RequestFormValues values) =>
      _bloc.add(PostRequestFlowValuesChanged(values));

  /// AI phân tích xong khi màn đang mở → nạp lại ô chữ nếu người dùng chưa sửa.
  void _syncAfterAnalysis(PostRequestFlowState state) {
    final values = state.values;
    if (_description.text.trim() == state.transcript.trim()) {
      _description.text = values.description;
    }
    if (_budget.text.isEmpty) _budget.text = values.budget;
  }

  Future<void> _onStateChanged(
    BuildContext context,
    PostRequestFlowState state,
  ) async {
    final notice = state.notice;
    if (notice != null && !notice.isAnalysisNotice) {
      RequestHeardPage.showNotice(notice, state.noticeMessage);
      _bloc.add(const PostRequestFlowNoticeConsumed());
    }
    switch (state.submitStatus) {
      case PostRequestSubmitStatus.success:
        final locale = context.locale.languageCode;
        context.go(
          RouteName.requestPosted,
          extra: RequestPostedPageArgs(
            headline: RequestFormatters.headline(state.values.description),
            summary: RequestFormatters.summary(state.values, locale),
            chosenCount: state.visibility == RequestVisibility.chosenProviders
                ? state.selectedProviders.length
                : null,
            matchCount: state.matchCount,
          ),
        );
      case PostRequestSubmitStatus.pendingAuth:
        // Như web: khách → popup Sign up ("your request will be posted automatically"),
        // đăng nhập xong thì tự đăng request đang chờ.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MultiBlocListener(
      listeners: [
        BlocListener<PostRequestFlowBloc, PostRequestFlowState>(
          listenWhen: (previous, current) =>
              previous.isAnalyzing && !current.isAnalyzing,
          listener: (context, state) => _syncAfterAnalysis(state),
        ),
        BlocListener<PostRequestFlowBloc, PostRequestFlowState>(
          listenWhen: (previous, current) =>
              (current.notice != null &&
                  previous.notice != current.notice &&
                  !current.notice!.isAnalysisNotice) ||
              previous.submitStatus != current.submitStatus,
          listener: _onStateChanged,
        ),
      ],
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: theme.muted(context),
          body: SafeArea(
            child: Column(
              children: [
                FlowHeader(
                  title: LocaleKeys.reviewTitle.tr(),
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: BlocBuilder<PostRequestFlowBloc, PostRequestFlowState>(
                    builder: (context, state) => _buildForm(context, state),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, PostRequestFlowState state) {
    final theme = Theme.of(context);
    final values = state.values;
    final suggestion = state.assistant?.suggestion ?? '';
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (values.hasVoice || state.hasRemovedVoice) ...[
          ReviewVoiceNoteRow(
            duration: values.voiceDuration ?? state.removedVoiceDuration,
            removed: !values.hasVoice,
            onRemove: () => _bloc.add(const PostRequestFlowVoiceRemoved()),
            onUndo: () => _bloc.add(const PostRequestFlowVoiceRestored()),
          ),
          Gap(18.h),
        ],
        ReviewLabel(LocaleKeys.reviewWhatLabel.tr(), required: true),
        TextField(
          controller: _description,
          minLines: 4,
          maxLines: 8,
          maxLength: RequestFormValues.maxDescription,
          textCapitalization: TextCapitalization.sentences,
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            height: 1.4,
            color: theme.textPrimary(context),
          ),
          decoration: reviewInputDecoration(
            context,
            hint: LocaleKeys.reviewWhatPlaceholder.tr(),
            error: _tried && _descriptionBad,
          ),
          onChanged: (text) => _update(values.copyWith(description: text)),
        ),
        if (_tried && _descriptionBad)
          ReviewFieldError(LocaleKeys.reviewDescriptionTooShort.tr())
        else ...[
          Gap(6.h),
          Text(
            LocaleKeys.reviewCharCount.tr(
              args: [
                '${_description.text.length}',
                '${RequestFormValues.maxDescription}',
              ],
            ),
            style: AppTextStyle.lightBodySmallRegular.copyWith(
              color: theme.textSecondary(context),
            ),
          ),
        ],
        Gap(20.h),
        ReviewLabel(LocaleKeys.reviewReceiveLabel.tr(), required: true),
        ReviewDeliveryChips(
          value: values.deliveryTypes,
          onChanged: (types) => _update(values.copyWith(deliveryTypes: types)),
        ),
        if (_tried && values.deliveryTypes.isEmpty)
          ReviewFieldError(LocaleKeys.reviewDeliveryChooseOne.tr()),
        Gap(20.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReviewLabel(LocaleKeys.reviewWhenLabel.tr()),
                  ReviewWhenField(values: values, onChanged: _update),
                ],
              ),
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReviewBudgetLabel(
                    currency: values.currency,
                    onChanged: (c) => _update(values.copyWith(currency: c)),
                  ),
                  SizedBox(
                    height: 50.h,
                    child: TextField(
                      controller: _budget,
                      style: AppTextStyle.lightBodyMediumRegular.copyWith(
                        color: theme.textPrimary(context),
                      ),
                      decoration: reviewInputDecoration(
                        context,
                        hint: LocaleKeys.reviewBudgetPlaceholder.tr(),
                        error: _budgetBad,
                      ),
                      onChanged: (text) =>
                          _update(values.copyWith(budget: text)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_budgetBad) ReviewFieldError(LocaleKeys.reviewBudgetFormat.tr()),
        Gap(20.h),
        ReviewLabel(LocaleKeys.reviewVisibilityLabel.tr()),
        ReviewVisibilityOption(
          title: LocaleKeys.reviewAllTitle.tr(),
          subtitle: LocaleKeys.reviewAllSubtitle.tr(),
          selected: state.visibility == RequestVisibility.allMatching,
          onTap: () => _bloc.add(
            const PostRequestFlowVisibilityChanged(
              RequestVisibility.allMatching,
            ),
          ),
        ),
        Gap(10.h),
        ReviewVisibilityOption(
          title: LocaleKeys.reviewChosenTitle.tr(),
          subtitle: LocaleKeys.reviewChosenSubtitle.tr(),
          selected: state.visibility == RequestVisibility.chosenProviders,
          onTap: () {
            _bloc.add(
              const PostRequestFlowVisibilityChanged(
                RequestVisibility.chosenProviders,
              ),
            );
            if (state.selectedProviders.isEmpty) _chooseProviders(context);
          },
          footer: state.visibility == RequestVisibility.chosenProviders
              ? Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: GestureDetector(
                    onTap: () => _chooseProviders(context),
                    child: Text(
                      state.selectedProviders.isEmpty
                          ? LocaleKeys.reviewChooseProviders.tr()
                          : LocaleKeys.reviewChosenCount.tr(
                              args: ['${state.selectedProviders.length}'],
                            ),
                      style: AppTextStyle.lightBodySmallSemiBold.copyWith(
                        color: theme.primary(context),
                      ),
                    ),
                  ),
                )
              : null,
        ),
        if (suggestion.isNotEmpty) ...[
          Gap(18.h),
          ReviewTipBox(text: suggestion),
        ],
        Gap(20.h),
        SizedBox(
          height: 52.h,
          child: FilledButton(
            // Đang phân tích: bloc sẽ bỏ qua submit → khoá nút + hiện đang chờ.
            onPressed: state.isSubmitting || state.isAnalyzing
                ? null
                : () => _submit(state),
            style: FilledButton.styleFrom(
              backgroundColor: theme.secondary(context),
              disabledBackgroundColor: theme
                  .secondary(context)
                  .withValues(alpha: 0.7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
              textStyle: AppTextStyle.lightBodyLargeBold,
            ),
            child: state.isSubmitting || state.isAnalyzing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CupertinoActivityIndicator(color: Colors.white),
                      Gap(8.w),
                      Text(
                        state.isSubmitting
                            ? LocaleKeys.reviewPosting.tr()
                            : LocaleKeys.reviewSubmit.tr(),
                      ),
                    ],
                  )
                : Text(LocaleKeys.reviewSubmit.tr()),
          ),
        ),
        Gap(10.h),
        Text(
          LocaleKeys.reviewDisclaimer.tr(),
          textAlign: TextAlign.center,
          style: AppTextStyle.lightBodySmallRegular.copyWith(
            height: 1.4,
            color: theme.textSecondary(context),
          ),
        ),
      ],
    );
  }

  void _chooseProviders(BuildContext context) => context.push(
    RouteName.matchingProviders,
    extra: const MatchingProvidersPageArgs(mode: MatchingProvidersMode.choose),
  );
}
