import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';

import '../bloc/auth/auth_bloc.dart';

extension AuthMessageText on AuthMessage {
  String resolve() => key?.tr() ?? text ?? '';
}

/// Ô nhập có nhãn + lỗi dưới ô (+ nút ẩn/hiện mật khẩu).
class AuthTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final AuthMessage? error;
  final String? hint;
  final bool password;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<String>? autofillHints;

  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.error,
    this.hint,
    this.password = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = widget.error?.resolve();
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: color),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: theme.textPrimary(context),
          ),
        ),
        Gap(6.h),
        TextField(
          controller: widget.controller,
          obscureText: widget.password && _obscure,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          autofillHints: widget.autofillHints,
          autocorrect: false,
          enableSuggestions: !widget.password,
          style: TextStyle(fontSize: 15.sp, color: theme.textPrimary(context)),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: theme.surface(context),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: 14.h,
            ),
            border: border(theme.border(context)),
            enabledBorder: border(
              error?.isNotEmpty ?? false ? Colour.error : theme.border(context),
            ),
            focusedBorder: border(theme.textPrimary(context)),
            suffixIcon: widget.password
                ? IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20.r,
                      color: theme.textSecondary(context),
                    ),
                  )
                : null,
          ),
        ),
        if (error?.isNotEmpty ?? false) ...[
          Gap(4.h),
          Text(
            error!,
            style: TextStyle(fontSize: 12.sp, color: Colour.error),
          ),
        ] else if (widget.hint != null) ...[
          Gap(4.h),
          Text(
            widget.hint!,
            style: TextStyle(
              fontSize: 12.sp,
              color: theme.textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// Nút chính tối màu (Sign up / Sign in / Send…), có trạng thái đang xử lý.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final String? loadingLabel;
  final bool loading;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: theme.secondary(context),
          disabledBackgroundColor: theme
              .secondary(context)
              .withValues(alpha: 0.7),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          textStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
        ),
        child: loading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CupertinoActivityIndicator(color: Colors.white),
                  if (loadingLabel != null) ...[Gap(8.w), Text(loadingLabel!)],
                ],
              )
            : Text(label),
      ),
    );
  }
}

/// "Or" + "Continue with Google" + nút Apple (như web `ModalSignUp` / `ModalLogin`).
class AuthSocialButtons extends StatelessWidget {
  final bool enabled;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  const AuthSocialButtons({
    super.key,
    required this.enabled,
    required this.onGoogle,
    required this.onApple,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final side = BorderSide(color: theme.border(context));
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.r),
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: theme.border(context))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Text(
                LocaleKeys.authOr.tr(),
                style: TextStyle(
                  fontSize: 13.sp,
                  color: theme.textSecondary(context),
                ),
              ),
            ),
            Expanded(child: Divider(color: theme.border(context))),
          ],
        ),
        Gap(14.h),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48.h,
                child: OutlinedButton(
                  onPressed: enabled ? onGoogle : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.textPrimary(context),
                    side: side,
                    shape: shape,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'G',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4285F4),
                        ),
                      ),
                      Gap(8.w),
                      Text(
                        LocaleKeys.authContinueGoogle.tr(),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Gap(10.w),
            SizedBox(
              width: 48.h,
              height: 48.h,
              child: OutlinedButton(
                onPressed: enabled ? onApple : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textPrimary(context),
                  side: side,
                  shape: shape,
                  padding: EdgeInsets.zero,
                ),
                child: Icon(
                  Icons.apple,
                  size: 24.r,
                  semanticLabel: LocaleKeys.authContinueApple.tr(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Already have an account? Sign in" / "Don't have an account? Sign up".
class AuthSwitchLink extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback onTap;

  const AuthSwitchLink({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$question ',
            style: TextStyle(
              fontSize: 14.sp,
              color: theme.textSecondary(context),
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              action,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: theme.primary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lỗi chung dưới form.
class AuthFormError extends StatelessWidget {
  final AuthMessage? error;

  const AuthFormError({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    final text = error?.resolve();
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.sp, color: Colour.error),
      ),
    );
  }
}
