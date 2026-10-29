import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/components/initials_avatar.dart';
import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';
import 'package:strongbody_buyer/modules/auth/presentation/bloc/auth/auth_bloc.dart'
    show AuthMessage;
import 'package:strongbody_buyer/modules/auth/presentation/widgets/auth_fields.dart';
import 'package:strongbody_buyer/modules/auth/presentation/widgets/auth_sheet.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_formatters.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_options.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/matching_providers_page_args.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/post_request_flow_args.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../bloc/account/account_bloc.dart';
import '../widgets/account_widgets.dart';

/// Tab "Account": profile, Lion Points, Voice & language, Orders & saved, Support, Log out.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  static const _background = Color(0xFFF4F6F9);

  void _comingSoon() => ToastUtil.showInfo(LocaleKeys.navComingSoon.tr());

  Future<void> _pickLanguage(BuildContext context, String? current) async {
    final theme = Theme.of(context);
    final locale = context.locale.languageCode;
    final bloc = context.read<AccountBloc>();
    // Bọc `code` để phân biệt "chọn Auto-detect" (null) với đóng sheet.
    final picked = await showModalBottomSheet<({String? code})>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.surface(context),
      builder: (context) {
        Widget option(String? code, String label, String? hint) => ListTile(
          title: Text(label, style: AppTextStyle.lightBodyMediumRegular),
          subtitle: hint == null ? null : Text(hint),
          trailing: current == code
              ? AppIcon(AppSvg.check, size: 24.r, color: theme.textPrimary(context))
              : null,
          onTap: () => Navigator.of(context).pop((code: code)),
        );
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              option(
                null,
                LocaleKeys.voiceRequestAutoDetect.tr(),
                LocaleKeys.voiceRequestAutoDetectHint.tr(),
              ),
              for (final language in requestLanguages)
                option(
                  language.code,
                  locale == 'vi' ? language.nativeName : language.name,
                  locale == 'vi' ? null : language.nativeName,
                ),
            ],
          ),
        );
      },
    );
    if (picked != null) bloc.add(AccountSpeakingLanguageChanged(picked.code));
  }

  /// Bật dịch tự động = đồng ý gửi tin cho dịch vụ dịch AI (như khi bật trong chat).
  Future<void> _toggleAutoTranslate(BuildContext context, bool value) async {
    final bloc = context.read<AccountBloc>();
    if (value) {
      final locale = context.locale.languageCode;
      final agreed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(LocaleKeys.chatConsentTitle.tr()),
          content: Text(
            LocaleKeys.chatConsentMessage.tr(
              args: [ChatFormatters.languageName(locale, locale) ?? locale],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(LocaleKeys.chatCancel.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(LocaleKeys.chatConsentAgree.tr()),
            ),
          ],
        ),
      );
      if (agreed != true) return;
    }
    bloc.add(AccountToggleChanged(AccountToggle.autoTranslate, value));
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bloc = context.read<AccountBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.accountLogoutConfirm.tr()),
        content: Text(LocaleKeys.accountLogoutMessage.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(LocaleKeys.chatCancel.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colour.error),
            child: Text(LocaleKeys.accountLogout.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) bloc.add(const AccountLogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: _background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: theme.surface(context),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
                child: Text(
                  LocaleKeys.accountTitle.tr(),
                  style: AppTextStyle.lightHeadingMedium.copyWith(
                    color: theme.textPrimary(context),
                  ),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: theme.border(context)),
          Expanded(
            child: BlocConsumer<AccountBloc, AccountState>(
              listenWhen: (a, b) => a.noticeId != b.noticeId,
              listener: (context, state) {
                switch (state.notice) {
                  case AccountNotice.profileSaved:
                    ToastUtil.showSuccess(LocaleKeys.accountSaved.tr());
                  case AccountNotice.profileFailed:
                    ToastUtil.showError(LocaleKeys.accountSaveFailed.tr());
                  case AccountNotice.loggedOut:
                    ToastUtil.showInfo(LocaleKeys.accountLoggedOut.tr());
                    context.go(RouteName.rootScreen);
                  case null:
                    break;
                }
              },
              builder: (context, state) {
                final signedIn = state.status != AccountStatus.signedOut;
                final locale = context.locale.languageCode;
                final language = state.speakingLanguage == null
                    ? LocaleKeys.voiceRequestAutoDetect.tr()
                    : ChatFormatters.languageName(
                        state.speakingLanguage,
                        locale,
                      );
                return RefreshIndicator(
                  onRefresh: () async =>
                      context.read<AccountBloc>().add(const AccountStarted()),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
                    children: [
                      if (signedIn) ...[
                        _ProfileCard(
                          state: state,
                          onEdit: () => _editProfile(context, state),
                        ),
                        if (state.wallet != null) ...[
                          Gap(12.h),
                          _LionPointsCard(
                            points: state.wallet!.points,
                            worth: state.pointsWorth,
                            onHistory: () => context.push(RouteName.lionPoints),
                          ),
                        ],
                      ] else
                        _GuestCard(
                          onSignIn: () async {
                            final bloc = context.read<AccountBloc>();
                            if (await showAuthSheet(
                              context,
                              source: 'account',
                            )) {
                              bloc.add(const AccountStarted());
                            }
                          },
                        ),
                      AccountSectionTitle(LocaleKeys.accountVoiceSection.tr()),
                      AccountGroup(
                        children: [
                          AccountNavRow(
                            iconAsset: AppSvg.microphone,
                            label: LocaleKeys.accountSpeakingLanguage.tr(),
                            value: language,
                            onTap: () =>
                                _pickLanguage(context, state.speakingLanguage),
                          ),
                          AccountSwitchRow(
                            title: LocaleKeys.accountAutoTranslate.tr(),
                            subtitle: LocaleKeys.accountAutoTranslateHint.tr(),
                            value: state.autoTranslate,
                            onChanged: (v) => _toggleAutoTranslate(context, v),
                          ),
                          AccountSwitchRow(
                            title: LocaleKeys.accountReadAloud.tr(),
                            subtitle: LocaleKeys.accountReadAloudHint.tr(),
                            value: state.readAloud,
                            onChanged: (v) => context.read<AccountBloc>().add(
                              AccountToggleChanged(AccountToggle.readAloud, v),
                            ),
                          ),
                          AccountSwitchRow(
                            title: LocaleKeys.accountAttachVoice.tr(),
                            subtitle: LocaleKeys.accountAttachVoiceHint.tr(),
                            value: state.attachVoice,
                            onChanged: (v) => context.read<AccountBloc>().add(
                              AccountToggleChanged(
                                AccountToggle.attachVoice,
                                v,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AccountSectionTitle(LocaleKeys.accountOrdersSection.tr()),
                      AccountGroup(
                        children: [
                          AccountNavRow(
                            iconAsset: AppSvg.bag,
                            label: LocaleKeys.accountMyOrders.tr(),
                            // Như prototype: đơn đã đặt nằm ở My requests (tab Closed / Booked).
                            onTap: () => context.go(RouteName.myRequests),
                          ),
                          AccountNavRow(
                            icon: Icons.favorite_border_rounded,
                            label: LocaleKeys.accountSavedProviders.tr(),
                            // Prototype: mở danh sách provider (chưa có API "đã lưu").
                            onTap: () => context.push(
                              RouteName.matchingProviders,
                              extra: const MatchingProvidersPageArgs(
                                start: PostRequestFlowArgs(browseOnly: true),
                              ),
                            ),
                          ),
                          AccountNavRow(
                            iconAsset: AppSvg.starOutline,
                            label: LocaleKeys.accountMyReviews.tr(),
                            onTap: _comingSoon,
                          ),
                          AccountNavRow(
                            iconAsset: AppSvg.card,
                            label: LocaleKeys.accountPaymentMethods.tr(),
                            onTap: _comingSoon,
                          ),
                        ],
                      ),
                      AccountSectionTitle(
                        LocaleKeys.accountSupportSection.tr(),
                      ),
                      AccountGroup(
                        children: [
                          AccountNavRow(
                            iconAsset: AppSvg.notification,
                            label: LocaleKeys.accountNotifications.tr(),
                            onTap: _comingSoon,
                          ),
                          AccountNavRow(
                            iconAsset: AppSvg.help,
                            label: LocaleKeys.accountHelp.tr(),
                            onTap: _comingSoon,
                          ),
                        ],
                      ),
                      if (signedIn) ...[
                        Gap(18.h),
                        SizedBox(
                          height: 50.h,
                          child: OutlinedButton(
                            onPressed: state.loggingOut
                                ? null
                                : () => _confirmLogout(context),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: theme.surface(context),
                              foregroundColor: Colour.error,
                              side: BorderSide(color: theme.border(context)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              textStyle: AppTextStyle.lightBodyMediumSemiBold,
                            ),
                            child: state.loggingOut
                                ? const CupertinoActivityIndicator()
                                : Text(LocaleKeys.accountLogout.tr()),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, AccountState state) {
    final bloc = context.read<AccountBloc>();
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).surface(context),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _EditProfileSheet(state: state),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AccountState state;
  final VoidCallback onEdit;

  const _ProfileCard({required this.state, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.languageCode;
    final profile = state.profile;
    final languages = (profile?.languages ?? const [])
        .map((code) => ChatFormatters.languageName(code, locale))
        .whereType<String>()
        .join(', ');
    final details = [
      ?profile?.place,
      if (languages.isNotEmpty) languages,
    ].join(' · ');
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: theme.surface(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: theme.border(context)),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            name: state.displayName,
            imageUrl: profile?.avatarUrl,
            colorSeed: 5,
            size: 56.r,
          ),
          Gap(14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.displayName.isEmpty ? '—' : state.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.lightBodyXLargeBold.copyWith(
                    color: theme.textPrimary(context),
                  ),
                ),
                if (details.isNotEmpty || profile?.email != null) ...[
                  Gap(2.h),
                  Text(
                    details.isNotEmpty ? details : profile!.email!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.lightBodySmallRegular.copyWith(
                      height: 1.3,
                      color: theme.textSecondary(context),
                    ),
                  ),
                ] else if (state.status == AccountStatus.loading) ...[
                  Gap(6.h),
                  const CupertinoActivityIndicator(),
                ],
              ],
            ),
          ),
          Gap(10.w),
          SizedBox.square(
            dimension: 42.r,
            child: OutlinedButton(
              onPressed: profile == null ? null : onEdit,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: theme.textPrimary(context),
                side: BorderSide(color: theme.border(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Semantics(
                label: LocaleKeys.accountEdit.tr(),
                child: AppIcon(AppSvg.edit, size: 19.r),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LionPointsCard extends StatelessWidget {
  final int points;
  final double? worth;
  final VoidCallback onHistory;

  const _LionPointsCard({
    required this.points,
    required this.worth,
    required this.onHistory,
  });

  static const _background = Color(0xFFFCF3E3);
  static const _star = Color(0xFFC07A1E);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.toString();
    final count = NumberFormat.decimalPattern(locale).format(points);
    final money = worth == null
        ? null
        : NumberFormat.simpleCurrency(
            locale: 'en_US',
            name: 'USD',
          ).format(worth);
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 12.h),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          AppIcon(AppSvg.starFilled, size: 28.r, color: _star),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.accountLionPoints.tr(args: [count]),
                  style: AppTextStyle.lightBodyMediumBold.copyWith(
                    color: theme.textPrimary(context),
                  ),
                ),
                if (money != null)
                  Text(
                    LocaleKeys.accountLionWorth.tr(args: [money]),
                    style: AppTextStyle.lightBodySmallRegular.copyWith(
                      color: theme.textPrimary(context),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onHistory,
            style: TextButton.styleFrom(
              foregroundColor: theme.textPrimary(context),
              textStyle: AppTextStyle.lightBodyMediumSemiBold,
            ),
            child: Text(LocaleKeys.accountHistory.tr()),
          ),
        ],
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  final VoidCallback onSignIn;

  const _GuestCard({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: theme.surface(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: theme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LocaleKeys.accountGuestTitle.tr(),
            style: AppTextStyle.lightBodyXLargeBold.copyWith(
              color: theme.textPrimary(context),
            ),
          ),
          Gap(4.h),
          Text(
            LocaleKeys.accountGuestMessage.tr(),
            style: AppTextStyle.lightBodySmallRegular.copyWith(
              height: 1.4,
              color: theme.textSecondary(context),
            ),
          ),
          Gap(14.h),
          AuthPrimaryButton(
            label: LocaleKeys.authSignIn.tr(),
            onPressed: onSignIn,
          ),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final AccountState state;

  const _EditProfileSheet({required this.state});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _first = TextEditingController(
    text: widget.state.profile?.firstName,
  );
  late final _last = TextEditingController(
    text: widget.state.profile?.lastName,
  );
  late final _city = TextEditingController(text: widget.state.profile?.city);

  /// Tên trống → Account hiện "—" và Home vẫn chào tên cũ → bắt nhập.
  bool _firstMissing = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<AccountBloc, AccountState>(
      listenWhen: (a, b) =>
          a.noticeId != b.noticeId && b.notice == AccountNotice.profileSaved,
      listener: (context, _) => Navigator.of(context).pop(),
      builder: (context, state) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                LocaleKeys.accountEdit.tr(),
                style: AppTextStyle.lightHeadingSmall.copyWith(
                  color: theme.textPrimary(context),
                ),
              ),
              Gap(16.h),
              AuthTextField(
                label: LocaleKeys.accountFirstName.tr(),
                controller: _first,
                error: _firstMissing
                    ? const AuthMessage.key(LocaleKeys.accountFirstNameRequired)
                    : null,
                autofillHints: const [AutofillHints.givenName],
              ),
              Gap(12.h),
              AuthTextField(
                label: LocaleKeys.accountLastName.tr(),
                controller: _last,
                autofillHints: const [AutofillHints.familyName],
              ),
              Gap(12.h),
              AuthTextField(
                label: LocaleKeys.accountCity.tr(),
                controller: _city,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.addressCity],
              ),
              Gap(20.h),
              AuthPrimaryButton(
                label: LocaleKeys.accountSave.tr(),
                loading: state.savingProfile,
                onPressed: () {
                  if (_first.text.trim().isEmpty) {
                    setState(() => _firstMissing = true);
                    return;
                  }
                  context.read<AccountBloc>().add(
                    AccountProfileSaved(
                      firstName: _first.text.trim(),
                      lastName: _last.text.trim(),
                      city: _city.text.trim(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
