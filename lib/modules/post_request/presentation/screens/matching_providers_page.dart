import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/domain/global_dependencies.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';

import 'package:strongbody_buyer/modules/auth/presentation/widgets/auth_sheet.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_page_args.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../domain/entities/provider_entity.dart';
import '../../domain/entities/provider_refine_query.dart';
import '../bloc/matching_providers/matching_providers_bloc.dart';
import '../post_request_flow_args.dart';
import '../widgets/voice/get_help_sheet.dart';
import '../matching_providers_page_args.dart';
import '../voice_request_page_args.dart';
import '../widgets/providers/provider_card.dart';
import '../widgets/providers/provider_formatters.dart';

/// "Matching providers": duyệt provider theo nghề. Request offer → form "Post a request"
/// gửi riêng cho người đó (`/buyer/request/to-seller`); Post request → nút "Get help".
class MatchingProvidersPage extends StatefulWidget {
  final MatchingProvidersPageArgs args;

  const MatchingProvidersPage({super.key, required this.args});

  @override
  State<MatchingProvidersPage> createState() => _MatchingProvidersPageState();
}

class _MatchingProvidersPageState extends State<MatchingProvidersPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 400) {
        context.read<MatchingProvidersBloc>().add(
          const MatchingProvidersLoadMore(),
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refineByVoice() async {
    final bloc = context.read<MatchingProvidersBloc>();
    final text = await context.push<String>(
      RouteName.voiceRequest,
      extra: const VoiceRequestPageArgs(
        refine: true,
        source: 'providers_refine',
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    if (ProviderRefineQuery.parse(text).isEmpty) {
      ToastUtil.showInfo(LocaleKeys.providersRefineNothing.tr());
      return;
    }
    bloc.add(MatchingProvidersRefined(text));
  }

  /// Như web AuthGate: chat cần tài khoản → popup Sign in trước, rồi mở chat với provider.
  Future<void> _voiceMessage(ProviderEntity provider) async {
    AppAnalytics.capture(AnalyticsEvents.providerMessageTapped, {
      'provider_id': provider.userId,
    });
    if (!gs.isLoggedIn && !await showAuthSheet(context, source: 'providers')) {
      return;
    }
    if (!mounted) return;
    context.push(
      RouteName.chat,
      extra: ChatPageArgs(
        partnerId: provider.userId,
        name: ProviderFormatters.name(provider),
        avatar: provider.avatarUrl,
        profession: provider.profession,
        source: 'providers',
      ),
    );
  }

  void _requestOffer(ProviderEntity provider) {
    AppAnalytics.capture(AnalyticsEvents.providerRequestOfferTapped, {
      'provider_id': provider.userId,
    });
    context.push(
      RouteName.postRequest,
      extra: PostRequestFlowArgs(
        sellerUserIds: [provider.userId],
        sellerName: ProviderFormatters.name(provider),
      ),
    );
  }

  /// "Not sure who to pick? · Post request" → nói / gõ yêu cầu (như nút "Get help").
  void _postToAll() {
    AppAnalytics.capture(AnalyticsEvents.providersPostToAllTapped, {
      'match_count': context.read<MatchingProvidersBloc>().state.matchCount,
    });
    showGetHelpSheet(context, source: 'providers');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _SearchHeader(
              onBack: () => context.pop(),
              onMic: () => showGetHelpSheet(context, source: 'providers'),
            ),
            const _FilterChips(),
            Divider(height: 1, color: theme.border(context)),
            Expanded(
              child: BlocBuilder<MatchingProvidersBloc, MatchingProvidersState>(
                builder: (context, state) => _buildList(context, state),
              ),
            ),
            _buildPostBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, MatchingProvidersState state) {
    final theme = Theme.of(context);
    final items = state.visibleItems;
    final header = <Widget>[
      _RefineHint(onTap: _refineByVoice),
      Gap(12.h),
      if (!state.isFirstLoad)
        Text(
          state.matchCount == 1
              ? LocaleKeys.providersMatchOne.tr()
              : LocaleKeys.providersMatchMany.tr(args: ['${state.matchCount}']),
          style: AppTextStyle.lightBodySmallRegular.copyWith(
            color: theme.textSecondary(context),
          ),
        ),
    ];
    final message = state.isFirstLoad
        ? null
        : state.status == MatchingProvidersStatus.failure
        ? LocaleKeys.providersLoadError.tr()
        : items.isEmpty
        ? LocaleKeys.providersEmpty.tr()
        : null;

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      children: [
        ...header,
        if (state.isFirstLoad)
          Padding(
            padding: EdgeInsets.only(top: 40.h),
            child: const Center(child: CupertinoActivityIndicator()),
          )
        else if (items.isEmpty &&
            state.items.isNotEmpty &&
            state.activeFilters.isNotEmpty)
          // Như prototype: lọc hết người → gợi ý bỏ lọc / đăng request.
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 0),
            child: Column(
              children: [
                Text(
                  LocaleKeys.providersNoMatchTitle.tr(),
                  textAlign: TextAlign.center,
                  style: AppTextStyle.lightBodyLargeBold.copyWith(
                    color: theme.textPrimary(context),
                  ),
                ),
                Gap(6.h),
                Text(
                  LocaleKeys.providersNoMatchMessage.tr(),
                  textAlign: TextAlign.center,
                  style: AppTextStyle.lightBodySmallRegular.copyWith(
                    height: 1.4,
                    color: theme.textSecondary(context),
                  ),
                ),
                Gap(14.h),
                OutlinedButton(
                  onPressed: () => context.read<MatchingProvidersBloc>().add(
                    const MatchingProvidersFiltersCleared(),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.textPrimary(context),
                    side: BorderSide(color: theme.border(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(LocaleKeys.providersClearFilters.tr()),
                ),
              ],
            ),
          )
        else if (message != null)
          Padding(
            padding: EdgeInsets.all(32.r),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyle.lightBodyMediumRegular.copyWith(
                color: theme.textSecondary(context),
              ),
            ),
          )
        else
          for (final provider in items) ...[
            Gap(10.h),
            ProviderCard(
              provider: provider,
              extras: state.extras[provider.id],
              onToggleSelect: () => context.read<MatchingProvidersBloc>().add(
                MatchingProvidersToggled(provider),
              ),
              onVoiceMessage: () => _voiceMessage(provider),
              onRequestOffer: () => _requestOffer(provider),
            ),
          ],
        if (state.isLoadingMore)
          Padding(
            padding: EdgeInsets.only(top: 16.h),
            child: const Center(child: CupertinoActivityIndicator()),
          ),
      ],
    );
  }

  Widget _buildPostBar(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface(context),
        border: Border(top: BorderSide(color: theme.border(context))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.providersNotSure.tr(),
                      style: AppTextStyle.lightBodyMediumBold.copyWith(
                        color: theme.textPrimary(context),
                      ),
                    ),
                    Text(
                      LocaleKeys.providersNotSureHint.tr(),
                      style: AppTextStyle.lightBodySmallRegular.copyWith(
                        color: theme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Gap(12.w),
              OutlinedButton(
                onPressed: _postToAll,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textPrimary(context),
                  side: BorderSide(color: theme.textPrimary(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  textStyle: AppTextStyle.lightBodyMediumSemiBold,
                ),
                child: Text(LocaleKeys.providersPostRequest.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "← [🔍 Physiotherapist · At home · …] (🎤)". Chạm ô để sửa từ khoá nghề.
class _SearchHeader extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onMic;

  const _SearchHeader({required this.onBack, required this.onMic});

  @override
  State<_SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<_SearchHeader> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) setState(() => _editing = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing(String keyword) {
    _controller.text = keyword;
    _controller.selection = TextSelection.collapsed(offset: keyword.length);
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: theme.textPrimary(context),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 8.h, 12.w, 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            icon: AppIcon(
              AppSvg.arrowBack,
              size: 24.r,
              color: theme.textPrimary(context),
            ),
          ),
          Expanded(
            child: Container(
              height: 48.h,
              padding: EdgeInsets.only(left: 12.w, right: 4.w),
              decoration: BoxDecoration(
                color: theme.muted(context),
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Row(
                children: [
                  AppIcon(
                    AppSvg.search,
                    size: 20.r,
                    color: theme.textSecondary(context),
                  ),
                  Gap(8.w),
                  Expanded(
                    child:
                        BlocBuilder<
                          MatchingProvidersBloc,
                          MatchingProvidersState
                        >(
                          buildWhen: (previous, current) =>
                              previous.keyword != current.keyword ||
                              previous.context != current.context,
                          builder: (context, state) {
                            if (_editing) {
                              return TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                style: textStyle,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText: LocaleKeys.providersSearchHint.tr(),
                                  hintStyle: AppTextStyle.lightBodyMediumRegular
                                      .copyWith(
                                        color: theme.textTertiary(context),
                                      ),
                                ),
                                onSubmitted: (text) {
                                  _focusNode.unfocus();
                                  context.read<MatchingProvidersBloc>().add(
                                    MatchingProvidersKeywordSubmitted(text),
                                  );
                                },
                              );
                            }
                            final label = [
                              _capitalize(state.keyword),
                              state.context.summary,
                            ].where((s) => s.isNotEmpty).join(' · ');
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _startEditing(state.keyword),
                              child: Text(
                                label.isEmpty
                                    ? LocaleKeys.providersSearchHint.tr()
                                    : label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: label.isEmpty
                                    ? textStyle.copyWith(
                                        color: theme.textTertiary(context),
                                      )
                                    : textStyle,
                              ),
                            );
                          },
                        ),
                  ),
                  Material(
                    color: Colour.buttonPrimary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: widget.onMic,
                      customBorder: const CircleBorder(),
                      child: SizedBox.square(
                        dimension: 40.r,
                        child: Center(
                          child: AppIcon(
                            AppSvg.microphone,
                            size: 20.r,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}

/// Chip lọc cuộn ngang ("✓ At home", "✓ This weekend", "Under $70"…).
class _FilterChips extends StatefulWidget {
  const _FilterChips();

  @override
  State<_FilterChips> createState() => _FilterChipsState();
}

class _FilterChipsState extends State<_FilterChips> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.languageCode;
    return BlocBuilder<MatchingProvidersBloc, MatchingProvidersState>(
      buildWhen: (previous, current) =>
          previous.context != current.context ||
          previous.activeFilters != current.activeFilters,
      builder: (context, state) {
        final filters = state.context.availableFilters;
        return SizedBox(
          height: 56.h,
          child: RawScrollbar(
            controller: _controller,
            thumbVisibility: true,
            thickness: 4.h,
            radius: Radius.circular(4.r),
            thumbColor: theme.textTertiary(context).withValues(alpha: 0.6),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 12.h),
              itemCount: filters.length,
              separatorBuilder: (_, _) => Gap(8.w),
              itemBuilder: (context, index) {
                final filter = filters[index];
                final active = state.activeFilters.contains(filter);
                return Material(
                  color: active ? theme.muted(context) : theme.surface(context),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: active
                          ? theme.secondary(context)
                          : theme.border(context),
                      width: active ? 1.4 : 1,
                    ),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => context.read<MatchingProvidersBloc>().add(
                      MatchingProvidersFilterToggled(filter),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14.w),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (active) ...[
                            AppIcon(
                              AppSvg.check,
                              size: 16.r,
                              color: theme.textPrimary(context),
                            ),
                            Gap(4.w),
                          ],
                          Text(
                            ProviderFormatters.chip(
                              filter,
                              state.context,
                              locale,
                            ),
                            style: AppTextStyle.lightBodyMediumMedium.copyWith(
                              color: theme.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// "🎤 Refine by voice: …" — chạm để nói cách lọc.
class _RefineHint extends StatelessWidget {
  final VoidCallback onTap;

  const _RefineHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.muted(context),
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(12.r),
          child: Row(
            children: [
              AppIcon(
                AppSvg.microphone,
                size: 20.r,
                color: theme.textSecondary(context),
              ),
              Gap(10.w),
              Expanded(
                child: Text(
                  LocaleKeys.providersRefineHint.tr(),
                  style: AppTextStyle.lightBodySmallRegular.copyWith(
                    height: 1.35,
                    color: theme.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
