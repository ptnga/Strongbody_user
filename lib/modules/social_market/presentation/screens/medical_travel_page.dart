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

import '../../domain/entities/market_feed_entities.dart';
import '../../domain/entities/medical_travel_entities.dart';
import '../bloc/category_market/category_market_bloc.dart' show SectionStatus;
import '../bloc/engagement/engagement_cubit.dart';
import '../bloc/medical_travel/medical_travel_cubit.dart';
import '../market_navigation.dart';
import '../widgets/market_expert_card.dart';
import '../widgets/market_hero.dart';
import '../widgets/market_service_card.dart';
import '../widgets/market_ui.dart';
import '../widgets/medical_travel_widgets.dart';

/// Trang Medical Travel (web `/medical-travel` = `CategoryLandingPage`): Hero hỏi điểm
/// đến · coordinator · destinations · trust · "Recommended services" · How · FAQ.
/// Khối "For facilities" là lời mời đăng ký cơ sở (seller) — app buyer ẩn.
class MedicalTravelPage extends StatelessWidget {
  const MedicalTravelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MedicalTravelCubit>();
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colour.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              MarketTopBar(title: LocaleKeys.marketBrandMedicalTravel.tr()),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: cubit.load,
                  child: LayoutBuilder(
                    builder: (context, constraints) => CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: constraints.maxHeight,
                            child: Column(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: MarketAskHeading(
                                      tagline: LocaleKeys.marketHeroTagline
                                          .tr(),
                                      title: LocaleKeys
                                          .marketMtHeroAssistantTitle
                                          .tr(),
                                    ),
                                  ),
                                ),
                                const MarketHeroComposer(),
                                SizedBox(
                                  height: MediaQuery.paddingOf(context).bottom,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: _CoordinatorsSection()),
                        const SliverToBoxAdapter(child: _DestinationsSection()),
                        const SliverToBoxAdapter(child: MedicalTrustStrip()),
                        const SliverToBoxAdapter(child: _PackagesSection()),
                        const SliverToBoxAdapter(child: MedicalHowItWorks()),
                        const SliverToBoxAdapter(child: MedicalFaq()),
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

/// Hàng coordinator cuộn ngang, không giới hạn: seller Medical Travel theo score trước,
/// hết thì nối seller ngẫu nhiên; gần cuối hàng thì tự tải tiếp (web `CoordinatorsRow`).
class _CoordinatorsSection extends StatefulWidget {
  const _CoordinatorsSection();

  @override
  State<_CoordinatorsSection> createState() => _CoordinatorsSectionState();
}

class _CoordinatorsSectionState extends State<_CoordinatorsSection> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final p = _scroll.position;
      // Tải trước khi chạm hẳn cuối hàng (~1 màn hình card).
      if (p.maxScrollExtent - p.pixels < p.viewportDimension) {
        context.read<MedicalTravelCubit>().loadMoreCoordinators();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<EngagementCubit>(param1: EngagementTarget.sellerProfile),
      child: BlocConsumer<MedicalTravelCubit, MedicalTravelState>(
        listenWhen: (a, b) => a.coordinators != b.coordinators,
        listener: (context, state) => context.read<EngagementCubit>().load(
          state.coordinators.map((c) => c.id).where((id) => (id ?? 0) > 0),
        ),
        buildWhen: (a, b) =>
            a.coordinators != b.coordinators ||
            a.coordinatorsLoading != b.coordinatorsLoading ||
            a.coordinatorsError != b.coordinatorsError,
        builder: (context, state) {
          if (state.coordinators.isEmpty &&
              !state.coordinatorsLoading &&
              !state.coordinatorsError) {
            return const SizedBox.shrink();
          }
          final width = MediaQuery.sizeOf(context).width * 0.82;
          final cubit = context.read<MedicalTravelCubit>();
          return Padding(
            padding: EdgeInsets.only(top: 32.h, bottom: 64.h),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Text(
                    LocaleKeys.marketMtCoordinatorsIntro.tr(),
                    textAlign: TextAlign.center,
                    style: AppTextStyle.lightBodyLargeRegular.copyWith(
                      color: Colour.textSecondary,
                    ),
                  ),
                ),
                Gap(32.h),
                SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final c in state.coordinators) ...[
                          SizedBox(
                            width: width,
                            child: MarketExpertCard(expert: c),
                          ),
                          Gap(16.w),
                        ],
                        if (state.coordinatorsLoading)
                          for (var i = 0; i < 2; i++) ...[
                            SizedBox(
                              width: width,
                              child: const MarketCardSkeleton(height: 260),
                            ),
                            Gap(16.w),
                          ],
                        if (state.coordinatorsError)
                          SizedBox(
                            width: width,
                            child: MarketCard(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    LocaleKeys.marketMtCoordinatorsLoadMoreError
                                        .tr(),
                                    textAlign: TextAlign.center,
                                    style: AppTextStyle.lightBodyLargeRegular
                                        .copyWith(color: Colour.textSecondary),
                                  ),
                                  Gap(12.h),
                                  MarketButton(
                                    label: LocaleKeys.marketMtTryAgain.tr(),
                                    variant: MarketButtonVariant.outline,
                                    onPressed: cubit.loadMoreCoordinators,
                                  ),
                                ],
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
        },
      ),
    );
  }
}

/// "Browse by destination": nước có service / seller Medical Travel; >3 nước thì cuộn
/// ngang, ít hơn thì lưới 2 cột (web `DestinationsSection`). Rỗng / lỗi → ẩn.
class _DestinationsSection extends StatelessWidget {
  const _DestinationsSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MedicalTravelCubit, MedicalTravelState>(
      buildWhen: (a, b) =>
          a.destinations != b.destinations ||
          a.destinationsStatus != b.destinationsStatus,
      builder: (context, state) {
        if (state.destinations.isEmpty) return const SizedBox.shrink();
        final items = state.destinations;
        final screen = MediaQuery.sizeOf(context).width;
        void open(MarketDestination d) {
          if (d.code != null) context.push(MarketRoutes.destination(d.code!));
        }

        return Padding(
          padding: EdgeInsets.symmetric(vertical: 56.h),
          child: Column(
            children: [
              MedicalCenteredHeading(
                title: LocaleKeys.marketMtDestinationsTitle.tr(),
                subtitle: LocaleKeys.marketMtDestinationsSubtitle.tr(),
              ),
              Gap(40.h),
              if (items.length > 3)
                SizedBox(
                  height: screen * 0.62 * 1.25,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
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
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12.r,
                    crossAxisSpacing: 12.r,
                    childAspectRatio: 4 / 5,
                    children: [
                      for (final d in items)
                        DestinationCard(destination: d, onTap: () => open(d)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// "Recommended services": sort (Recommended / Top-rated — service Medical Travel
/// không hiện giá nên bỏ "Price") + lọc chứng nhận, "View more" (web `PackagesClient`).
class _PackagesSection extends StatelessWidget {
  const _PackagesSection();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<EngagementCubit>(param1: EngagementTarget.service),
      child: BlocConsumer<MedicalTravelCubit, MedicalTravelState>(
        listenWhen: (a, b) => a.packages != b.packages,
        listener: (context, state) => context.read<EngagementCubit>().load(
          state.packages.map((s) => s.id),
        ),
        builder: (context, state) {
          final cubit = context.read<MedicalTravelCubit>();
          final f = state.filters;
          final loading =
              state.packagesStatus == SectionStatus.loading ||
              state.packagesStatus == SectionStatus.initial;
          final Widget results;
          if (state.packagesStatus == SectionStatus.failure) {
            results = MarketCard(
              child: Column(
                children: [
                  Text(
                    LocaleKeys.marketMtPackagesLoadError.tr(),
                    textAlign: TextAlign.center,
                    style: AppTextStyle.lightBodyLargeRegular.copyWith(
                      color: Colour.textSecondary,
                    ),
                  ),
                  MarketButton(
                    label: LocaleKeys.marketMtTryAgain.tr(),
                    variant: MarketButtonVariant.link,
                    onPressed: cubit.retryPackages,
                  ),
                ],
              ),
            );
          } else if (!loading && state.packages.isEmpty) {
            results = MarketCard(
              child: Text(
                LocaleKeys.marketMtPackagesEmpty.tr(),
                textAlign: TextAlign.center,
                style: AppTextStyle.lightBodyLargeRegular.copyWith(
                  color: Colour.textSecondary,
                ),
              ),
            );
          } else if (loading && state.packages.isEmpty) {
            results = Column(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  const MarketCardSkeleton(height: 300),
                  Gap(16.h),
                ],
              ],
            );
          } else {
            results = AnimatedOpacity(
              opacity: loading ? 0.5 : 1,
              duration: const Duration(milliseconds: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in state.packages) ...[
                    MarketServiceCard(
                      service: s,
                      showImage: true,
                      onTap: () => MarketNavigation.openService(context, s),
                      onInquiry: () =>
                          MarketNavigation.inquireService(context, s),
                      onViewAndBook: () =>
                          MarketNavigation.viewAndBook(context, s),
                    ),
                    Gap(16.h),
                  ],
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 56.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MarketSectionHeading(
                  title: LocaleKeys.marketMtPackagesTitle.tr(),
                  description: LocaleKeys.marketMtPackagesSubtitle.tr(),
                ),
                Gap(24.h),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (key, label) in [
                        (
                          'recommended',
                          LocaleKeys.marketMtPackagesSortRecommended.tr(),
                        ),
                        (
                          'top_rated',
                          LocaleKeys.marketMtPackagesSortTopRated.tr(),
                        ),
                      ]) ...[
                        MarketFilterChip(
                          label: label,
                          selected: f.sort == key,
                          onTap: () =>
                              cubit.changeFilters(f.copyWith(sort: key)),
                        ),
                        Gap(8.w),
                      ],
                    ],
                  ),
                ),
                Gap(10.h),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in MarketCert.values) ...[
                        MarketFilterChip(
                          label: MedicalTravelTexts.cert(c),
                          selected: f.certs.contains(c),
                          onTap: () => cubit.changeFilters(
                            f.copyWith(
                              certs: f.certs.contains(c)
                                  ? ({...f.certs}..remove(c))
                                  : {...f.certs, c},
                            ),
                          ),
                        ),
                        Gap(8.w),
                      ],
                    ],
                  ),
                ),
                Gap(24.h),
                results,
                if (state.packagesStatus == SectionStatus.success &&
                    state.packagesTotal > state.packages.length) ...[
                  Gap(16.h),
                  if (state.packagesMoreError)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Text(
                        LocaleKeys.marketMtPackagesLoadMoreError.tr(),
                        textAlign: TextAlign.center,
                        style: AppTextStyle.lightBodyMediumRegular.copyWith(
                          color: Colour.textSecondary,
                        ),
                      ),
                    ),
                  Center(
                    child: MarketButton(
                      large: true,
                      variant: MarketButtonVariant.outline,
                      label: state.packagesLoadingMore
                          ? LocaleKeys.marketMtLoading.tr()
                          : LocaleKeys.marketMtPackagesViewMore.tr(),
                      onPressed: state.packagesLoadingMore
                          ? null
                          : cubit.viewMorePackages,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
