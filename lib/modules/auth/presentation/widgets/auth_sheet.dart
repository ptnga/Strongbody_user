import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';

import '../bloc/auth/auth_bloc.dart';
import 'auth_code_views.dart';
import 'auth_credentials_view.dart';

/// Mở sheet đăng ký / đăng nhập (mobile của web `AuthDialog`). Trả `true` khi đã đăng nhập.
///
/// [initial] = `signup` cho luồng đăng request (web `PostRequestContext`), `login` cho các
/// chỗ khác (web `AuthGate`). [subtitle] mặc định theo màn. [source] = nơi mở (analytics).
Future<bool> showAuthSheet(
  BuildContext context, {
  AuthScreen initial = AuthScreen.login,
  String? subtitle,
  required String source,
}) async {
  AppAnalytics.capture(AnalyticsEvents.authSheetOpened, {
    'source': source,
    'screen': initial.name,
  });
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).surface(context),
    builder: (_) => BlocProvider(
      create: (_) => getIt<AuthBloc>()..add(AuthStarted(screen: initial)),
      child: _AuthSheet(subtitle: subtitle),
    ),
  );
  final signedIn = result ?? false;
  AppAnalytics.capture(AnalyticsEvents.authSheetClosed, {
    'source': source,
    'signed_in': signedIn,
  });
  return signedIn;
}

class _AuthSheet extends StatelessWidget {
  final String? subtitle;

  const _AuthSheet({this.subtitle});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == AuthStatus.success,
      listener: (context, state) {
        ToastUtil.showSuccess(LocaleKeys.authWelcome.tr());
        Navigator.of(context).pop(true);
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
          child: BlocBuilder<AuthBloc, AuthState>(
            buildWhen: (previous, current) => previous.screen != current.screen,
            builder: (context, state) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(state.screen),
                child: switch (state.screen) {
                  AuthScreen.signup => AuthCredentialsView(
                    signUp: true,
                    subtitle: subtitle ?? LocaleKeys.authRequestSubtitle.tr(),
                  ),
                  AuthScreen.login => AuthCredentialsView(
                    signUp: false,
                    subtitle: subtitle ?? LocaleKeys.authLoginSubtitle.tr(),
                  ),
                  AuthScreen.verifyOtp ||
                  AuthScreen.forgotOtp => const AuthOtpView(),
                  AuthScreen.forgotEmail => const AuthForgotEmailView(),
                  AuthScreen.forgotNewPassword => const AuthNewPasswordView(),
                  AuthScreen.forgotDone => const AuthResetDoneView(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
