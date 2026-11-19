import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/components/empty_state_view.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/modules/auth/presentation/widgets/auth_sheet.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_page_args.dart';
import 'package:strongbody_buyer/modules/home/presentation/new_offers_badge_notifier.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import '../widgets/voice/get_help_sheet.dart';

import '../bloc/my_requests/my_requests_bloc.dart';
import '../matching_providers_page_args.dart';
import '../request_offers_page_args.dart';
import '../widgets/my_requests/my_request_card.dart';

/// "My requests" — tab Public / Private như web `/buyer/request/management`
/// (`GET /user/requests?is_private=`) + thanh điều hướng dưới (Home về trang đầu).
class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  final _scrollController = ScrollController();

  /// Nền vùng danh sách (xám nhạt hơn `muted`, như mockup).
  static const _listBackground = Color(0xFFF4F6F9);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 400) {
        context.read<MyRequestsBloc>().add(const MyRequestsLoadMore());
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: _listBackground,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: theme.surface(context),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.myRequestsTitle.tr(),
                      style: AppTextStyle.lightHeadingMedium.copyWith(
                        color: theme.textPrimary(context),
                      ),
                    ),
                    BlocBuilder<MyRequestsBloc, MyRequestsState>(
                      buildWhen: (a, b) =>
                          a.tab != b.tab || a.showTabs != b.showTabs,
                      // Chưa đăng nhập → bỏ Public | Private.
                      builder: (context, state) => state.showTabs
                          ? Padding(
                              padding: EdgeInsets.only(top: 12.h),
                              child: _TabSwitch(
                                selected: state.tab,
                                onChanged: (tab) {
                                  AppAnalytics.capture(
                                    AnalyticsEvents.myRequestsTabChanged,
                                    {'tab': tab.name},
                                  );
                                  context.read<MyRequestsBloc>().add(
                                    MyRequestsTabChanged(tab),
                                  );
                                },
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: theme.border(context)),
          Expanded(
            child: BlocBuilder<MyRequestsBloc, MyRequestsState>(
              builder: (context, state) {
                if (state.isFirstLoad) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                final items = state.visibleItems;
                return RefreshIndicator(
                  onRefresh: () async => context.read<MyRequestsBloc>().add(
                    const MyRequestsStarted(),
                  ),
                  child: items.isEmpty && !state.isLoadingMore
                      ? _EmptyState(state: state)
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(16.r),
                          itemCount:
                              items.length + (state.isLoadingMore ? 1 : 0),
                          separatorBuilder: (_, _) => Gap(12.h),
                          itemBuilder: (context, index) {
                            if (index == items.length) {
                              return const Center(
                                child: CupertinoActivityIndicator(),
                              );
                            }
                            final request = items[index];
                            final offers = state.offers[request.id];
                            return MyRequestCard(
                              key: ValueKey(request.id),
                              request: request,
                              offers: offers,
                              onOpen: () async {
                                final bloc = context.read<MyRequestsBloc>();
                                // Request gửi riêng qua inquiry: web "Open chat" với
                                // provider nhận (họ trả lời trong chat, không gửi offer).
                                final recipient = request.inquiry?.recipientId;
                                if (recipient != null && recipient > 0) {
                                  context.push(
                                    RouteName.chat,
                                    extra: ChatPageArgs(
                                      partnerId: recipient,
                                      name: request.inquiry!.recipientName,
                                      avatar: request.inquiry!.recipientAvatar,
                                      source: 'my_requests',
                                    ),
                                  );
                                  return;
                                }
                                AppAnalytics.capture(
                                  AnalyticsEvents.requestCardTapped,
                                  {
                                    'request_id': request.id,
                                    'status': request.status,
                                    'offers_count': request.offersCount,
                                  },
                                );
                                await context.push(
                                  RouteName.requestOffers,
                                  extra: RequestOffersPageArgs.fromRequest(
                                    request,
                                    offers: offers,
                                  ),
                                );
                                // Có thể đã trả / nhận offer → cập nhật thẻ + badge.
                                bloc.add(const MyRequestsStarted());
                                getIt<NewOffersBadgeNotifier>().refresh();
                              },
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented "Active | Closed".
class _TabSwitch extends StatelessWidget {
  final MyRequestsTab selected;
  final ValueChanged<MyRequestsTab> onChanged;

  const _TabSwitch({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget option(MyRequestsTab tab, String label) {
      final active = tab == selected;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(tab),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(vertical: 9.h),
            decoration: BoxDecoration(
              color: active ? theme.surface(context) : Colors.transparent,
              borderRadius: BorderRadius.circular(10.r),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                color: active
                    ? theme.textPrimary(context)
                    : theme.textSecondary(context),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        color: theme.muted(context),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          option(MyRequestsTab.public, LocaleKeys.myRequestsTabPublic.tr()),
          option(MyRequestsTab.private, LocaleKeys.myRequestsTabPrivate.tr()),
        ],
      ),
    );
  }
}

/// Chưa đăng nhập / lỗi / tab trống — vẫn kéo để làm mới được.
class _EmptyState extends StatelessWidget {
  final MyRequestsState state;

  const _EmptyState({required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MyRequestsBloc>();
    void speak() => showGetHelpSheet(context, source: 'my_requests');
    return switch (state.status) {
      MyRequestsStatus.signedOut => EmptyStateView(
        iconAsset: AppSvg.user,
        title: LocaleKeys.myRequestsSignedOutTitle.tr(),
        message: LocaleKeys.myRequestsSignedOutMessage.tr(),
        actionLabel: LocaleKeys.authSignIn.tr(),
        actionIcon: Icons.login_rounded,
        onAction: () async {
          if (await showAuthSheet(context, source: 'my_requests')) {
            bloc.add(const MyRequestsStarted());
          }
        },
      ),
      MyRequestsStatus.failure => EmptyStateView(
        iconAsset: AppSvg.cloud,
        title: LocaleKeys.myRequestsLoadErrorTitle.tr(),
        message: LocaleKeys.commonConnectionMessage.tr(),
        actionLabel: LocaleKeys.commonTryAgain.tr(),
        actionIconAsset: AppSvg.refresh,
        onAction: () => bloc.add(const MyRequestsStarted()),
      ),
      // Web `PrivateRequestsEmpty`: báo trống + "Find a provider" + 3 bước gửi request riêng.
      _ when state.tab == MyRequestsTab.private =>
        const _PrivateRequestsEmpty(),
      _ => EmptyStateView(
        iconAsset: AppSvg.microphone,
        title: LocaleKeys.myRequestsNoneTitle.tr(),
        message: LocaleKeys.myRequestsNoneMessage.tr(),
        actionLabel: LocaleKeys.myRequestsSpeakRequest.tr(),
        actionIconAsset: AppSvg.microphone,
        onAction: speak,
      ),
    };
  }
}

/// Tab "Private requests" chưa có gì (web `PrivateRequestsEmpty`): báo trống + nút tìm
/// provider, kèm 3 bước gửi request riêng (tìm provider → gửi request từ hồ sơ / service /
/// product / offer → trả lời trong Messages).
class _PrivateRequestsEmpty extends StatelessWidget {
  const _PrivateRequestsEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = [
      (
        LocaleKeys.myRequestsPrivateStepFindTitle.tr(),
        LocaleKeys.myRequestsPrivateStepFindDesc.tr(),
      ),
      (
        LocaleKeys.myRequestsPrivateStepSendTitle.tr(),
        LocaleKeys.myRequestsPrivateStepSendDesc.tr(),
      ),
      (
        LocaleKeys.myRequestsPrivateStepChatTitle.tr(),
        LocaleKeys.myRequestsPrivateStepChatDesc.tr(),
      ),
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.r),
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.surface(context),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: theme.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 24.h),
                child: Column(
                  children: [
                    Container(
                      width: 56.r,
                      height: 56.r,
                      decoration: BoxDecoration(
                        color: theme.muted(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 26.r,
                        color: theme.textSecondary(context),
                      ),
                    ),
                    Gap(14.h),
                    Text(
                      LocaleKeys.myRequestsNoPrivateTitle.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyle.lightBodyXLargeBold.copyWith(
                        color: theme.textPrimary(context),
                      ),
                    ),
                    Gap(6.h),
                    Text(
                      LocaleKeys.myRequestsNoPrivateMessage.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyle.lightBodyMediumRegular.copyWith(
                        height: 1.4,
                        color: theme.textSecondary(context),
                      ),
                    ),
                    Gap(18.h),
                    FilledButton.icon(
                      onPressed: () => context.push(
                        RouteName.matchingProviders,
                        extra: const MatchingProvidersPageArgs(),
                      ),
                      icon: Icon(Icons.search_rounded, size: 18.r),
                      label: Text(LocaleKeys.myRequestsPrivateCta.tr()),
                      style: FilledButton.styleFrom(
                        minimumSize: Size(0, 46.h),
                        padding: EdgeInsets.symmetric(horizontal: 22.w),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        textStyle: AppTextStyle.lightBodyMediumBold,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.border(context)),
              Padding(
                padding: EdgeInsets.all(20.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.myRequestsPrivateStepsTitle.tr(),
                      style: AppTextStyle.lightBodyMediumMedium.copyWith(
                        color: theme.textSecondary(context),
                      ),
                    ),
                    for (final (i, (title, desc)) in steps.indexed) ...[
                      Gap(14.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28.r,
                            height: 28.r,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: theme.muted(context),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: AppTextStyle.lightBodyMediumSemiBold
                                  .copyWith(color: theme.textPrimary(context)),
                            ),
                          ),
                          Gap(12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: AppTextStyle.lightBodyMediumMedium
                                      .copyWith(
                                        color: theme.textPrimary(context),
                                      ),
                                ),
                                Gap(2.h),
                                Text(
                                  desc,
                                  style: AppTextStyle.lightBodyMediumRegular
                                      .copyWith(
                                        height: 1.4,
                                        color: theme.textSecondary(context),
                                      ),
                                ),
                              ],
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
        ),
      ],
    );
  }
}
