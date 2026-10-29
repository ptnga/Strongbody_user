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
import 'package:strongbody_buyer/modules/home/presentation/new_offers_badge_notifier.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../bloc/my_requests/my_requests_bloc.dart';
import '../request_offers_page_args.dart';
import '../widgets/my_requests/my_request_card.dart';
import '../voice_request_page_args.dart';

/// "My requests" — tab Active / Closed (Multime `ManageRequest`, `GET /user/requests`)
/// + thanh điều hướng dưới (Home về trang đầu).
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
                      // Chưa có request nào / chưa đăng nhập → bỏ Active | Closed (mockup).
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
          option(MyRequestsTab.active, LocaleKeys.myRequestsTabActive.tr()),
          option(MyRequestsTab.closed, LocaleKeys.myRequestsTabClosed.tr()),
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
    void speak() => context.push(
      RouteName.voiceRequest,
      extra: const VoiceRequestPageArgs(source: 'my_requests'),
    );
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
      _ when state.tab == MyRequestsTab.closed => EmptyStateView(
        iconAsset: AppSvg.box,
        title: LocaleKeys.myRequestsNoClosedTitle.tr(),
        message: LocaleKeys.myRequestsNoClosedMessage.tr(),
        actionLabel: LocaleKeys.myRequestsSpeakRequest.tr(),
        actionIconAsset: AppSvg.microphone,
        onAction: speak,
      ),
      _ => EmptyStateView(
        iconAsset: AppSvg.microphone,
        title: state.hasAnyRequest
            ? LocaleKeys.myRequestsNoOpenTitle.tr()
            : LocaleKeys.myRequestsNoneTitle.tr(),
        message: LocaleKeys.myRequestsNoneMessage.tr(),
        actionLabel: LocaleKeys.myRequestsSpeakRequest.tr(),
        actionIconAsset: AppSvg.microphone,
        onAction: speak,
      ),
    };
  }
}
