import 'dart:async';

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

import '../../data/mappers/market_mapper.dart';
import '../../domain/entities/market_feed_entities.dart';
import '../../domain/entities/medical_travel_entities.dart';
import '../bloc/category_market/category_market_bloc.dart' show SectionStatus;
import '../bloc/engagement/engagement_cubit.dart';
import '../bloc/medical_travel/destination_cubit.dart';
import '../market_navigation.dart';
import '../widgets/market_expert_card.dart';
import '../widgets/market_hero.dart';
import '../widgets/market_service_card.dart';
import '../widgets/market_ui.dart';
import '../widgets/medical_travel_widgets.dart';

/// Ngôn ngữ của bộ lọc "Speaks", tên viết bằng chính ngôn ngữ đó (web `LANGUAGE_CODES`).
const _speakLanguages = {
  'en': 'English',
  'vi': 'Tiếng Việt',
  'ko': '한국어',
  'th': 'ไทย',
  'zh': '中文',
  'ja': '日本語',
  'fr': 'Français',
  'de': 'Deutsch',
  'es': 'Español',
  'ru': 'Русский',
  'ar': 'العربية',
};

/// Mốc giá nhanh, USD (web `PRICE_PRESETS`).
const _pricePresets = <(double?, double?)>[
  (null, 500),
  (500, 2000),
  (2000, 5000),
  (5000, null),
];

/// Trang một nước của Medical Travel (web `/destination/{code}/medical-travel`):
/// hero · tab Services / Providers (lọc + tìm riêng từng tab) · nước khác.
class DestinationPage extends StatelessWidget {
  final String code;

  const DestinationPage({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    // Engagement của tab Services; tab Providers có cubit riêng bên dưới (_DestinationBody).
    return BlocProvider(
      create: (_) => getIt<EngagementCubit>(param1: EngagementTarget.service),
      child: Scaffold(
        backgroundColor: Colour.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              MarketTopBar(title: LocaleKeys.marketBrandMedicalTravel.tr()),
              Expanded(
                child: BlocBuilder<DestinationCubit, DestinationState>(
                  buildWhen: (a, b) =>
                      a.countryStatus != b.countryStatus ||
                      a.country != b.country,
                  builder: (context, state) {
                    final country = state.country;
                    if (country == null) {
                      if (state.countryStatus == SectionStatus.failure) {
                        return _StatePanel(
                          icon: Icons.public_off_outlined,
                          title: LocaleKeys.marketDestResultsErrorTitle.tr(),
                          hint: LocaleKeys.marketDestResultsErrorHint.tr(),
                          action: LocaleKeys.marketDestResultsRetry.tr(),
                          onAction: () =>
                              context.read<DestinationCubit>().load(code),
                        );
                      }
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _DestinationBody(country: country);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationBody extends StatefulWidget {
  final MarketCountry country;

  const _DestinationBody({required this.country});

  @override
  State<_DestinationBody> createState() => _DestinationBodyState();
}

class _DestinationBodyState extends State<_DestinationBody> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Ô tìm kiếm: chờ 350ms sau lần gõ cuối (web `useDebounced`).
  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final cubit = context.read<DestinationCubit>();
      final state = cubit.state;
      if (state.tab == DestinationTab.services) {
        cubit.changeServiceFilters(
          state.serviceFilters.copyWith(keyword: text),
        );
      } else if (state.sellerFilters != null) {
        cubit.changeSellerFilters(state.sellerFilters!.copyWith(keyword: text));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DestinationCubit>();
    return BlocProvider(
      create: (_) =>
          getIt<EngagementCubit>(param1: EngagementTarget.sellerProfile),
      child: Builder(
        builder: (sellersContext) => BlocConsumer<DestinationCubit, DestinationState>(
          listenWhen: (a, b) =>
              a.services.items != b.services.items ||
              a.sellers.items != b.sellers.items,
          listener: (_, state) {
            context.read<EngagementCubit>().load(
              state.services.items.map((s) => s.id),
            );
            sellersContext.read<EngagementCubit>().load(
              state.sellers.items.map((e) => e.id),
            );
          },
          builder: (context, state) {
            final tabServices = state.tab == DestinationTab.services;
            final chips = _activeChips(context, state);
            return NotificationListener<ScrollNotification>(
              onNotification: (n) {
                // Gần cuối danh sách → tải thêm (web "Show more" + infinite).
                if (n.metrics.extentAfter < 400) cubit.loadMore();
                return false;
              },
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  16.h,
                  16.w,
                  24.h + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  _Hero(country: widget.country),
                  Gap(24.h),
                  _Tabs(
                    tab: state.tab,
                    onChanged: (tab) {
                      cubit.selectTab(tab);
                      final f = tab == DestinationTab.services
                          ? state.serviceFilters.keyword
                          : state.sellerFilters?.keyword ?? '';
                      _search.text = f;
                    },
                  ),
                  Gap(16.h),
                  Row(
                    children: [
                      _FiltersButton(
                        count: chips.where((c) => c.$1 != 'kw').length,
                        onTap: () => _openFilters(context, state),
                      ),
                      Gap(8.w),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: _onSearch,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            isDense: true,
                            // Ô tìm bo tròn có viền (web `formClass.search`).
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: const BorderSide(
                                color: Colour.lineStrong,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: const BorderSide(
                                color: Colour.lineStrong,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10.h,
                            ),
                            prefixIcon: const Icon(Icons.search_rounded),
                            hintText: tabServices
                                ? LocaleKeys.marketDestFiltersSearchServices
                                      .tr()
                                : LocaleKeys.marketDestFiltersSearchSellers
                                      .tr(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (chips.isNotEmpty) ...[
                    Gap(12.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final (_, label, remove) in chips)
                          InputChip(
                            label: Text(label),
                            onDeleted: () {
                              remove();
                            },
                          ),
                        MarketButton(
                          label: LocaleKeys.marketDestFiltersClearAll.tr(),
                          variant: MarketButtonVariant.link,
                          onPressed: () => _clear(state),
                        ),
                      ],
                    ),
                  ],
                  Gap(20.h),
                  if (tabServices)
                    ..._results(
                      context,
                      state.services.status,
                      state.services.items.isEmpty,
                      [
                        for (final s in state.services.items)
                          // Cubit engagement của service nằm phía trên cubit seller.
                          BlocProvider.value(
                            value: this.context.read<EngagementCubit>(),
                            child: MarketServiceCard(
                              service: s,
                              onTap: () =>
                                  MarketNavigation.openService(context, s),
                              onInquiry: () =>
                                  MarketNavigation.inquireService(context, s),
                              onViewAndBook: () =>
                                  MarketNavigation.viewAndBook(context, s),
                            ),
                          ),
                      ],
                      state.services.loadingMore,
                      state.services.hasMore,
                      emptyTitle: LocaleKeys.marketDestResultsEmptyServices.tr(
                        namedArgs: {'country': widget.country.title},
                      ),
                      state: state,
                    )
                  else
                    ..._results(
                      sellersContext,
                      state.sellers.status,
                      state.sellers.items.isEmpty,
                      [
                        for (final e in state.sellers.items)
                          BlocProvider.value(
                            value: sellersContext.read<EngagementCubit>(),
                            child: MarketExpertCard(expert: e),
                          ),
                      ],
                      state.sellers.loadingMore,
                      state.sellers.hasMore,
                      emptyTitle: LocaleKeys.marketDestResultsEmptySellers.tr(
                        namedArgs: {'country': widget.country.title},
                      ),
                      state: state,
                    ),
                  if (state.others.isNotEmpty) ...[
                    Gap(48.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            LocaleKeys.marketDestOthersTitle.tr(),
                            style: AppTextStyle.lightHeadingMedium.copyWith(
                              color: Colour.textPrimary,
                            ),
                          ),
                        ),
                        MarketButton(
                          label: LocaleKeys.marketDestOthersSeeAll.tr(),
                          variant: MarketButtonVariant.more,
                          onPressed: () => context.pop(),
                        ),
                      ],
                    ),
                    Gap(24.h),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12.r,
                      crossAxisSpacing: 12.r,
                      childAspectRatio: 4 / 3,
                      children: [
                        for (final d in state.others)
                          DestinationCard(
                            destination: d,
                            compact: true,
                            onTap: () => context.pushReplacement(
                              MarketRoutes.destination(d.code!),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _results(
    BuildContext context,
    SectionStatus status,
    bool empty,
    List<Widget> cards,
    bool loadingMore,
    bool hasMore, {
    required String emptyTitle,
    required DestinationState state,
  }) {
    final cubit = context.read<DestinationCubit>();
    if (status == SectionStatus.failure && empty) {
      return [
        _StatePanel(
          icon: Icons.cloud_off_outlined,
          title: LocaleKeys.marketDestResultsErrorTitle.tr(),
          hint: LocaleKeys.marketDestResultsErrorHint.tr(),
          action: LocaleKeys.marketDestResultsRetry.tr(),
          onAction: cubit.retry,
        ),
      ];
    }
    if ((status == SectionStatus.loading || status == SectionStatus.initial) &&
        empty) {
      return [
        for (var i = 0; i < 3; i++) ...[
          const MarketCardSkeleton(height: 220),
          Gap(16.h),
        ],
      ];
    }
    if (empty) {
      return [
        _StatePanel(
          icon: Icons.search_off_outlined,
          title: emptyTitle,
          hint: LocaleKeys.marketDestResultsEmptyHint.tr(),
          action: LocaleKeys.marketDestResultsClearFilters.tr(),
          onAction: () => _clear(state),
        ),
      ];
    }
    return [
      AnimatedOpacity(
        opacity: status == SectionStatus.loading ? 0.5 : 1,
        duration: const Duration(milliseconds: 200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in cards) ...[c, Gap(16.h)],
          ],
        ),
      ),
      if (loadingMore) const MarketCardSkeleton(height: 220),
      if (!loadingMore && hasMore)
        Center(
          child: MarketButton(
            label: LocaleKeys.marketDestResultsShowMore.tr(),
            variant: MarketButtonVariant.outline,
            large: true,
            onPressed: cubit.loadMore,
          ),
        ),
    ];
  }

  void _clear(DestinationState state) {
    _search.clear();
    final cubit = context.read<DestinationCubit>();
    if (state.tab == DestinationTab.services) {
      cubit.changeServiceFilters(
        MedicalServiceFilters(countryId: widget.country.id),
      );
    } else {
      cubit.changeSellerFilters(
        CountrySellerFilters(countryId: widget.country.id),
      );
    }
  }

  static String _usd(double v) => MarketMapper.formatMoney(v);

  static String? priceLabel(double? min, double? max) {
    if (min != null && max != null) {
      return LocaleKeys.marketDestFiltersPriceBetween.tr(
        namedArgs: {'min': _usd(min), 'max': _usd(max)},
      );
    }
    if (min != null) {
      return LocaleKeys.marketDestFiltersPriceFrom.tr(
        namedArgs: {'min': _usd(min)},
      );
    }
    if (max != null) {
      return LocaleKeys.marketDestFiltersPriceUpTo.tr(
        namedArgs: {'max': _usd(max)},
      );
    }
    return null;
  }

  static String sortLabel(MedicalServiceFilters f) =>
      switch ((f.sort, f.priceDesc)) {
        ('top_rated', _) => LocaleKeys.marketDestFiltersSortTopRated.tr(),
        ('price', false) => LocaleKeys.marketDestFiltersSortPriceAsc.tr(),
        ('price', true) => LocaleKeys.marketDestFiltersSortPriceDesc.tr(),
        _ => LocaleKeys.marketDestFiltersSortRecommended.tr(),
      };

  /// Chip bộ lọc đang bật của tab hiện tại — mỗi chip tự gỡ (web `chips`).
  List<(String, String, VoidCallback)> _activeChips(
    BuildContext context,
    DestinationState state,
  ) {
    final cubit = context.read<DestinationCubit>();
    if (state.tab == DestinationTab.services) {
      final f = state.serviceFilters;
      final price = priceLabel(f.minPrice, f.maxPrice);
      return [
        if (f.keyword.isNotEmpty)
          (
            'kw',
            '“${f.keyword}”',
            () {
              _search.clear();
              cubit.changeServiceFilters(f.copyWith(keyword: ''));
            },
          ),
        if (f.sort != 'recommended')
          (
            'sort',
            sortLabel(f),
            () {
              cubit.changeServiceFilters(
                f.copyWith(sort: 'recommended', priceDesc: false),
              );
            },
          ),
        if (price != null)
          (
            'price',
            price,
            () {
              cubit.changeServiceFilters(
                f.copyWith(minPrice: () => null, maxPrice: () => null),
              );
            },
          ),
        for (final c in f.certs)
          (
            c.apiValue,
            MedicalTravelTexts.cert(c),
            () {
              cubit.changeServiceFilters(
                f.copyWith(certs: {...f.certs}..remove(c)),
              );
            },
          ),
      ];
    }
    final f = state.sellerFilters;
    if (f == null) return const [];
    return [
      if (f.keyword.isNotEmpty)
        (
          'kw',
          '“${f.keyword}”',
          () {
            _search.clear();
            cubit.changeSellerFilters(f.copyWith(keyword: ''));
          },
        ),
      if (f.verified)
        (
          'ver',
          LocaleKeys.marketDestFiltersVerified.tr(),
          () {
            cubit.changeSellerFilters(f.copyWith(verified: false));
          },
        ),
      if (f.introCall)
        (
          'intro',
          LocaleKeys.marketDestFiltersIntroCall.tr(),
          () {
            cubit.changeSellerFilters(f.copyWith(introCall: false));
          },
        ),
      if (f.language.isNotEmpty)
        (
          'lang',
          _speakLanguages[f.language] ?? f.language,
          () {
            cubit.changeSellerFilters(f.copyWith(language: ''));
          },
        ),
    ];
  }

  Future<void> _openFilters(
    BuildContext context,
    DestinationState state,
  ) async {
    final cubit = context.read<DestinationCubit>();
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colour.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => state.tab == DestinationTab.services
          ? _ServiceFilterSheet(
              initial: state.serviceFilters,
              onApply: cubit.changeServiceFilters,
            )
          : _SellerFilterSheet(
              initial: state.sellerFilters!,
              onApply: cubit.changeSellerFilters,
            ),
    );
  }
}

/// Ảnh lớn của nước + cờ, nhãn "Medical Travel destination", tên, mô tả, 2 cam kết.
class _Hero extends StatelessWidget {
  final MarketCountry country;

  const _Hero({required this.country});

  @override
  Widget build(BuildContext context) {
    final cover = country.images.firstOrNull;
    final pill = BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
    );
    final white = AppTextStyle.lightBodyMediumMedium.copyWith(
      color: Colors.white,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        constraints: BoxConstraints(minHeight: 320.h),
        decoration: const BoxDecoration(color: Colour.textPrimary),
        child: Stack(
          children: [
            if (cover != null)
              Positioned.fill(
                child: Image.network(
                  cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(24.r),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: 272.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (country.flag != null) ...[
                          Container(
                            width: 44.r,
                            height: 44.r,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3.r),
                              child: Image.network(
                                country.flag!,
                                width: 32.w,
                                height: 24.w,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                          Gap(12.w),
                        ],
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 4.h,
                          ),
                          decoration: pill,
                          child: Text(
                            LocaleKeys.marketDestHeroEyebrow.tr(
                              namedArgs: {
                                'category': LocaleKeys.marketMedicalTravel.tr(),
                              },
                            ),
                            style: white,
                          ),
                        ),
                      ],
                    ),
                    Gap(16.h),
                    Text(
                      country.title,
                      style: AppTextStyle.lightHeadingMediumLarge.copyWith(
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    if (country.description.isNotEmpty) ...[
                      Gap(12.h),
                      Text(
                        country.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.lightBodyLargeRegular.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    Gap(20.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        for (final (icon, label) in [
                          (
                            Icons.support_agent,
                            LocaleKeys.marketDestHeroLocalCoordinators.tr(),
                          ),
                          (
                            Icons.verified_user_outlined,
                            LocaleKeys.marketDestHeroCheckedFacilities.tr(),
                          ),
                        ])
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 6.h,
                            ),
                            decoration: pill,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 18.r, color: Colors.white),
                                Gap(6.w),
                                Text(label, style: white),
                              ],
                            ),
                          ),
                      ],
                    ),
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

/// Tab Services / Providers dạng segmented (web `segmented`).
class _Tabs extends StatelessWidget {
  final DestinationTab tab;
  final ValueChanged<DestinationTab> onChanged;

  const _Tabs({required this.tab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: Colour.border,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          for (final (t, label) in [
            (DestinationTab.services, LocaleKeys.marketDestTabsServices.tr()),
            (DestinationTab.sellers, LocaleKeys.marketDestTabsSellers.tr()),
          ])
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t == tab ? Colour.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    label,
                    style: AppTextStyle.lightBodyMediumMedium.copyWith(
                      color: t == tab
                          ? Colour.textPrimary
                          : Colour.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FiltersButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _FiltersButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.tune_rounded, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(LocaleKeys.marketDestFiltersTitle.tr()),
          if (count > 0) ...[
            Gap(6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: Colour.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: AppTextStyle.lightBodySmallMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Khối trạng thái (lỗi / không có kết quả) + một nút (web `StatePanel`).
class _StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final String action;
  final VoidCallback onAction;

  const _StatePanel({
    required this.icon,
    required this.title,
    required this.hint,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return MarketCard(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
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
          Gap(16.h),
          MarketButton(
            label: action,
            variant: MarketButtonVariant.outline,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

/// Khung chung của sheet lọc: tiêu đề + nội dung cuộn + Clear all / Apply.
class _FilterSheetFrame extends StatelessWidget {
  final List<Widget> children;
  final VoidCallback onClear;
  final VoidCallback onApply;

  const _FilterSheetFrame({
    required this.children,
    required this.onClear,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 8.w, 8.h),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: Colour.textPrimary),
                Gap(8.w),
                Expanded(
                  child: Text(
                    LocaleKeys.marketDestFiltersTitle.tr(),
                    style: AppTextStyle.lightHeadingSmall.copyWith(
                      color: Colour.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colour.lineSubtle),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.all(20.r),
              children: children,
            ),
          ),
          const Divider(height: 1, color: Colour.lineSubtle),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20.w,
              12.h,
              20.w,
              12.h + MediaQuery.paddingOf(context).bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: MarketButton(
                    large: true,
                    variant: MarketButtonVariant.outline,
                    label: LocaleKeys.marketDestFiltersClearAll.tr(),
                    onPressed: onClear,
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: MarketButton(
                    large: true,
                    label: LocaleKeys.marketDestFiltersApply.tr(),
                    onPressed: () {
                      onApply();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _groupTitle(String text) => Padding(
  padding: EdgeInsets.only(bottom: 8.h, top: 8.h),
  child: Text(
    text,
    style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
      color: Colour.textPrimary,
    ),
  ),
);

/// Lọc tab Services: sắp xếp · giá · chứng nhận cơ sở (web `ServiceFilterPanel`).
class _ServiceFilterSheet extends StatefulWidget {
  final MedicalServiceFilters initial;
  final ValueChanged<MedicalServiceFilters> onApply;

  const _ServiceFilterSheet({required this.initial, required this.onApply});

  @override
  State<_ServiceFilterSheet> createState() => _ServiceFilterSheetState();
}

class _ServiceFilterSheetState extends State<_ServiceFilterSheet> {
  late var _f = widget.initial;
  late final _min = TextEditingController(
    text: _f.minPrice?.toStringAsFixed(0) ?? '',
  );
  late final _max = TextEditingController(
    text: _f.maxPrice?.toStringAsFixed(0) ?? '',
  );
  String? _priceError;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _applyPrice() {
    final min = double.tryParse(_min.text.trim());
    final max = double.tryParse(_max.text.trim());
    if ((_min.text.trim().isNotEmpty && (min == null || min < 0)) ||
        (_max.text.trim().isNotEmpty && (max == null || max < 0))) {
      setState(
        () => _priceError = LocaleKeys.marketDestFiltersPriceInvalid.tr(),
      );
      return;
    }
    if (min != null && max != null && max <= min) {
      setState(() => _priceError = LocaleKeys.marketDestFiltersPriceOrder.tr());
      return;
    }
    setState(() {
      _priceError = null;
      _f = _f.copyWith(minPrice: () => min, maxPrice: () => max);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sorts = [
      ('recommended', false, LocaleKeys.marketDestFiltersSortRecommended.tr()),
      ('top_rated', false, LocaleKeys.marketDestFiltersSortTopRated.tr()),
      ('price', false, LocaleKeys.marketDestFiltersSortPriceAsc.tr()),
      ('price', true, LocaleKeys.marketDestFiltersSortPriceDesc.tr()),
    ];
    return _FilterSheetFrame(
      onClear: () => setState(() {
        _f = MedicalServiceFilters(
          countryId: _f.countryId,
          keyword: _f.keyword,
        );
        _min.clear();
        _max.clear();
      }),
      onApply: () => widget.onApply(_f),
      children: [
        _groupTitle(LocaleKeys.marketDestFiltersSortBy.tr()),
        RadioGroup<(String, bool)>(
          groupValue: (_f.sort, _f.sort == 'price' && _f.priceDesc),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _f = _f.copyWith(sort: v.$1, priceDesc: v.$2));
          },
          child: Column(
            children: [
              for (final (key, desc, label) in sorts)
                RadioListTile<(String, bool)>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: (key, desc),
                  title: Text(label),
                ),
            ],
          ),
        ),
        Gap(8.h),
        _groupTitle(LocaleKeys.marketDestFiltersPrice.tr()),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final (min, max) in _pricePresets)
              MarketFilterChip(
                label: _DestinationBodyState.priceLabel(min, max)!,
                selected: _f.minPrice == min && _f.maxPrice == max,
                onTap: () => setState(() {
                  final on = _f.minPrice == min && _f.maxPrice == max;
                  _f = _f.copyWith(
                    minPrice: () => on ? null : min,
                    maxPrice: () => on ? null : max,
                  );
                  _min.text = on || min == null ? '' : min.toStringAsFixed(0);
                  _max.text = on || max == null ? '' : max.toStringAsFixed(0);
                }),
              ),
          ],
        ),
        Gap(12.h),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _min,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: LocaleKeys.marketDestFiltersMin.tr(),
                ),
              ),
            ),
            Gap(8.w),
            Expanded(
              child: TextField(
                controller: _max,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: LocaleKeys.marketDestFiltersMax.tr(),
                ),
              ),
            ),
            Gap(8.w),
            IconButton.filled(
              onPressed: _applyPrice,
              icon: const Icon(Icons.arrow_forward_rounded),
              tooltip: LocaleKeys.marketDestFiltersApplyPrice.tr(),
            ),
          ],
        ),
        if (_priceError != null)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              _priceError!,
              style: AppTextStyle.lightBodySmallRegular.copyWith(
                color: Colour.error,
              ),
            ),
          ),
        Gap(16.h),
        _groupTitle(LocaleKeys.marketDestFiltersCredentials.tr()),
        for (final c in MarketCert.values)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: _f.certs.contains(c),
            title: Text(MedicalTravelTexts.cert(c)),
            onChanged: (on) => setState(
              () => _f = _f.copyWith(
                certs: on == true
                    ? {..._f.certs, c}
                    : ({..._f.certs}..remove(c)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Lọc tab Providers: đã xác minh · có intro call miễn phí · ngôn ngữ (web
/// `SellerFilterPanel`).
class _SellerFilterSheet extends StatefulWidget {
  final CountrySellerFilters initial;
  final ValueChanged<CountrySellerFilters> onApply;

  const _SellerFilterSheet({required this.initial, required this.onApply});

  @override
  State<_SellerFilterSheet> createState() => _SellerFilterSheetState();
}

class _SellerFilterSheetState extends State<_SellerFilterSheet> {
  late var _f = widget.initial;

  @override
  Widget build(BuildContext context) {
    return _FilterSheetFrame(
      onClear: () => setState(
        () => _f = CountrySellerFilters(
          countryId: _f.countryId,
          keyword: _f.keyword,
        ),
      ),
      onApply: () => widget.onApply(_f),
      children: [
        _groupTitle(LocaleKeys.marketDestFiltersTrust.tr()),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _f.verified,
          title: Text(LocaleKeys.marketDestFiltersVerified.tr()),
          subtitle: Text(LocaleKeys.marketDestFiltersVerifiedHint.tr()),
          onChanged: (v) => setState(() => _f = _f.copyWith(verified: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _f.introCall,
          title: Text(LocaleKeys.marketDestFiltersIntroCall.tr()),
          subtitle: Text(LocaleKeys.marketDestFiltersIntroCallHint.tr()),
          onChanged: (v) => setState(() => _f = _f.copyWith(introCall: v)),
        ),
        Gap(8.h),
        _groupTitle(LocaleKeys.marketDestFiltersSpeaks.tr()),
        RadioGroup<String>(
          groupValue: _f.language,
          onChanged: (v) => setState(() => _f = _f.copyWith(language: v ?? '')),
          child: Column(
            children: [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: '',
                title: Text(LocaleKeys.marketDestFiltersAny.tr()),
              ),
              for (final e in _speakLanguages.entries)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: e.key,
                  title: Text(e.value),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
