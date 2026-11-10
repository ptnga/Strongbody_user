import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/components/initials_avatar.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/core/utils/language_names.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_page_args.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_ui.dart';

import '../bloc/request_matches/request_matches_cubit.dart';
import '../request_formatters.dart';
import '../widgets/common/flow_header.dart';

/// "Providers for your request" (web `/buyer/request/matches/{id}`): đã đăng → yêu cầu
/// của bạn → chuyên gia khớp với chính yêu cầu đó (nút Chat chia sẻ request vào cuộc
/// trò chuyện) → "View my requests".
class RequestMatchesPage extends StatelessWidget {
  const RequestMatchesPage({super.key});

  void _close(BuildContext context) => context.go(RouteName.rootScreen);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close(context);
      },
      child: Scaffold(
        backgroundColor: Colour.surface,
        body: SafeArea(
          child: Column(
            children: [
              FlowHeader(
                title: LocaleKeys.requestSentPageTitle.tr(),
                onBack: () => _close(context),
              ),
              Expanded(
                child: BlocBuilder<RequestMatchesCubit, RequestMatchesState>(
                  builder: (context, state) => switch (state.requestStatus) {
                    RequestMatchesStatus.loading => const Center(
                      child: CupertinoActivityIndicator(),
                    ),
                    RequestMatchesStatus.failure => _NotFound(),
                    RequestMatchesStatus.success => _Body(state: state),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(24.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 32.r, color: Colour.error),
          Gap(12.h),
          Text(
            LocaleKeys.requestSentNotFound.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyle.lightBodyMediumRegular.copyWith(
              color: Colour.textSecondary,
            ),
          ),
          Gap(16.h),
          const _MyRequestsLink(),
        ],
      ),
    ),
  );
}

class _Body extends StatelessWidget {
  final RequestMatchesState state;

  const _Body({required this.state});

  @override
  Widget build(BuildContext context) {
    final request = state.request!;
    final facts = <(String, String)>[
      if (RequestMatchesCubit.budgetLabel(request).isNotEmpty)
        (
          LocaleKeys.requestSentFactBudget.tr(),
          RequestMatchesCubit.budgetLabel(request),
        ),
      if (request.deliveryTypes.isNotEmpty)
        (
          LocaleKeys.requestSentFactWhere.tr(),
          request.deliveryTypes
              .map(RequestFormatters.deliveryOption)
              .join(', '),
        ),
      if (request.sellerLanguages.isNotEmpty)
        (
          LocaleKeys.requestSentFactLanguages.tr(),
          request.sellerLanguages.map(languageLabel).join(', '),
        ),
    ];
    final divider = Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: const Divider(height: 1, color: Colour.lineSubtle),
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 32.h),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44.r,
              height: 44.r,
              decoration: const BoxDecoration(
                color: Colour.seller50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 28.r,
                color: Colour.success,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleKeys.requestSentTitle.tr(),
                    style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
                      color: Colour.textPrimary,
                    ),
                  ),
                  Gap(4.h),
                  Text(
                    request.isLive
                        ? LocaleKeys.requestSentBodyLive.tr()
                        : LocaleKeys.requestSentBodyReview.tr(),
                    style: AppTextStyle.lightBodyMediumRegular.copyWith(
                      color: Colour.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        divider,
        Text(
          request.description,
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            height: 1.45,
            color: Colour.textPrimary,
          ),
        ),
        if (facts.isNotEmpty) ...[
          Gap(12.h),
          Wrap(
            spacing: 16.w,
            runSpacing: 6.h,
            children: [
              for (final (label, value) in facts)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$label ',
                        style: const TextStyle(color: Colour.textSecondary),
                      ),
                      TextSpan(text: value),
                    ],
                  ),
                  style: AppTextStyle.lightBodySmallMedium.copyWith(
                    color: Colour.textPrimary,
                  ),
                ),
            ],
          ),
        ],
        divider,
        _Matches(state: state),
        divider,
        const Center(child: _MyRequestsLink()),
      ],
    );
  }
}

class _Matches extends StatelessWidget {
  final RequestMatchesState state;

  const _Matches({required this.state});

  Future<void> _chat(BuildContext context, RequestMatch m) async {
    final cubit = context.read<RequestMatchesCubit>();
    final router = GoRouter.of(context);
    final ok = await cubit.shareToChat(m, LocaleKeys.requestSentChatIntro.tr());
    if (!ok) return;
    router.push(
      RouteName.chat,
      extra: ChatPageArgs(
        partnerId: m.userId,
        name: m.name,
        avatar: m.avatar,
        source: 'request_matches',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metaStyle = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.requestSentMatchesTitle.tr(),
          style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
            color: Colour.textPrimary,
          ),
        ),
        Gap(8.h),
        switch (state.matchesStatus) {
          RequestMatchesStatus.loading => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(LocaleKeys.requestSentMatchesLoading.tr(), style: metaStyle),
              Gap(12.h),
              const Center(child: CupertinoActivityIndicator()),
            ],
          ),
          RequestMatchesStatus.failure => Text(
            state.rateLimited
                ? LocaleKeys.requestSentMatchesRateLimited.tr()
                : LocaleKeys.requestSentMatchesError.tr(),
            style: metaStyle,
          ),
          RequestMatchesStatus.success when state.matches.isEmpty => Text(
            LocaleKeys.requestSentMatchesEmpty.tr(),
            style: metaStyle,
          ),
          RequestMatchesStatus.success => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(LocaleKeys.requestSentMatchesHint.tr(), style: metaStyle),
              for (final m in state.matches) ...[
                Gap(12.h),
                _MatchRow(
                  match: m,
                  opening: state.openingUserId == m.userId,
                  busy: state.openingUserId != null,
                  onChat: () => _chat(context, m),
                ),
              ],
            ],
          ),
        },
      ],
    );
  }
}

class _MatchRow extends StatelessWidget {
  final RequestMatch match;
  final bool opening;
  final bool busy;
  final VoidCallback onChat;

  const _MatchRow({
    required this.match,
    required this.opening,
    required this.busy,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(12.r),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: Colour.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(
                    name: match.name,
                    imageUrl: match.avatar,
                    colorSeed: match.name.hashCode,
                    size: 40.r,
                  ),
                  Gap(10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                match.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyle.lightBodyMediumMedium
                                    .copyWith(color: Colour.textPrimary),
                              ),
                            ),
                            if (match.verified) ...[
                              Gap(4.w),
                              Icon(
                                Icons.verified,
                                size: 16.r,
                                color: Colour.seller,
                              ),
                            ],
                          ],
                        ),
                        if (match.country != null) ...[
                          Gap(2.h),
                          Row(
                            children: [
                              if (match.flag != null) ...[
                                CountryFlag(match.flag),
                                Gap(6.w),
                              ],
                              Flexible(
                                child: Text(
                                  match.country!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyle.lightBodySmallRegular
                                      .copyWith(color: Colour.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (match.serviceTitle != null) ...[
                Gap(8.h),
                Text(
                  match.serviceTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.lightBodySmallRegular.copyWith(
                    color: Colour.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Gap(8.w),
        SizedBox(
          height: 36.h,
          child: FilledButton.icon(
            onPressed: busy ? null : onChat,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              textStyle: AppTextStyle.lightBodyMediumMedium,
            ),
            icon: opening
                ? const CupertinoActivityIndicator(color: Colors.white)
                : Icon(Icons.chat_bubble_outline_rounded, size: 16.r),
            label: Text(LocaleKeys.requestSentChat.tr()),
          ),
        ),
      ],
    ),
  );
}

class _MyRequestsLink extends StatelessWidget {
  const _MyRequestsLink();

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => context.go(RouteName.myRequests),
    child: Text(LocaleKeys.requestSentViewMine.tr()),
  );
}
