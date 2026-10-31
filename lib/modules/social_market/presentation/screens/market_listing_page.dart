import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';

import '../../domain/entities/market_category.dart';
import '../../domain/entities/market_listing_entities.dart';
import '../bloc/engagement/engagement_cubit.dart';
import '../bloc/market_listing/market_listing_bloc.dart';
import '../market_formatters.dart';
import '../market_navigation.dart';
import '../widgets/market_expert_card.dart';
import '../widgets/market_service_card.dart';
import '../widgets/market_ui.dart';

/// "View selling list" → service của category, mới nhất trước (web `/services/{category}`).
class MarketServicesListingPage extends StatelessWidget {
  final MarketCategory category;

  const MarketServicesListingPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) => _MarketListingView<MarketServiceEntity>(
    title: LocaleKeys.marketListingServicesTitle.tr(
      namedArgs: {'category': MarketFormatters.categoryLabel(category)},
    ),
    description: LocaleKeys.marketListingServicesDesc.tr(),
    idOf: (s) => s.id,
    itemBuilder: (context, s) => MarketServiceCard(
      service: s,
      onInquiry: () => MarketNavigation.inquireService(context, s),
      onViewAndBook: () => MarketNavigation.viewAndBook(context, s),
      onTap: () => MarketNavigation.openService(context, s),
    ),
  );
}

/// "View profile list" → provider của category, xếp score_rank (web `/providers/{category}`).
class MarketProvidersListingPage extends StatelessWidget {
  final MarketCategory category;

  const MarketProvidersListingPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) => _MarketListingView<MarketExpertEntity>(
    title: LocaleKeys.marketListingProvidersTitle.tr(
      namedArgs: {'category': MarketFormatters.categoryLabel(category)},
    ),
    description: LocaleKeys.marketListingProvidersDesc.tr(),
    idOf: (e) => e.id,
    itemBuilder: (context, e) => MarketExpertCard(expert: e),
  );
}

class _MarketListingView<T> extends StatefulWidget {
  final String title;
  final String description;
  final int? Function(T item) idOf;
  final Widget Function(BuildContext context, T item) itemBuilder;

  const _MarketListingView({
    super.key,
    required this.title,
    required this.description,
    required this.idOf,
    required this.itemBuilder,
  });

  @override
  State<_MarketListingView<T>> createState() => _MarketListingViewState<T>();
}

class _MarketListingViewState<T> extends State<_MarketListingView<T>> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Gần cuối (sớm 600px như web `rootMargin`) → tải trang kế.
  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels < 600.h) {
      context.read<MarketListingBloc<T>>().add(
        const MarketListingNextPageRequested(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MarketListingBloc<T>>();
    final metaStyle = AppTextStyle.lightBodyLargeRegular.copyWith(
      color: Colour.textSecondary,
    );
    return MultiBlocListener(
      listeners: [
        BlocListener<MarketListingBloc<T>, MarketListingState<T>>(
          listener: (context, state) {
            context.read<EngagementCubit>().load(state.items.map(widget.idOf));
            // Trang đầu chưa đầy màn hình → tải tiếp.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => mounted ? _maybeLoadMore() : null,
            );
          },
        ),
        BlocListener<EngagementCubit, EngagementCubitState>(
          listenWhen: (a, b) => a.errorCount != b.errorCount,
          listener: (context, _) =>
              ToastUtil.showError(LocaleKeys.marketGenericError.tr()),
        ),
      ],
      child: Scaffold(
        backgroundColor: Colour.background,
        appBar: AppBar(
          backgroundColor: Colour.surface,
          surfaceTintColor: Colors.transparent,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Colour.border),
          ),
        ),
        body: BlocBuilder<MarketListingBloc<T>, MarketListingState<T>>(
          builder: (context, state) {
            final header = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: AppTextStyle.lightHeadingMedium.copyWith(
                    color: Colour.textPrimary,
                  ),
                ),
                Gap(8.h),
                Text(widget.description, style: metaStyle),
                Gap(24.h),
              ],
            );
            final List<Widget> body;
            if (state.isFirstLoad) {
              body = [
                for (var i = 0; i < 3; i++) ...[
                  const MarketCardSkeleton(),
                  Gap(16.h),
                ],
              ];
            } else if (state.status == ListingStatus.failure) {
              body = [
                _Notice(
                  icon: Icons.cloud_off_outlined,
                  title: LocaleKeys.marketListingFetchError.tr(),
                  hint: LocaleKeys.marketListingEmptyHint.tr(),
                  onRetry: () => bloc.add(const MarketListingStarted()),
                ),
              ];
            } else if (state.items.isEmpty) {
              body = [
                _Notice(
                  icon: Icons.search_off_outlined,
                  title: LocaleKeys.marketListingEmpty.tr(),
                  hint: LocaleKeys.marketListingEmptyHint.tr(),
                ),
              ];
            } else {
              body = [
                for (final item in state.items) ...[
                  widget.itemBuilder(context, item),
                  Gap(16.h),
                ],
                if (state.loadingMore) ...[
                  const MarketCardSkeleton(),
                  Gap(16.h),
                ],
                if (state.loadMoreError)
                  Column(
                    children: [
                      Text(
                        LocaleKeys.marketListingLoadMoreError.tr(),
                        textAlign: TextAlign.center,
                        style: metaStyle,
                      ),
                      Gap(8.h),
                      OutlinedButton(
                        onPressed: () => bloc.add(
                          const MarketListingNextPageRequested(retry: true),
                        ),
                        child: Text(LocaleKeys.marketListingRetry.tr()),
                      ),
                    ],
                  ),
              ];
            }
            return RefreshIndicator(
              onRefresh: () async {
                bloc.add(const MarketListingRefreshed());
                await bloc.stream.first;
              },
              child: ListView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  24.h,
                  16.w,
                  24.h + MediaQuery.paddingOf(context).bottom,
                ),
                children: [header, ...body],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Khối "Nothing here yet" / "We couldn't load this list." (web `ListingNotice`).
class _Notice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback? onRetry;

  const _Notice({
    required this.icon,
    required this.title,
    required this.hint,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 48.h),
      child: Column(
        children: [
          Icon(icon, size: 36.r, color: Colour.textTertiary),
          Gap(12.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
              color: Colour.textPrimary,
            ),
          ),
          Gap(4.h),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: AppTextStyle.lightBodyMediumRegular.copyWith(
              color: Colour.textSecondary,
            ),
          ),
          if (onRetry != null) ...[
            Gap(16.h),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(LocaleKeys.marketListingRetry.tr()),
            ),
          ],
        ],
      ),
    );
  }
}
