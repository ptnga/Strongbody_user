import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/components/initials_avatar.dart';
import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_badge_notifier.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/matching_providers_page_args.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/post_request_flow_args.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/request_formatters.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/request_offers_page_args.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/voice_request_page_args.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_category.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/market_formatters.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/market_navigation.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../bloc/home_menu/home_menu_cubit.dart';
import '../new_offers_badge_notifier.dart';

/// Menu ☰ ở Home: New request · My requests · Messages · Browse providers · Recent · hồ sơ.
class HomeMenuDrawer extends StatelessWidget {
  const HomeMenuDrawer({super.key});

  /// Đóng menu rồi điều hướng (tránh push khi drawer còn mở).
  void _go(BuildContext context, void Function(GoRouter router) action) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    action(router);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: theme.surface(context),
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: BlocBuilder<HomeMenuCubit, HomeMenuState>(
          builder: (context, state) {
            Widget link(
              String icon,
              String label,
              VoidCallback onTap, {
              ValueNotifier<int>? badge,
            }) => ListTile(
              leading: AppIcon(
                icon,
                size: 24.r,
                color: theme.textPrimary(context),
              ),
              title: Text(
                label,
                style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                  color: theme.textPrimary(context),
                ),
              ),
              trailing: badge == null
                  ? null
                  : ValueListenableBuilder<int>(
                      valueListenable: badge,
                      builder: (context, count, _) => count <= 0
                          ? const SizedBox.shrink()
                          : Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 7.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: theme.textPrimary(context),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$count',
                                style: AppTextStyle.lightBodyXSmallBold
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                    ),
              onTap: onTap,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 8.w, 8.h),
                  child: Row(
                    children: [
                      Text(
                        'StrongBody',
                        style: AppTextStyle.lightBodyXLargeBold.copyWith(
                          color: theme.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: SizedBox(
                    height: 48.h,
                    child: FilledButton.icon(
                      onPressed: () => _go(
                        context,
                        (r) => r.push(
                          RouteName.voiceRequest,
                          extra: const VoiceRequestPageArgs(source: 'menu'),
                        ),
                      ),
                      icon: AppIcon(AppSvg.microphone, size: 24.r),
                      label: Text(LocaleKeys.homeMenuNewRequest.tr()),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.primary(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        textStyle: AppTextStyle.lightBodyMediumBold,
                      ),
                    ),
                  ),
                ),
                Gap(8.h),
                // Phần giữa cuộn được: Social Market mở rộng + Recent không tràn màn nhỏ.
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      link(
                        Icons.move_to_inbox_outlined,
                        LocaleKeys.myRequestsTitle.tr(),
                        () => _go(context, (r) => r.go(RouteName.myRequests)),
                        badge: getIt<NewOffersBadgeNotifier>(),
                      ),
                      link(
                        Icons.chat_bubble_outline_rounded,
                        LocaleKeys.messagesTitle.tr(),
                        () => _go(context, (r) => r.go(RouteName.messages)),
                        badge: getIt<ChatBadgeNotifier>(),
                      ),
                      // Social Market (web sidebar): mở ra 4 trang con theo `SOCIAL_MARKET_NAV`.
                      Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: Icon(
                            Icons.shopping_bag_outlined,
                            color: theme.textPrimary(context),
                          ),
                          title: Text(
                            LocaleKeys.marketSocialMarket.tr(),
                            style: AppTextStyle.lightBodyMediumSemiBold
                                .copyWith(color: theme.textPrimary(context)),
                          ),
                          iconColor: theme.textPrimary(context),
                          collapsedIconColor: theme.textPrimary(context),
                          childrenPadding: EdgeInsets.only(left: 40.w),
                          children: [
                            for (final category in MarketCategory.values)
                              ListTile(
                                dense: true,
                                title: Text(
                                  MarketFormatters.categoryLabel(category),
                                  style: AppTextStyle.lightBodyMediumRegular
                                      .copyWith(
                                        color: theme.textPrimary(context),
                                      ),
                                ),
                                onTap: () => _go(
                                  context,
                                  (r) =>
                                      r.push(MarketRoutes.category(category)),
                                ),
                              ),
                            // Medical Travel: landing riêng (web `CategoryLandingPage`).
                            ListTile(
                              dense: true,
                              title: Text(
                                LocaleKeys.marketMedicalTravel.tr(),
                                style: AppTextStyle.lightBodyMediumRegular
                                    .copyWith(
                                      color: theme.textPrimary(context),
                                    ),
                              ),
                              onTap: () => _go(
                                context,
                                (r) => r.push(MarketRoutes.medicalTravel),
                              ),
                            ),
                          ],
                        ),
                      ),
                      link(
                        Icons.search_rounded,
                        LocaleKeys.homeMenuBrowseProviders.tr(),
                        () => _go(
                          context,
                          (r) => r.push(
                            RouteName.matchingProviders,
                            extra: const MatchingProvidersPageArgs(
                              start: PostRequestFlowArgs(browseOnly: true),
                            ),
                          ),
                        ),
                      ),
                      if (state.recent.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 4.h),
                          child: Text(
                            LocaleKeys.homeMenuRecent.tr(),
                            style: AppTextStyle.lightBodySmallSemiBold.copyWith(
                              color: theme.textSecondary(context),
                            ),
                          ),
                        ),
                        for (final request in state.recent)
                          ListTile(
                            dense: true,
                            title: Text(
                              RequestFormatters.headline(request.description),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.lightBodyMediumRegular
                                  .copyWith(color: theme.textPrimary(context)),
                            ),
                            onTap: () => _go(
                              context,
                              (r) => r.push(
                                RouteName.requestOffers,
                                extra: RequestOffersPageArgs.fromRequest(
                                  request,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.border(context)),
                ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 6.h,
                  ),
                  leading: InitialsAvatar(
                    name: state.name ?? '',
                    colorSeed: 5,
                    size: 40.r,
                  ),
                  title: Text(
                    state.loggedIn
                        ? (state.name ?? '')
                        : LocaleKeys.authSignIn.tr(),
                    style: AppTextStyle.lightBodyMediumBold.copyWith(
                      color: theme.textPrimary(context),
                    ),
                  ),
                  subtitle: state.points == null
                      ? null
                      : Text(
                          LocaleKeys.homeMenuPoints.tr(
                            args: [
                              NumberFormat.decimalPattern(
                                context.locale.toString(),
                              ).format(state.points),
                            ],
                          ),
                        ),
                  onTap: () => _go(context, (r) => r.go(RouteName.account)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
