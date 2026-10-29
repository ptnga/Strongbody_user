import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../request_posted_page_args.dart';

/// "Request posted" — xác nhận đã đăng, tóm tắt request, đi tới My requests / Home.
class RequestPostedPage extends StatelessWidget {
  final RequestPostedPageArgs args;

  const RequestPostedPage({super.key, required this.args});

  static void _track(String action) => AppAnalytics.capture(
    AnalyticsEvents.requestPostedCtaTapped,
    {'action': action},
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = args.chosenCount;
    final count = args.matchCount;
    final message = chosen != null
        ? LocaleKeys.postedSentTo.tr(args: ['$chosen'])
        : count != null && count > 0
        ? LocaleKeys.postedSharedWith.tr(args: ['$count'])
        : LocaleKeys.postedSharedGeneric.tr();
    final summary = args.summary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RouteName.rootScreen);
      },
      child: Scaffold(
        backgroundColor: theme.surface(context),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
              child: Column(
                children: [
                  Container(
                    width: 96.r,
                    height: 96.r,
                    decoration: BoxDecoration(
                      color: Colour.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: AppIcon(
                      AppSvg.check,
                      size: 48.r,
                      color: Colour.success,
                    ),
                  ),
                  Gap(20.h),
                  Text(
                    LocaleKeys.postedTitle.tr(),
                    style: AppTextStyle.lightHeadingMedium.copyWith(
                      color: theme.textPrimary(context),
                    ),
                  ),
                  Gap(8.h),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTextStyle.lightBodyMediumRegular.copyWith(
                      height: 1.45,
                      color: theme.textSecondary(context),
                    ),
                  ),
                  Gap(24.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14.r),
                    decoration: BoxDecoration(
                      color: theme.background(context),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: theme.border(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocaleKeys.postedYourRequest.tr(),
                          style: AppTextStyle.lightBodySmallRegular.copyWith(
                            color: theme.textSecondary(context),
                          ),
                        ),
                        Gap(4.h),
                        Text(
                          args.headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.lightBodyLargeBold.copyWith(
                            color: theme.textPrimary(context),
                          ),
                        ),
                        if (summary.isNotEmpty) ...[
                          Gap(4.h),
                          Text(
                            summary,
                            style: AppTextStyle.lightBodySmallRegular.copyWith(
                              color: theme.textSecondary(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Gap(28.h),
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: FilledButton(
                      onPressed: () {
                        _track('my_requests');
                        context.go(RouteName.myRequests);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.secondary(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        textStyle: AppTextStyle.lightBodyMediumBold,
                      ),
                      child: Text(LocaleKeys.postedViewMyRequests.tr()),
                    ),
                  ),
                  Gap(10.h),
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: OutlinedButton(
                      onPressed: () {
                        _track('home');
                        context.go(RouteName.rootScreen);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.textPrimary(context),
                        side: BorderSide(color: theme.border(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        textStyle: AppTextStyle.lightBodyMediumSemiBold,
                      ),
                      child: Text(LocaleKeys.postedBackHome.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
