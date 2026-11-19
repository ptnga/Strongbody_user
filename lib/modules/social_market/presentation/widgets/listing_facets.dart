import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../domain/entities/market_category.dart';
import '../../domain/entities/market_listing_entities.dart';
import '../bloc/category_market/category_market_bloc.dart' show SectionStatus;
import '../bloc/market_listing/listing_facets_cubit.dart';
import '../market_formatters.dart';
import '../market_navigation.dart';
import 'medical_travel_widgets.dart' show MarketFilterChip;

/// Hàng lọc trên lưới listing service của trang nhãn (web `NeedCategoryChips`):
/// chưa chọn category → chip "All" + category; đã chọn → thanh tab classification.
/// Lỗi / không có dữ liệu → không hiện gì (lưới vẫn lọc đúng).
class ListingFacetsBar extends StatelessWidget {
  final MarketPageScope scope;

  /// Tab classification đang chọn (null = All).
  final String? activeClassification;
  final ValueChanged<String?> onClassification;

  const ListingFacetsBar({
    super.key,
    required this.scope,
    required this.activeClassification,
    required this.onClassification,
  });

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ListingFacetsCubit, ListingFacetsState>(
    builder: (context, state) {
      if (state.status == SectionStatus.initial ||
          state.status == SectionStatus.loading) {
        return const _ChipsSkeleton();
      }
      if (state.status == SectionStatus.failure) {
        return const SizedBox.shrink();
      }
      if (state.category != null) {
        final selected = state.selected;
        final active = activeClassification ?? '';
        // Chỉ classification đang có service (và tab đang chọn, kể cả khi đã hết).
        final tabs = state.tabs
            .where((c) => c.count > 0 || c.slug == active)
            .toList();
        if (selected == null || tabs.isEmpty) {
          return const SizedBox.shrink();
        }
        return ClassificationTabs(
          title: MarketFormatters.needCategoryName(
            context,
            selected.slug,
            selected.name,
          ),
          tabs: tabs,
          active: tabs.any((c) => c.slug == active) ? active : '',
          onSelect: onClassification,
        );
      }
      if (state.chips.isEmpty) return const SizedBox.shrink();
      return _CategoryChips(scope: scope, chips: state.chips);
    },
  );
}

/// Chip "All" (đang chọn) + các category của nhãn có service: chọn một category → mở
/// listing của category đó (web link `?category=`, quay lại = về "All").
class _CategoryChips extends StatelessWidget {
  final MarketPageScope scope;
  final List<MarketBusinessCategory> chips;

  const _CategoryChips({required this.scope, required this.chips});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40.h,
    child: ListView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      children: [
        MarketFilterChip(
          label: LocaleKeys.marketListingAllCategories.tr(),
          selected: true,
          onTap: () {},
        ),
        for (final c in chips) ...[
          Gap(8.w),
          MarketFilterChip(
            label: MarketFormatters.needCategoryName(context, c.slug, c.name),
            selected: false,
            onTap: () => context.push(
              MarketRoutes.scopeServices(scope, category: c.slug),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ChipsSkeleton extends StatelessWidget {
  const _ChipsSkeleton();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36.h,
    child: ClipRect(
      child: Row(
        children: [
          for (final w in const [56.0, 128.0, 96.0, 144.0, 112.0]) ...[
            Container(
              width: w.w,
              decoration: BoxDecoration(
                color: Colour.subtle,
                borderRadius: BorderRadius.circular(18.r),
              ),
            ),
            Gap(8.w),
          ],
        ],
      ),
    ),
  );
}

/// Thanh tab service classification của 1 category (web `ClassificationTabs`): "All" +
/// các classification trên MỘT hàng trải hết bề ngang. Hết chỗ thì phần còn lại gom vào
/// nút "More" ở cuối (mở danh sách đủ, có ô tìm khi dài); còn chỗ ≥ 72px thì hiện thêm 1
/// tab cắt "…". Tab đang chọn luôn nằm trên thanh (thay tab cuối nếu bị gom).
class ClassificationTabs extends StatelessWidget {
  /// Tên category — tiêu đề danh sách "More".
  final String title;
  final List<MarketClassificationFacet> tabs;

  /// Slug đang chọn ('' = All).
  final String active;
  final ValueChanged<String?> onSelect;

  const ClassificationTabs({
    super.key,
    required this.title,
    required this.tabs,
    required this.active,
    required this.onSelect,
  });

  /// Khớp web: rãnh p-1 (2 × 4) và gap-1 (4); tab px-4, tối đa 256.
  static const trackPadding = 4.0;
  static const gap = 4.0;
  static const tabPadding = 16.0;
  static const tabMaxWidth = 256.0;

  /// Còn ngần này (px) thì vẫn hiện thêm 1 tab cắt chữ thay vì để trống.
  static const minPartial = 72.0;

  /// Danh sách "More" có ô tìm khi dài hơn ngần này.
  static const searchFrom = 10;

  static TextStyle get _style => AppTextStyle.lightBodyMediumMedium;

  /// Số tab classification vừa thanh (sau "All") + tab cuối có cắt chữ không (web
  /// `compute`): [widths] = All, từng classification; [more] = nút More.
  static ({int fit, bool partial}) fitTabs({
    required double available,
    required List<double> widths,
    required double more,
  }) {
    final items = widths.skip(1).toList();
    // Không cần nút More khi cả All + mọi tab vừa thanh.
    final total =
        widths.fold<double>(0, (a, w) => a + w) + gap * (widths.length - 1);
    if (total <= available) return (fit: items.length, partial: false);
    var used = widths.first + gap + more;
    var n = 0;
    while (n < items.length && used + items[n] + gap <= available) {
      used += items[n++] + gap;
    }
    final partial = n < items.length && available - used - gap >= minPartial;
    return (fit: partial ? n + 1 : n, partial: partial);
  }

  /// Tab trên thanh: [fit] tab đầu; tab đang chọn nằm ngoài thì thay tab cuối.
  static List<T> shownTabs<T>(
    List<T> tabs,
    int fit,
    bool Function(T tab) isActive,
  ) {
    if (fit >= tabs.length) return tabs;
    final head = tabs.take(fit).toList();
    final i = tabs.indexWhere(isActive);
    if (i >= fit && fit > 0) {
      head[fit - 1] = tabs[i];
    } else if (i >= fit) {
      head.add(tabs[i]);
    }
    return head;
  }

  double _measure(BuildContext context, String text, {double extra = 0}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final w = painter.width + tabPadding.w * 2 + extra;
    return w > tabMaxWidth.w ? tabMaxWidth.w : w;
  }

  @override
  Widget build(BuildContext context) {
    final allLabel = LocaleKeys.marketListingAllClassifications.tr();
    final moreLabel = LocaleKeys.marketListingMoreClassifications.tr();
    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = [
          _measure(context, allLabel),
          for (final t in tabs) _measure(context, t.name),
        ];
        final moreWidth = _measure(context, moreLabel, extra: (18 + 6).r);
        final available = constraints.maxWidth - trackPadding.w * 2;
        final fit = fitTabs(
          available: available,
          widths: widths,
          more: moreWidth,
        );
        final shown = shownTabs(tabs, fit.fit, (t) => t.slug == active);
        final overflow = fit.fit < tabs.length;
        // Tab đang chọn đổi chỗ / nhãn quá dài so với chỗ (chữ to…) → mọi tab co lại cắt
        // "…" thay vì tràn (web: rãnh `overflow-hidden`).
        double widthOf(MarketClassificationFacet t) =>
            widths[tabs.indexOf(t) + 1];
        final planned =
            widths.first +
            [
              for (final (i, t) in shown.indexed)
                fit.partial && i == shown.length - 1 ? minPartial : widthOf(t),
            ].fold<double>(0, (a, w) => a + w + gap) +
            (overflow ? moreWidth + gap : 0);
        final cramped = planned > available;
        Widget tab(Widget child, {bool flexible = false}) =>
            flexible || cramped ? Flexible(child: child) : child;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(trackPadding.w),
          decoration: BoxDecoration(
            color: Colour.border,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              tab(
                _Tab(
                  label: allLabel,
                  active: active.isEmpty,
                  onTap: () => onSelect(null),
                ),
              ),
              for (final (i, t) in shown.indexed) ...[
                Gap(gap.w),
                tab(
                  _Tab(
                    label: t.name,
                    active: t.slug == active,
                    onTap: () => onSelect(t.slug),
                  ),
                  flexible: fit.partial && i == shown.length - 1,
                ),
              ],
              if (overflow) ...[
                if (cramped) Gap(gap.w) else const Spacer(),
                _Tab(
                  label: moreLabel,
                  active: false,
                  trailing: Icons.expand_more,
                  onTap: () => _openAll(context),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAll(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colour.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) =>
          _ClassificationSheet(title: title, tabs: tabs, active: active),
    );
    if (picked == null || picked == active) return;
    onSelect(picked.isEmpty ? null : picked);
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final IconData? trailing;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.active,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: ClassificationTabs.tabMaxWidth.w),
    child: Material(
      color: active ? Colour.surface : Colors.transparent,
      elevation: active ? 1 : 0,
      shadowColor: Colour.textPrimary.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(8.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.r),
        onTap: onTap,
        child: Container(
          height: 36.h,
          padding: EdgeInsets.symmetric(
            horizontal: ClassificationTabs.tabPadding.w,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ClassificationTabs._style.copyWith(
                    color: active ? Colour.textPrimary : Colour.textSecondary,
                  ),
                ),
              ),
              if (trailing != null) ...[
                Gap(6.r),
                Icon(trailing, size: 18.r, color: Colour.textSecondary),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Danh sách đủ classification (nút "More"): ô tìm khi dài, chọn → đóng và trả slug
/// ('' = All).
class _ClassificationSheet extends StatefulWidget {
  final String title;
  final List<MarketClassificationFacet> tabs;
  final String active;

  const _ClassificationSheet({
    required this.title,
    required this.tabs,
    required this.active,
  });

  @override
  State<_ClassificationSheet> createState() => _ClassificationSheetState();
}

class _ClassificationSheetState extends State<_ClassificationSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = (
      slug: '',
      label: LocaleKeys.marketListingAllClassifications.tr(),
    );
    final options = [
      all,
      for (final t in widget.tabs) (slug: t.slug, label: t.name),
    ];
    final q = _query.trim().toLowerCase();
    final listed = options
        .where((o) => q.isEmpty || o.label.toLowerCase().contains(q))
        .toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 12.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: AppTextStyle.lightBodyXLargeSemiBold.copyWith(
                          color: Colour.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        size: 20.r,
                        color: Colour.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colour.lineSubtle),
              if (options.length > ClassificationTabs.searchFrom)
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 20.r),
                      hintText: LocaleKeys.marketListingClassificationsSearch
                          .tr(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
              Flexible(
                child: listed.isEmpty
                    ? Padding(
                        padding: EdgeInsets.all(16.r),
                        child: Text(
                          LocaleKeys.marketListingClassificationsEmpty.tr(),
                          style: AppTextStyle.lightBodyMediumRegular.copyWith(
                            color: Colour.textTertiary,
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 8.h,
                        ),
                        children: [
                          for (final o in listed)
                            _Option(
                              label: o.label,
                              active: o.slug == widget.active,
                              onTap: () => Navigator.pop(context, o.slug),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dòng lựa chọn (web `OptionItem`): đang chọn nền ocean nhạt + dấu check.
class _Option extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Option({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: active
        ? Colour.buttonPrimary.withValues(alpha: 0.1)
        : Colors.transparent,
    borderRadius: BorderRadius.circular(12.r),
    child: InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 44.h),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style:
                      (active
                              ? AppTextStyle.lightBodyLargeMedium
                              : AppTextStyle.lightBodyLargeRegular)
                          .copyWith(
                            color: active
                                ? Colour.buttonPrimary
                                : Colour.textSecondary,
                          ),
                ),
              ),
              if (active)
                Icon(Icons.check, size: 16.r, color: Colour.buttonPrimary),
            ],
          ),
        ),
      ),
    ),
  );
}
