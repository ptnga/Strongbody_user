import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/constants/app_spacings.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';

import '../bloc/home/home_bloc.dart';

/// "Hi Sarah" + "What do you need today?" căn giữa khoảng trống.
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlocSelector<HomeBloc, HomeState, String?>(
              selector: (state) => state.firstName,
              builder: (context, firstName) => firstName == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.only(bottom: 6.h),
                      child: Text(
                        LocaleKeys.homeGreeting.tr(args: [firstName]),
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: theme.textSecondary(context),
                        ),
                      ),
                    ),
            ),
            Text(
              LocaleKeys.homeQuestion.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25.sp,
                height: 1.25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: theme.textPrimary(context),
              ),
            ),
            Gap(8.h),
          ],
        ),
      ),
    );
  }
}
