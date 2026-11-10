import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../domain/usecases/auth_use_cases.dart';
import '../bloc/auth/auth_bloc.dart';
import 'auth_fields.dart';

/// Màn Sign up / Sign in: email + mật khẩu + Google/Apple (web `BuyerSignUpForm`, `LoginForm`).
class AuthCredentialsView extends StatefulWidget {
  final bool signUp;
  final String subtitle;

  const AuthCredentialsView({
    super.key,
    required this.signUp,
    required this.subtitle,
  });

  @override
  State<AuthCredentialsView> createState() => _AuthCredentialsViewState();
}

class _AuthCredentialsViewState extends State<AuthCredentialsView> {
  late final _email = TextEditingController(
    text: context.read<AuthBloc>().state.email,
  );
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Web `useEmailDomainValidation`: kiểm tra domain email khi đang gõ ở màn đăng ký.
    if (widget.signUp) {
      _email.addListener(
        () => context.read<AuthBloc>().add(AuthEmailChanged(_email.text)),
      );
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final bloc = context.read<AuthBloc>();
    widget.signUp
        ? bloc.add(
            AuthSignUpSubmitted(email: _email.text, password: _password.text),
          )
        : bloc.add(
            AuthLoginSubmitted(email: _email.text, password: _password.text),
          );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<AuthBloc>();
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.signUp
                  ? LocaleKeys.authSignUpTitle.tr()
                  : LocaleKeys.authSignInTitle.tr(),
              style: AppTextStyle.lightHeadingSmall.copyWith(
                color: theme.textPrimary(context),
              ),
            ),
            Gap(6.h),
            Text(
              widget.subtitle,
              style: AppTextStyle.lightBodyMediumRegular.copyWith(
                height: 1.4,
                color: theme.textSecondary(context),
              ),
            ),
            Gap(20.h),
            AuthTextField(
              label: LocaleKeys.authEmailLabel.tr(),
              controller: _email,
              error:
                  state.emailError ??
                  (widget.signUp ? state.emailDomainError : null),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            Gap(14.h),
            AuthTextField(
              label: LocaleKeys.authPasswordLabel.tr(),
              controller: _password,
              error: state.passwordError,
              hint: widget.signUp ? LocaleKeys.authPasswordHint.tr() : null,
              password: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              autofillHints: [
                widget.signUp
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
            ),
            if (!widget.signUp)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => bloc.add(
                    AuthScreenChanged(
                      AuthScreen.forgotEmail,
                      email: _email.text.trim(),
                    ),
                  ),
                  child: Text(
                    LocaleKeys.authForgotPassword.tr(),
                    style: AppTextStyle.lightBodySmallSemiBold.copyWith(
                      color: theme.textPrimary(context),
                    ),
                  ),
                ),
              )
            else
              Gap(20.h),
            AuthPrimaryButton(
              label: widget.signUp
                  ? LocaleKeys.authSignUp.tr()
                  : LocaleKeys.authSignIn.tr(),
              loadingLabel: widget.signUp
                  ? LocaleKeys.authSigningUp.tr()
                  : LocaleKeys.authSigningIn.tr(),
              loading: state.isSubmitting,
              onPressed: _submit,
            ),
            AuthFormError(error: state.formError),
            Gap(20.h),
            AuthSocialButtons(
              enabled: !state.isSubmitting,
              onGoogle: () =>
                  bloc.add(const AuthSocialRequested(SocialProvider.google)),
              onApple: () =>
                  bloc.add(const AuthSocialRequested(SocialProvider.apple)),
            ),
            Gap(22.h),
            widget.signUp
                ? AuthSwitchLink(
                    question: LocaleKeys.authHaveAccount.tr(),
                    action: LocaleKeys.authSignIn.tr(),
                    onTap: () => bloc.add(
                      AuthScreenChanged(
                        AuthScreen.login,
                        email: _email.text.trim(),
                      ),
                    ),
                  )
                : AuthSwitchLink(
                    question: LocaleKeys.authNoAccount.tr(),
                    action: LocaleKeys.authSignUp.tr(),
                    onTap: () => bloc.add(
                      AuthScreenChanged(
                        AuthScreen.signup,
                        email: _email.text.trim(),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
