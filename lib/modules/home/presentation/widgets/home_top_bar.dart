import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';

import 'package:go_router/go_router.dart';
import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../bloc/home/home_bloc.dart';

/// Menu (có chấm báo) · "StrongBody" · avatar chữ viết tắt.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 52.h,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Row(
          children: [
            // Menu bên: New request, My requests, Messages, Browse providers, Recent.
            IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notes_rounded,
                    size: 26.r,
                    color: theme.textPrimary(context),
                  ),
                  Positioned(
                    top: -1.r,
                    right: -2.r,
                    child: Container(
                      width: 8.r,
                      height: 8.r,
                      decoration: BoxDecoration(
                        color: theme.textPrimary(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.surface(context),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                LocaleKeys.homeBrand.tr(),
                textAlign: TextAlign.center,
                style: AppTextStyle.lightBodyXLargeBold.copyWith(
                  color: theme.textPrimary(context),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: BlocBuilder<HomeBloc, HomeState>(
                buildWhen: (previous, current) =>
                    previous.initials != current.initials ||
                    previous.isLoggedIn != current.isLoggedIn,
                builder: (context, state) => GestureDetector(
                  // Avatar → tab Account (khách thấy thẻ Sign in ở đó).
                  onTap: () => context.go(RouteName.account),
                  child: _Avatar(initials: state.initials),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;

  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 36.r,
      height: 36.r,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.muted(context),
        shape: BoxShape.circle,
      ),
      child: initials.isEmpty
          ? Icon(
              Icons.person_outline_rounded,
              size: 20.r,
              color: theme.textSecondary(context),
            )
          : Text(
              initials,
              style: AppTextStyle.lightBodySmallBold.copyWith(
                color: theme.textPrimary(context),
              ),
            ),
    );
  }
}
