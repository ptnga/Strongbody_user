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
import '../../domain/entities/medical_travel_entities.dart';
import '../bloc/category_market/category_market_bloc.dart';
import '../bloc/engagement/engagement_cubit.dart';
import '../market_formatters.dart';
import '../market_navigation.dart';
import '../widgets/market_expert_card.dart';
import '../widgets/market_hero.dart';
import '../widgets/market_service_card.dart';
import '../widgets/market_ui.dart';
import '../widgets/medical_travel_widgets.dart';

/// Trang nhãn "Browse by need" (web `CategoryPage` nhánh `need` — `/longevity`,
/// `/mental`, `/personal-helper`, `/medical-travel`): hero 2 dòng truyền cảm hứng →
/// [Medical Travel: Destinations] → mỗi category doanh nghiệp một section service (tiêu
/// đề = tên category, "View all" mở listing đã chọn category) → Experts. Mục rỗng thì ẩn.
class CategoryMarketPage extends StatelessWidget {
  final MarketPageScope scope;

  const CategoryMarketPage({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CategoryMarketBloc>();
    return Scaffold(
      backgroundColor: Colour.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            MarketTopBar(title: MarketFormatters.scopeBrand(scope)),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  bloc.add(const CategoryMarketRefreshed());
                  await bloc.stream.firstWhere(
                    (s) => s.sections.every((k) => !s.isLoading(k)),
                  );
                },
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _Hero(scope: scope)),
                    if (scope.isMedicalTravel) const _DestinationsSection(),
                    _NeedServicesSections(scope: scope),
                    _ExpertsSection(scope: scope),
                    SliverGap(24.h + MediaQuery.paddingOf(context).bottom),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hero ngắn căn giữa: 2 dòng truyền cảm hứng riêng cho từng category (web `CategoryHero`).
class _Hero extends StatelessWidget {
  final MarketPageScope scope;

  const _Hero({required this.scope});

  @override
  Widget build(BuildContext context) {
    final hero = MarketFormatters.categoryHero(scope);
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 32.h, 16.w, 16.h),
      child: Column(
        children: [
          Text(
            hero.title,
            textAlign: TextAlign.center,
            style: AppTextStyle.lightHeadingMedium.copyWith(
              color: Colour.textPrimary,
            ),
          ),
          Gap(8.h),
          Text(
            hero.subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyle.lightBodyLargeRegular.copyWith(
              color: Colour.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung một mục (web `SectionShell` + `CATEGORY_SECTION` `py-5`): tải → skeleton,
/// lỗi → khối thử lại (chỉ khi [showError], còn lại ẩn), rỗng → ẩn.
class _Section<T> extends StatelessWidget {
  final MarketSectionKind kind;
  final String title;
  final String? viewAllLabel;
  final void Function(BuildContext context)? onViewAll;
  final List<T> Function(CategoryMarketState state) select;
  final Widget Function(BuildContext context, List<T> items) builder;
  final bool showError;

  const _Section({
    required this.kind,
    required this.title,
    required this.select,
    required this.builder,
    this.viewAllLabel,
    this.onViewAll,
    this.showError = false,
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
          if (showError) {
            body = MarketSectionError(
              title: title,
              onRetry: () => context.read<CategoryMarketBloc>().add(
                CategoryMarketSectionRetried(kind),
              ),
            );
          }
        } else if (state.isLoading(kind) && items.isEmpty) {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MarketSectionHeading(title: title, compact: true),
              for (var i = 0; i < 2; i++) ...[
                Gap(i == 0 ? 20.h : 8.h),
                const MarketCardSkeleton(height: 280),
              ],
            ],
          );
        } else if (items.isNotEmpty) {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MarketSectionHeading(
                title: title,
                compact: true,
                viewAllLabel: viewAllLabel,
                onViewAll: onViewAll == null ? null : () => onViewAll!(context),
              ),
              Gap(20.h),
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
                    vertical: 20.h,
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

/// Lưới 1 cột trên mobile, khoảng cách 8 (web `categoryRail` `gap-2`).
Widget _grid(List<Widget> children) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final (i, child) in children.indexed) ...[if (i > 0) Gap(8.h), child],
  ],
);

/// Section theo category doanh nghiệp (web `NeedSectionsLoader` +
/// `CategoryNeedServicesSection`): tiêu đề là tên category (không hiện số lượng), lưới
/// như Services; tải → 3 khung chờ, lỗi → khối thử lại, category rỗng → ẩn.
class _NeedServicesSections extends StatelessWidget {
  final MarketPageScope scope;

  const _NeedServicesSections({required this.scope});

  @override
  Widget build(BuildContext context) => _EngagementScope(
    target: EngagementTarget.service,
    ids: (s) => s.serviceIds,
    child: BlocBuilder<CategoryMarketBloc, CategoryMarketState>(
      buildWhen: (a, b) =>
          a.status(MarketSectionKind.services) !=
              b.status(MarketSectionKind.services) ||
          a.categorySections != b.categorySections,
      builder: (context, state) {
        const kind = MarketSectionKind.services;
        final sections = state.categorySections;
        final List<Widget> children;
        if (state.status(kind) == SectionStatus.failure && sections.isEmpty) {
          children = [
            MarketSectionError(
              title: LocaleKeys.marketCategoryServicesTitle.tr(),
              onRetry: () => context.read<CategoryMarketBloc>().add(
                const CategoryMarketSectionRetried(kind),
              ),
            ),
          ];
        } else if (state.isLoading(kind) && sections.isEmpty) {
          children = [
            for (var i = 0; i < 3; i++)
              _sectionSkeleton(CategoryMarketBloc.servicesShown),
          ];
        } else {
          children = [
            for (final section in sections)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MarketSectionHeading(
                    title: MarketFormatters.needCategoryName(
                      context,
                      section.category.slug,
                      section.category.name,
                    ),
                    compact: true,
                    viewAllLabel: LocaleKeys.marketCategoryByCategoryViewAll
                        .tr(),
                    onViewAll: () => context.push(
                      MarketRoutes.scopeServices(
                        scope,
                        category: section.category.slug,
                      ),
                    ),
                  ),
                  Gap(20.h),
                  _grid([
                    for (final s in section.items)
                      MarketServiceGridCard(
                        service: s,
                        onTap: () =>
                            MarketNavigation.openServiceCard(context, s),
                      ),
                  ]),
                ],
              ),
          ];
        }
        return SliverList.list(
          children: [
            for (final child in children)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                child: child,
              ),
          ],
        );
      },
    ),
  );
}

/// Khung chờ của một section: tiêu đề + [count] card.
Widget _sectionSkeleton(int count) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: 0.5,
      child: Container(
        height: 24.h,
        decoration: BoxDecoration(
          color: Colour.subtle,
          borderRadius: BorderRadius.circular(6.r),
        ),
      ),
    ),
    for (var i = 0; i < count; i++) ...[
      Gap(i == 0 ? 20.h : 8.h),
      const MarketCardSkeleton(height: 280),
    ],
  ],
);

class _ExpertsSection extends StatelessWidget {
  final MarketPageScope scope;

  const _ExpertsSection({required this.scope});

  @override
  Widget build(BuildContext context) => _EngagementScope(
    target: EngagementTarget.sellerProfile,
    ids: (s) => s.experts.map((e) => e.id),
    child: _Section<MarketExpertEntity>(
      kind: MarketSectionKind.experts,
      title: LocaleKeys.marketCategoryExpertsTitle.tr(),
      viewAllLabel: LocaleKeys.marketCategoryExpertsViewAll.tr(),
      onViewAll: (c) => c.push(MarketRoutes.scopeProviders(scope)),
      select: (s) => s.experts,
      showError: true,
      builder: (context, items) =>
          _grid([for (final e in items) MarketExpertSpotlightCard(expert: e)]),
    ),
  );
}

/// Medical Travel: chọn điểm đến là bước đầu → ngay dưới hero (web `DestinationsSection`):
/// >3 nước cuộn ngang, ít hơn lưới 2 cột; rỗng / lỗi → ẩn.
class _DestinationsSection extends StatelessWidget {
  const _DestinationsSection();

  @override
  Widget build(BuildContext context) => _Section<MarketDestination>(
    kind: MarketSectionKind.destinations,
    title: LocaleKeys.marketMtDestinationsTitle.tr(),
    select: (s) => s.destinations,
    builder: (context, items) {
      final screen = MediaQuery.sizeOf(context).width;
      void open(MarketDestination d) {
        if (d.code != null) context.push(MarketRoutes.destination(d.code!));
      }

      if (items.length > 3) {
        return SizedBox(
          height: screen * 0.62 * 1.25,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, _) => Gap(12.w),
            itemBuilder: (context, i) => SizedBox(
              width: screen * 0.62,
              child: DestinationCard(
                destination: items[i],
                onTap: () => open(items[i]),
              ),
            ),
          ),
        );
      }
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12.r,
        crossAxisSpacing: 12.r,
        childAspectRatio: 4 / 5,
        children: [
          for (final d in items)
            DestinationCard(destination: d, onTap: () => open(d)),
        ],
      );
    },
  );
}
