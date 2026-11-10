import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/core/utils/language_names.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_ui.dart';

import '../../../domain/entities/board_entities.dart';

/// Một lựa chọn trong nhóm lọc.
typedef _Option<V> = ({V value, String label});

/// Popup "Filters" của board (web `BoardFilterDialog`): mỗi nhóm một giá trị, chạm lại
/// để bỏ; thay đổi chỉ là nháp tới khi bấm "Show results". "Reset" bỏ bộ lọc + nước
/// (giữ từ khoá).
Future<BoardFilters?> showBoardFilterSheet(
  BuildContext context, {
  required BoardKind kind,
  required BoardFilters current,
  required List<BoardCountry>? countries,
  Map<int, int>? countryCounts,
  List<String>? languages,
}) => showModalBottomSheet<BoardFilters>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _FilterSheet(
    kind: kind,
    current: current,
    countries: countries,
    countryCounts: countryCounts,
    languages: languages,
  ),
);

/// Khoảng giá USD (web `filters.price`).
const boardPriceRanges = <({String key, int? min, int? max})>[
  (key: 'under50', min: null, max: 50),
  (key: '50to200', min: 50, max: 200),
  (key: '200to1000', min: 200, max: 1000),
  (key: 'over1000', min: 1000, max: null),
];

String boardPriceLabel(({int? min, int? max}) range) =>
    switch ((range.min, range.max)) {
      (null, 50) => LocaleKeys.boardPriceUnder50.tr(),
      (50, 200) => LocaleKeys.boardPrice50to200.tr(),
      (200, 1000) => LocaleKeys.boardPrice200to1000.tr(),
      _ => LocaleKeys.boardPriceOver1000.tr(),
    };

String boardSortLabel(BoardKind kind, String sort) => switch (sort) {
  'newest' => LocaleKeys.boardSortNewest.tr(),
  'relevance' => LocaleKeys.boardSortRelevance.tr(),
  'least_responses' => LocaleKeys.boardSortLeastResponses.tr(),
  'soonest' => LocaleKeys.boardSortSoonest.tr(),
  // Request: price_desc = "Highest budget".
  'price_desc' when kind == BoardKind.requests =>
    LocaleKeys.boardSortBudgetDesc.tr(),
  'price_desc' => LocaleKeys.boardSortPriceDesc.tr(),
  'price_asc' => LocaleKeys.boardSortPriceAsc.tr(),
  'rating' => LocaleKeys.boardSortRating.tr(),
  _ => LocaleKeys.boardSortPopular.tr(),
};

String boardPostedLabel(int days) => switch (days) {
  1 => LocaleKeys.boardPostedToday.tr(),
  7 => LocaleKeys.boardPostedWeek.tr(),
  _ => LocaleKeys.boardPostedMonth.tr(),
};

String boardDeliveryLabel(String delivery) => switch (delivery) {
  'remote' => LocaleKeys.boardFilterOnline.tr(),
  'at_home' => LocaleKeys.boardFilterAtHome.tr(),
  'at_clinic' => LocaleKeys.boardFilterAtClinic.tr(),
  _ => LocaleKeys.boardFilterAtOffice.tr(),
};

class _FilterSheet extends StatefulWidget {
  final BoardKind kind;
  final BoardFilters current;
  final List<BoardCountry>? countries;
  final Map<int, int>? countryCounts;
  final List<String>? languages;

  const _FilterSheet({
    required this.kind,
    required this.current,
    required this.countries,
    this.countryCounts,
    this.languages,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late BoardFilters _draft = widget.current;

  bool get _requests => widget.kind == BoardKind.requests;

  /// Ngôn ngữ mặc định khi chưa có facet (web).
  static const _fallbackLanguages = ['en', 'vi', 'es', 'fr', 'de', 'it', 'pt'];

  void _set(BoardFilters next) => setState(() => _draft = next);

  /// Tạo bản lọc mới đổi một nhóm (nhóm khác giữ nguyên).
  BoardFilters _with({
    Object? sort = _keep,
    Object? postedDays = _keep,
    Object? delivery = _keep,
    Object? price = _keep,
    bool? noResponses,
    bool? verified,
    bool? free,
    Object? language = _keep,
    Object? country = _keep,
  }) {
    final d = _draft;
    return BoardFilters(
      sort: sort == _keep ? d.sort : sort as String?,
      postedDays: postedDays == _keep ? d.postedDays : postedDays as int?,
      delivery: delivery == _keep ? d.delivery : delivery as String?,
      price: price == _keep ? d.price : price as ({int? min, int? max})?,
      noResponses: noResponses ?? d.noResponses,
      verified: verified ?? d.verified,
      free: free ?? d.free,
      language: language == _keep ? d.language : language as String?,
      country: country == _keep ? d.country : country as BoardCountry?,
    );
  }

  static const _keep = Object();

  @override
  Widget build(BuildContext context) {
    final d = _draft;
    final sorts = _requests
        ? ['newest', 'relevance', 'least_responses', 'soonest', 'price_desc']
        : [
            'newest',
            'relevance',
            'price_asc',
            'price_desc',
            'rating',
            'popular',
          ];
    final posted = _requests ? [1, 7, 30] : [7, 30];
    final deliveries = _requests
        ? ['remote', 'at_office', 'at_clinic', 'at_home']
        : ['remote', 'at_home', 'at_office'];
    final languages = (widget.languages?.isNotEmpty ?? false)
        ? widget.languages!
        : _fallbackLanguages;
    final countries = widget.countries;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 0.85.sh),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _requests
                      ? LocaleKeys.boardFiltersTitleRequests.tr()
                      : LocaleKeys.boardFiltersTitleOffers.tr(),
                  style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
                    color: Colour.textPrimary,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                children: [
                  _group<String>(
                    LocaleKeys.boardGroupSort.tr(),
                    [
                      for (final s in sorts)
                        (value: s, label: boardSortLabel(widget.kind, s)),
                    ],
                    d.sort,
                    (v) => _set(_with(sort: v)),
                  ),
                  _group<int>(
                    LocaleKeys.boardGroupPosted.tr(),
                    [
                      for (final p in posted)
                        (value: p, label: boardPostedLabel(p)),
                    ],
                    d.postedDays,
                    (v) => _set(_with(postedDays: v)),
                  ),
                  _group<String>(
                    LocaleKeys.boardGroupDelivery.tr(),
                    [
                      for (final x in deliveries)
                        (value: x, label: boardDeliveryLabel(x)),
                    ],
                    d.delivery,
                    (v) => _set(_with(delivery: v)),
                  ),
                  _group<({int? min, int? max})>(
                    _requests
                        ? LocaleKeys.boardGroupBudget.tr()
                        : LocaleKeys.boardGroupPrice.tr(),
                    [
                      for (final r in boardPriceRanges)
                        (
                          value: (min: r.min, max: r.max),
                          label: boardPriceLabel((min: r.min, max: r.max)),
                        ),
                    ],
                    d.price,
                    (v) => _set(_with(price: v)),
                  ),
                  if (_requests)
                    _group<bool>(
                      LocaleKeys.boardGroupResponses.tr(),
                      [
                        (
                          value: true,
                          label: LocaleKeys.boardResponsesNone.tr(),
                        ),
                      ],
                      d.noResponses ? true : null,
                      (v) => _set(_with(noResponses: v ?? false)),
                    )
                  else ...[
                    _group<String>(
                      LocaleKeys.boardGroupExtra.tr(),
                      [
                        (
                          value: 'verified',
                          label: LocaleKeys.boardExtraVerified.tr(),
                        ),
                        (value: 'free', label: LocaleKeys.boardExtraFree.tr()),
                      ],
                      d.verified ? 'verified' : (d.free ? 'free' : null),
                      (v) => _set(
                        _with(verified: v == 'verified', free: v == 'free'),
                      ),
                    ),
                    _group<String>(
                      LocaleKeys.boardGroupLanguage.tr(),
                      [
                        for (final code in languages)
                          (value: code, label: languageLabel(code)),
                      ],
                      d.language,
                      (v) => _set(_with(language: v)),
                    ),
                  ],
                  _countryGroup(countries, d.country),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colour.lineSubtle)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46.h,
                      child: OutlinedButton(
                        onPressed: d.isEmpty
                            ? null
                            : () => _set(BoardFilters.none),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colour.textPrimary,
                          side: const BorderSide(color: Colour.lineStrong),
                        ),
                        child: Text(LocaleKeys.boardFiltersReset.tr()),
                      ),
                    ),
                  ),
                  Gap(10.w),
                  Expanded(
                    child: SizedBox(
                      height: 46.h,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(_draft),
                        child: Text(LocaleKeys.boardFiltersApply.tr()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countryGroup(List<BoardCountry>? countries, BoardCountry? selected) {
    if (countries == null) {
      return _section(
        LocaleKeys.boardGroupCountry.tr(),
        Text(
          LocaleKeys.boardCountriesUnavailable.tr(),
          style: AppTextStyle.lightBodySmallRegular.copyWith(
            color: Colour.textSecondary,
          ),
        ),
      );
    }
    final counts = widget.countryCounts;
    return _section(
      LocaleKeys.boardGroupCountry.tr(),
      Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          for (final c in countries)
            _FilterChip(
              label: '${c.title} (${counts?[c.id] ?? c.count})',
              leading: c.flag == null ? null : CountryFlag(c.flag),
              selected: selected?.id == c.id,
              onTap: () =>
                  _set(_with(country: selected?.id == c.id ? null : c)),
            ),
        ],
      ),
    );
  }

  Widget _group<V>(
    String title,
    List<_Option<V>> options,
    V? selected,
    ValueChanged<V?> onChanged,
  ) => _section(
    title,
    Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final o in options)
          _FilterChip(
            label: o.label,
            selected: o.value == selected,
            onTap: () => onChanged(o.value == selected ? null : o.value),
          ),
      ],
    ),
  );

  Widget _section(String title, Widget child) => Padding(
    padding: EdgeInsets.only(top: 16.h),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
            color: Colour.textPrimary,
          ),
        ),
        Gap(8.h),
        child,
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget? leading;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Colour.textPrimary : Colour.surface,
    shape: StadiumBorder(
      side: BorderSide(
        color: selected ? Colour.textPrimary : Colour.lineStrong,
      ),
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, Gap(6.w)],
            Text(
              label,
              style: AppTextStyle.lightBodySmallMedium.copyWith(
                color: selected ? Colour.surface : Colour.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
