import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../bloc/auth/auth_bloc.dart';
import 'auth_fields.dart';

TextStyle _title(BuildContext context) => AppTextStyle.lightHeadingSmall
    .copyWith(color: Theme.of(context).textPrimary(context));

TextStyle _body(BuildContext context) => AppTextStyle.lightBodyMediumRegular
    .copyWith(height: 1.4, color: Theme.of(context).textSecondary(context));

/// Nhập mã 4 số — xác minh email (web `ModalVerifyOtp`) hoặc mã quên mật khẩu.
class AuthOtpView extends StatefulWidget {
  const AuthOtpView({super.key});

  @override
  State<AuthOtpView> createState() => _AuthOtpViewState();
}

class _AuthOtpViewState extends State<AuthOtpView> {
  final _otp = TextEditingController();

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<AuthBloc>();
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final forgot = state.screen == AuthScreen.forgotOtp;
        final error = state.otpError?.resolve();
        final seconds = state.resendIn;
        final countdown =
            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              forgot
                  ? LocaleKeys.authForgotTitle.tr()
                  : LocaleKeys.authOtpTitle.tr(),
              style: _title(context),
            ),
            Gap(6.h),
            Text(
              forgot
                  ? LocaleKeys.authForgotOtpSubtitle.tr()
                  : LocaleKeys.authOtpSent.tr(),
              style: _body(context),
            ),
            Text(
              state.email,
              style: AppTextStyle.lightBodyMediumBold.copyWith(
                color: theme.textPrimary(context),
              ),
            ),
            Gap(22.h),
            TextField(
              controller: _otp,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofillHints: const [AutofillHints.oneTimeCode],
              onChanged: (code) {
                if (code.length == 4) bloc.add(AuthOtpSubmitted(code));
              },
              style: AppTextStyle.lightHeadingMedium.copyWith(
                letterSpacing: 18.w,
                color: theme.textPrimary(context),
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                hintStyle: TextStyle(
                  color: theme.textTertiary(context),
                  letterSpacing: 18.w,
                ),
                filled: true,
                fillColor: theme.surface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: theme.border(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(
                    color: (error?.isNotEmpty ?? false)
                        ? Colour.error
                        : theme.border(context),
                  ),
                ),
              ),
            ),
            if (error?.isNotEmpty ?? false) ...[
              Gap(6.h),
              Text(
                error!,
                style: AppTextStyle.lightBodySmallRegular.copyWith(
                  color: Colour.error,
                ),
              ),
            ],
            Gap(14.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${LocaleKeys.authOtpNoCode.tr()} ',
                  style: _body(context),
                ),
                GestureDetector(
                  onTap: seconds > 0
                      ? null
                      : () => bloc.add(const AuthResendRequested()),
                  child: Text(
                    seconds > 0
                        ? LocaleKeys.authResendIn.tr(args: [countdown])
                        : LocaleKeys.authResend.tr(),
                    style: AppTextStyle.lightBodyMediumBold.copyWith(
                      color: seconds > 0
                          ? theme.textTertiary(context)
                          : theme.primary(context),
                    ),
                  ),
                ),
              ],
            ),
            Gap(20.h),
            AuthPrimaryButton(
              label: forgot
                  ? LocaleKeys.authVerify.tr()
                  : LocaleKeys.authSend.tr(),
              loadingLabel: LocaleKeys.authVerifying.tr(),
              loading: state.isSubmitting,
              onPressed: () => bloc.add(AuthOtpSubmitted(_otp.text)),
            ),
            Gap(16.h),
            AuthSwitchLink(
              question: LocaleKeys.authHaveAccount.tr(),
              action: LocaleKeys.authSignIn.tr(),
              onTap: () => bloc.add(
                AuthScreenChanged(AuthScreen.login, email: state.email),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Quên mật khẩu bước 1: nhập email để nhận mã.
class AuthForgotEmailView extends StatefulWidget {
  const AuthForgotEmailView({super.key});

  @override
  State<AuthForgotEmailView> createState() => _AuthForgotEmailViewState();
}

class _AuthForgotEmailViewState extends State<AuthForgotEmailView> {
  late final _email = TextEditingController(
    text: context.read<AuthBloc>().state.email,
  );

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AuthBloc>();
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(LocaleKeys.authForgotTitle.tr(), style: _title(context)),
          Gap(6.h),
          Text(LocaleKeys.authForgotSubtitle.tr(), style: _body(context)),
          Gap(20.h),
          AuthTextField(
            label: LocaleKeys.authEmailLabel.tr(),
            controller: _email,
            error: state.emailError,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => bloc.add(AuthForgotEmailSubmitted(value)),
          ),
          Gap(20.h),
          AuthPrimaryButton(
            label: LocaleKeys.authSendCode.tr(),
            loading: state.isSubmitting,
            onPressed: () => bloc.add(AuthForgotEmailSubmitted(_email.text)),
          ),
          Gap(16.h),
          Center(
            child: TextButton(
              onPressed: () => bloc.add(
                AuthScreenChanged(AuthScreen.login, email: _email.text.trim()),
              ),
              child: Text(LocaleKeys.authBackToSignIn.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quên mật khẩu bước 3: mật khẩu mới + nhập lại.
class AuthNewPasswordView extends StatefulWidget {
  const AuthNewPasswordView({super.key});

  @override
  State<AuthNewPasswordView> createState() => _AuthNewPasswordViewState();
}

class _AuthNewPasswordViewState extends State<AuthNewPasswordView> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AuthBloc>();
    void submit() => bloc.add(
      AuthNewPasswordSubmitted(
        password: _password.text,
        confirm: _confirm.text,
      ),
    );
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(LocaleKeys.authNewPasswordTitle.tr(), style: _title(context)),
          Gap(20.h),
          AuthTextField(
            label: LocaleKeys.authNewPassword.tr(),
            controller: _password,
            hint: LocaleKeys.authPasswordHint.tr(),
            password: true,
            autofillHints: const [AutofillHints.newPassword],
          ),
          Gap(14.h),
          AuthTextField(
            label: LocaleKeys.authConfirmPassword.tr(),
            controller: _confirm,
            error: state.passwordError,
            password: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => submit(),
          ),
          Gap(20.h),
          AuthPrimaryButton(
            label: LocaleKeys.authResetPassword.tr(),
            loading: state.isSubmitting,
            onPressed: submit,
          ),
          AuthFormError(error: state.formError),
        ],
      ),
    );
  }
}

/// Đổi mật khẩu xong → quay lại đăng nhập.
class AuthResetDoneView extends StatelessWidget {
  const AuthResetDoneView({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AuthBloc>();
    return Column(
      children: [
        Gap(12.h),
        Container(
          width: 72.r,
          height: 72.r,
          decoration: BoxDecoration(
            color: Colour.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: AppIcon(AppSvg.check, size: 36.r, color: Colour.success),
        ),
        Gap(16.h),
        Text(LocaleKeys.authResetDoneTitle.tr(), style: _title(context)),
        Gap(6.h),
        Text(
          LocaleKeys.authResetDoneMessage.tr(),
          textAlign: TextAlign.center,
          style: _body(context),
        ),
        Gap(24.h),
        AuthPrimaryButton(
          label: LocaleKeys.authBackToSignIn.tr(),
          onPressed: () => bloc.add(
            AuthScreenChanged(AuthScreen.login, email: bloc.state.email),
          ),
        ),
      ],
    );
  }
}
