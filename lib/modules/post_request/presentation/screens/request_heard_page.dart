import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../bloc/post_request_flow/post_request_flow_bloc.dart';
import '../matching_providers_page_args.dart';
import '../voice_request_page_args.dart';
import '../widgets/common/flow_header.dart';
import '../widgets/heard/heard_action_card.dart';
import '../widgets/heard/heard_transcript_card.dart';
import '../widgets/heard/understood_card.dart';

/// "Here's what I heard": câu đã nói + voice note, phần AI hiểu được, rồi chọn
/// đăng request (→ Review) hoặc xem provider phù hợp.
class RequestHeardPage extends StatelessWidget {
  const RequestHeardPage({super.key});

  static void showNotice(PostRequestNotice notice, String? serverMessage) {
    final message = switch (notice) {
      PostRequestNotice.transcribeFailed =>
        LocaleKeys.heardErrorTranscribe.tr(),
      PostRequestNotice.rateLimited => LocaleKeys.heardErrorRateLimited.tr(),
      PostRequestNotice.emptyVoice => LocaleKeys.heardErrorEmptyVoice.tr(),
      PostRequestNotice.draftFailed => LocaleKeys.heardErrorDraft.tr(),
      PostRequestNotice.descriptionRequired =>
        LocaleKeys.reviewDescriptionRequired.tr(),
      PostRequestNotice.deliveryRequired =>
        LocaleKeys.reviewDeliveryRequired.tr(),
      PostRequestNotice.chooseProviders =>
        LocaleKeys.reviewChooseProvidersRequired.tr(),
      PostRequestNotice.requestFailed =>
        (serverMessage?.isNotEmpty ?? false)
            ? serverMessage!
            : LocaleKeys.reviewRequestFailed.tr(),
    };
    ToastUtil.showError(message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<PostRequestFlowBloc, PostRequestFlowState>(
      // Chỉ báo lỗi phân tích ở đây; lỗi đăng request do màn Review hiện.
      listenWhen: (previous, current) =>
          current.notice != null &&
          previous.notice != current.notice &&
          current.notice!.isAnalysisNotice,
      listener: (context, state) {
        showNotice(state.notice!, state.noticeMessage);
        context.read<PostRequestFlowBloc>().add(
          const PostRequestFlowNoticeConsumed(),
        );
      },
      child: Scaffold(
        backgroundColor: theme.background(context),
        body: SafeArea(
          child: Column(
            children: [
              FlowHeader(
                title: LocaleKeys.heardTitle.tr(),
                onBack: () => context.pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
                  child: Column(
                    children: [
                      const HeardTranscriptCard(),
                      Gap(14.h),
                      const UnderstoodCard(),
                    ],
                  ),
                ),
              ),
              const _HeardActions(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeardActions extends StatelessWidget {
  const _HeardActions();

  static void _track(String action, int? matchCount) => AppAnalytics.capture(
    AnalyticsEvents.heardActionTapped,
    {'action': action, 'match_count': matchCount},
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<PostRequestFlowBloc, PostRequestFlowState>(
      buildWhen: (previous, current) =>
          previous.isAnalyzing != current.isAnalyzing ||
          previous.matchCount != current.matchCount,
      builder: (context, state) {
        final count = state.matchCount;
        return Container(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 4.h),
          color: theme.background(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.heardQuestion.tr(),
                style: AppTextStyle.lightBodyLargeBold.copyWith(
                  color: theme.textPrimary(context),
                ),
              ),
              Gap(12.h),
              HeardActionCard(
                primary: true,
                icon: Icons.campaign_outlined,
                title: LocaleKeys.heardPostTitle.tr(),
                subtitle: LocaleKeys.heardPostSubtitle.tr(),
                loading: state.isAnalyzing,
                onTap: () {
                  _track('post_request', count);
                  // "Get offers" = gửi mọi provider phù hợp; bỏ provider đã chọn bằng
                  // "Request offer" ở Browse trước đó (như nút Post request ở Providers).
                  context.read<PostRequestFlowBloc>()
                    ..add(const PostRequestFlowProvidersSelected([]))
                    ..add(
                      const PostRequestFlowVisibilityChanged(
                        RequestVisibility.allMatching,
                      ),
                    );
                  context.push(RouteName.requestReview);
                },
              ),
              Gap(10.h),
              HeardActionCard(
                icon: Icons.search_rounded,
                title: LocaleKeys.heardBrowseTitle.tr(),
                subtitle: count != null && count > 0
                    ? LocaleKeys.heardBrowseSubtitle.tr(args: ['$count'])
                    : LocaleKeys.heardBrowseSubtitleGeneric.tr(),
                loading: state.isAnalyzing,
                onTap: () {
                  _track('browse_providers', count);
                  context.push(
                    RouteName.matchingProviders,
                    extra: const MatchingProvidersPageArgs(),
                  );
                },
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    _track('say_again', count);
                    context.pushReplacement(
                      RouteName.voiceRequest,
                      extra: VoiceRequestPageArgs(
                        attachmentPaths: state.values.attachmentPaths,
                        source: 'heard',
                      ),
                    );
                  },
                  icon: Icon(Icons.mic_none_rounded, size: 20.r),
                  label: Text(LocaleKeys.heardSayAgain.tr()),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.textPrimary(context),
                    textStyle: AppTextStyle.lightBodyMediumMedium,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
