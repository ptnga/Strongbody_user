import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';

import '../../domain/entities/market_category.dart';
import '../../domain/entities/market_feed_entities.dart';
import '../../domain/entities/market_listing_entities.dart';
import '../bloc/category_market/category_market_bloc.dart';
import '../bloc/engagement/engagement_cubit.dart';
import '../market_formatters.dart';
import '../market_navigation.dart';
import '../widgets/market_expert_card.dart';
import '../widgets/market_hero.dart';
import '../widgets/market_offer_card.dart';
import '../widgets/market_request_card.dart';
import '../widgets/market_service_card.dart';
import '../widgets/market_solution_card.dart';
import '../widgets/market_ui.dart';

/// Trang Social Market của một category (web `/longevity`, `/health-pro-advisory`,
/// `/personal-helper` = `MarketplacePage` lọc category): Hero chiếm trọn màn hình
/// với ô nhập yêu cầu, cuộn xuống là Selling · Profiles · Offers · Requests · Solutions.
class CategoryMarketPage extends StatelessWidget {
  final MarketCategory category;

  const CategoryMarketPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CategoryMarketBloc>();
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        // Cùng bố cục màn Home: nền trắng, thanh trên không kẻ, ô nhập ghim đáy.
        backgroundColor: Colour.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              MarketTopBar(title: MarketFormatters.brand(category)),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    bloc.add(const CategoryMarketRefreshed());
                    await bloc.stream.firstWhere(
                      (s) => MarketSectionKind.values.every(
                        (k) => !s.isLoading(k),
                      ),
                    );
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) => CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _Hero(
                            category: category,
                            height: constraints.maxHeight,
                          ),
                        ),
                        _ServicesSection(category: category),
                        _SellersSection(category: category),
                        const _OffersSection(),
                        const _RequestsSection(),
                        const _SolutionsSection(),
                        SliverGap(24.h + MediaQuery.paddingOf(context).bottom),
                      ],
                    ),
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

/// Hero = màn đầu tiên, bố cục như Home: tagline + câu hỏi căn giữa khoảng trống,
/// ô nhập ghim ở đáy; cuộn xuống mới thấy các mục.
class _Hero extends StatelessWidget {
  final MarketCategory category;
  final double height;

  const _Hero({required this.category, required this.height});

  @override
  Widget build(BuildContext context) {
    final hero = MarketFormatters.hero(category);
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: MarketAskHeading(
                tagline: hero.tagline,
                title: hero.title,
                subtitle: hero.subtitle,
              ),
            ),
          ),
          const MarketHeroComposer(),
          // SafeArea không bọc đáy (các mục cuộn tràn xuống) → tự chừa home indicator.
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

/// Khung một mục: padding web `py-10` + tiêu đề; tải → skeleton, lỗi → khối thử lại,
/// rỗng → ẩn mục (trừ khi [showWhenEmpty]).
class _Section<T> extends StatelessWidget {
  final MarketSectionKind kind;
  final String title;
  final String? description;
  final VoidCallback? onViewAll;
  final String? viewAllLabel;
  final List<T> Function(CategoryMarketState state) select;
  final Widget Function(BuildContext context, List<T> items) builder;
  final bool showWhenEmpty;
  final int skeletons;

  const _Section({
    required this.kind,
    required this.title,
    required this.select,
    required this.builder,
    this.description,
    this.onViewAll,
    this.viewAllLabel,
    this.showWhenEmpty = false,
    this.skeletons = 2,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoryMarketBloc, CategoryMarketState>(
      buildWhen: (a, b) =>
          a.status(kind) != b.status(kind) || select(a) != select(b),
      builder: (context, state) {
        final items = select(state);
        final status = state.status(kind);
        Widget? body;
        if (status == SectionStatus.failure && items.isEmpty) {
          body = MarketSectionError(
            title: title,
            onRetry: () => context.read<CategoryMarketBloc>().add(
              CategoryMarketSectionRetried(kind),
            ),
          );
        } else if (state.isLoading(kind) && items.isEmpty) {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarketSectionHeading(title: title, description: description),
              for (var i = 0; i < skeletons; i++) ...[
                Gap(16.h),
                const MarketCardSkeleton(),
              ],
            ],
          );
        } else if (items.isNotEmpty || showWhenEmpty) {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarketSectionHeading(
                title: title,
                description: description,
                onViewAll: onViewAll,
                viewAllLabel: viewAllLabel,
              ),
              Gap(24.h),
              builder(context, items),
            ],
          );
        }
        return SliverToBoxAdapter(
          child: body == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 40.h,
                  ),
                  child: body,
                ),
        );
      },
    );
  }
}

/// Bọc một mục bằng [EngagementCubit] của loại target đó; nạp số đếm khi có dữ liệu.
class _EngagementScope extends StatelessWidget {
  final EngagementTarget target;
  final Iterable<int?> Function(CategoryMarketState state) ids;
  final Widget child;

  const _EngagementScope({
    required this.target,
    required this.ids,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          getIt<EngagementCubit>(param1: target)
            ..load(ids(context.read<CategoryMarketBloc>().state)),
      child: Builder(
        builder: (context) =>
            BlocListener<CategoryMarketBloc, CategoryMarketState>(
              listener: (context, state) =>
                  context.read<EngagementCubit>().load(ids(state)),
              child: BlocListener<EngagementCubit, EngagementCubitState>(
                listenWhen: (a, b) => a.errorCount != b.errorCount,
                listener: (context, _) =>
                    ToastUtil.showError(LocaleKeys.marketGenericError.tr()),
                child: child,
              ),
            ),
      ),
    );
  }
}

Widget _list(List<Widget> children) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final (i, child) in children.indexed) ...[if (i > 0) Gap(16.h), child],
  ],
);

class _ServicesSection extends StatelessWidget {
  final MarketCategory category;

  const _ServicesSection({required this.category});

  @override
  Widget build(BuildContext context) => _EngagementScope(
    target: EngagementTarget.service,
    ids: (s) => s.services.map((e) => e.id),
    child: _Section<MarketServiceEntity>(
      kind: MarketSectionKind.services,
      title: LocaleKeys.marketServicesTitle.tr(),
      description: LocaleKeys.marketServicesDesc.tr(),
      viewAllLabel: LocaleKeys.marketServicesViewAll.tr(),
      onViewAll: () => context.push(MarketRoutes.services(category)),
      select: (s) => s.services,
      builder: (context, items) => _list([
        for (final s in items)
          MarketServiceCard(
            service: s,
            onInquiry: () => MarketNavigation.inquireService(context, s),
            onViewAndBook: () => MarketNavigation.viewAndBook(context, s),
            onTap: () => MarketNavigation.openService(context, s),
          ),
      ]),
    ),
  );
}

class _SellersSection extends StatelessWidget {
  final MarketCategory category;

  const _SellersSection({required this.category});

  @override
  Widget build(BuildContext context) => _EngagementScope(
    target: EngagementTarget.sellerProfile,
    ids: (s) => s.sellers.map((e) => e.id),
    child: _Section<MarketExpertEntity>(
      kind: MarketSectionKind.sellers,
      title: LocaleKeys.marketSellersTitle.tr(),
      description: LocaleKeys.marketSellersDesc.tr(),
      viewAllLabel: LocaleKeys.marketSellersViewAll.tr(),
      onViewAll: () => context.push(MarketRoutes.providers(category)),
      select: (s) => s.sellers,
      builder: (context, items) =>
          _list([for (final e in items) MarketExpertCard(expert: e)]),
    ),
  );
}

class _OffersSection extends StatelessWidget {
  const _OffersSection();

  @override
  Widget build(BuildContext context) => _EngagementScope(
    target: EngagementTarget.offer,
    ids: (s) => s.offers.map((e) => e.id),
    child: _Section<MarketOfferEntity>(
      kind: MarketSectionKind.offers,
      title: LocaleKeys.marketOffersTitle.tr(),
      description: LocaleKeys.marketOffersDesc.tr(),
      // Mục này luôn hiện (web: rỗng → "No offers yet").
      showWhenEmpty: true,
      select: (s) => s.offers,
      builder: (context, items) => items.isEmpty
          ? Text(
              LocaleKeys.marketOffersEmpty.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyle.lightBodyMediumRegular.copyWith(
                color: Colour.textSecondary,
              ),
            )
          : _list([
              for (final (i, o) in items.indexed)
                MarketOfferCard(
                  offer: o,
                  index: i,
                  onWantThis: () => MarketNavigation.inquireOffer(context, o),
                ),
            ]),
    ),
  );
}

class _RequestsSection extends StatelessWidget {
  const _RequestsSection();

  @override
  Widget build(BuildContext context) => _Section<MarketRequestEntity>(
    kind: MarketSectionKind.requests,
    title: LocaleKeys.marketRequestsTitle.tr(),
    description: LocaleKeys.marketRequestsDesc.tr(),
    showWhenEmpty: true,
    skeletons: 3,
    select: (s) => s.requests,
    builder: (context, items) => _list([
      for (final r in items)
        MarketRequestCard(
          request: r,
          // "I have similar request": soạn request mới từ nội dung đó.
          onSimilar: (text) => openMarketRequest(context, text, const []),
        ),
      // Khối cuối mục: cùng nội dung với Hero (web `ShareRequest`).
      Container(
        margin: EdgeInsets.only(top: 24.h),
        padding: EdgeInsets.only(top: 32.h, bottom: 4.h),
        decoration: BoxDecoration(
          color: Colour.subtle,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          children: [
            MarketAskHeading(
              tagline: LocaleKeys.marketHeroTagline.tr(),
              title: LocaleKeys.marketHeroTitle.tr(),
            ),
            Gap(16.h),
            const MarketHeroComposer(background: Colour.surface),
          ],
        ),
      ),
    ]),
  );
}

class _SolutionsSection extends StatelessWidget {
  const _SolutionsSection();

  /// Gom theo category (1 solution có thể ở nhiều nhóm); chưa gán → "Other".
  /// Không solution nào có category → trả rỗng để hiện danh sách phẳng (web `groupByCategory`).
  static List<({String name, List<HealthSolutionEntity> items})> _group(
    List<HealthSolutionEntity> items,
  ) {
    final byId = <int, ({String name, List<HealthSolutionEntity> items})>{};
    final other = <HealthSolutionEntity>[];
    for (final s in items) {
      if (s.categories.isEmpty) {
        other.add(s);
        continue;
      }
      for (final c in s.categories) {
        byId.putIfAbsent(c.id, () => (name: c.name, items: [])).items.add(s);
      }
    }
    if (byId.isEmpty) return const [];
    final groups = byId.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return [
      ...groups,
      if (other.isNotEmpty)
        (name: LocaleKeys.marketSolutionsOther.tr(), items: other),
    ];
  }

  @override
  Widget build(BuildContext context) => _Section<HealthSolutionEntity>(
    kind: MarketSectionKind.solutions,
    title: LocaleKeys.marketSolutionsTitle.tr(),
    description:
        '${LocaleKeys.marketSolutionsDesc.tr()} ${LocaleKeys.marketSolutionsDisclaimer.tr()}',
    select: (s) => s.solutions,
    builder: (context, items) {
      Widget card(HealthSolutionEntity s) => MarketSolutionCard(
        solution: s,
        onWant: (s) => MarketNavigation.wantSolution(context, s),
      );
      final groups = _group(items);
      if (groups.isEmpty) return _list([for (final s in items) card(s)]);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, g) in groups.indexed) ...[
            if (i > 0) Gap(32.h),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colour.primary),
                ),
                child: Text(
                  g.name.trim().toUpperCase(),
                  style: AppTextStyle.lightBodySmallMedium.copyWith(
                    color: Colour.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Gap(12.h),
            _list([for (final s in g.items) card(s)]),
          ],
        ],
      );
    },
  );
}
