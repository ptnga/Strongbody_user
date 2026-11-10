import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/core/utils/language_names.dart';
import 'package:strongbody_buyer/core/utils/plural_tr.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/widgets/voice/get_help_sheet.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_ui.dart';

import '../../../domain/entities/board_entities.dart';
import '../../bloc/board/board_cubit.dart';
import 'board_filter_sheet.dart';

/// Chủ đề của board Requests (`category_id`, web `topics`).
const boardTopics = <({int id, String key})>[
  (id: 96655, key: 'longevity'),
  (id: 96656, key: 'medicalTravel'),
  (id: 96657, key: 'healthPro'),
  (id: 96658, key: 'personalHelper'),
];

String _topicLabel(String key) => switch (key) {
  'longevity' => LocaleKeys.boardTopicLongevity.tr(),
  'medicalTravel' => LocaleKeys.boardTopicMedicalTravel.tr(),
  'healthPro' => LocaleKeys.boardTopicHealthPro.tr(),
  _ => LocaleKeys.boardTopicPersonalHelper.tr(),
};

/// Một board (web `BoardFrame` + feed): tiêu đề → (chủ đề) → ô tìm + "Filters" → hàng
/// bộ lọc đang dùng → danh sách cuộn tải thêm → trạng thái trống / lỗi.
class BoardView<T> extends StatefulWidget {
  final BoardKind kind;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Gọi khi danh sách có item mới (tải số đếm like / save…).
  final void Function(List<T> items)? onItems;

  const BoardView({
    super.key,
    required this.kind,
    required this.itemBuilder,
    this.onItems,
  });

  @override
  State<BoardView<T>> createState() => _BoardViewState<T>();
}

class _BoardViewState<T> extends State<BoardView<T>>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;

  bool get _requests => widget.kind == BoardKind.requests;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final p = _scroll.position;
      // Như web: tải trước khi chạm đáy (~800px).
      if (p.pixels >= p.maxScrollExtent - 800) {
        context.read<BoardCubit<T>>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => context.read<BoardCubit<T>>().search(text),
    );
  }

  Future<void> _openFilters(BoardState<T> state) async {
    final cubit = context.read<BoardCubit<T>>();
    final next = await showBoardFilterSheet(
      context,
      kind: widget.kind,
      current: state.filters,
      countries: state.countries,
      countryCounts: state.countryCounts,
      languages: state.languages,
    );
    if (next == null) return;
    await cubit.applyFilters(next);
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _postRequest() => showGetHelpSheet(context, source: 'home_board');

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocConsumer<BoardCubit<T>, BoardState<T>>(
      listenWhen: (a, b) => a.items != b.items,
      listener: (context, state) => widget.onItems?.call(state.items),
      builder: (context, state) {
        if (state.keyword.isEmpty && _search.text.isNotEmpty) _search.clear();
        return RefreshIndicator(
          onRefresh: context.read<BoardCubit<T>>().retry,
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 96.h),
            children: [
              _header(),
              if (_requests) ...[Gap(12.h), _topics(state)],
              Gap(12.h),
              _toolbar(state),
              if (state.isSearching && state.status == BoardStatus.success)
                _activeFilters(state),
              Gap(12.h),
              ..._content(state),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    final title = _requests
        ? LocaleKeys.boardRequestsTitle.tr()
        : LocaleKeys.boardOffersTitle.tr();
    final desc = _requests
        ? LocaleKeys.boardRequestsDesc.tr()
        : LocaleKeys.boardOffersDesc.tr();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyle.lightHeadingXSmall.copyWith(
                  color: Colour.textPrimary,
                ),
              ),
            ),
            if (_requests)
              MarketButton(
                label: LocaleKeys.boardRequestsPost.tr(),
                onPressed: _postRequest,
              ),
          ],
        ),
        Gap(4.h),
        Text(
          desc,
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            color: Colour.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _topics(BoardState<T> state) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final t in boardTopics) ...[
          _Pill(
            label: _topicLabel(t.key),
            selected: state.topicId == t.id,
            onTap: () {
              _search.clear();
              context.read<BoardCubit<T>>().toggleTopic(t.id);
            },
          ),
          Gap(8.w),
        ],
      ],
    ),
  );

  Widget _toolbar(BoardState<T> state) {
    final active = state.filters.activeCount;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44.h,
            child: TextField(
              controller: _search,
              maxLength: 200,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (text) {
                _debounce?.cancel();
                context.read<BoardCubit<T>>().search(text);
              },
              style: AppTextStyle.lightBodyMediumRegular.copyWith(
                color: Colour.textPrimary,
              ),
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                hintText: _requests
                    ? LocaleKeys.boardSearchRequests.tr()
                    : LocaleKeys.boardSearchOffers.tr(),
                hintStyle: AppTextStyle.lightBodyMediumRegular.copyWith(
                  color: Colour.textTertiary,
                ),
                prefixIcon: Icon(Icons.search_rounded, size: 20.r),
                filled: true,
                fillColor: Colour.surface,
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Colour.lineStrong),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Colour.lineStrong),
                ),
              ),
            ),
          ),
        ),
        Gap(8.w),
        SizedBox(
          height: 44.h,
          child: OutlinedButton.icon(
            onPressed: () => _openFilters(state),
            style: OutlinedButton.styleFrom(
              foregroundColor: active > 0
                  ? Colour.buttonPrimary
                  : Colour.textPrimary,
              side: BorderSide(
                color: active > 0 ? Colour.buttonPrimary : Colour.lineStrong,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              textStyle: AppTextStyle.lightBodyMediumMedium,
            ),
            icon: Icon(Icons.tune_rounded, size: 18.r),
            label: Text(
              active > 0
                  ? '${LocaleKeys.boardFiltersButton.tr()} ($active)'
                  : LocaleKeys.boardFiltersButton.tr(),
            ),
          ),
        ),
      ],
    );
  }

  /// "{n} results" · chip từng bộ lọc (bỏ được) · "Clear filters".
  Widget _activeFilters(BoardState<T> state) {
    final cubit = context.read<BoardCubit<T>>();
    final f = state.filters;
    final chips = <(String, Widget?, BoardFilters)>[
      if (f.country != null)
        (
          f.country!.title,
          f.country!.flag == null ? null : CountryFlag(f.country!.flag),
          _copy(f, country: null),
        ),
      if (f.sort != null)
        (boardSortLabel(widget.kind, f.sort!), null, _copy(f, sort: null)),
      if (f.postedDays != null)
        (boardPostedLabel(f.postedDays!), null, _copy(f, postedDays: null)),
      if (f.delivery != null)
        (boardDeliveryLabel(f.delivery!), null, _copy(f, delivery: null)),
      if (f.price != null)
        (boardPriceLabel(f.price!), null, _copy(f, price: null)),
      if (f.noResponses)
        (
          LocaleKeys.boardResponsesNone.tr(),
          null,
          _copy(f, noResponses: false),
        ),
      if (f.verified)
        (LocaleKeys.boardExtraVerified.tr(), null, _copy(f, verified: false)),
      if (f.free) (LocaleKeys.boardExtraFree.tr(), null, _copy(f, free: false)),
      if (f.language != null)
        (languageLabel(f.language!), null, _copy(f, language: null)),
    ];
    final total = state.total;
    return Padding(
      padding: EdgeInsets.only(top: 10.h),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (total != null)
            Text(
              pluralTr(
                total,
                one: LocaleKeys.boardFiltersResultsOne,
                other: LocaleKeys.boardFiltersResultsOther,
              ),
              style: AppTextStyle.lightBodySmallMedium.copyWith(
                color: Colour.textSecondary,
              ),
            ),
          for (final (label, leading, next) in chips)
            InputChip(
              avatar: leading,
              label: Text(label),
              labelStyle: AppTextStyle.lightBodySmallMedium.copyWith(
                color: Colour.textPrimary,
              ),
              backgroundColor: Colour.subtle,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
              onDeleted: () => cubit.applyFilters(next),
            ),
          if (chips.isNotEmpty)
            GestureDetector(
              onTap: cubit.clearFilters,
              child: Text(
                LocaleKeys.boardFiltersClearAll.tr(),
                style: AppTextStyle.lightBodySmallMedium.copyWith(
                  color: Colour.textPrimary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const _keep = Object();

  BoardFilters _copy(
    BoardFilters f, {
    Object? sort = _keep,
    Object? postedDays = _keep,
    Object? delivery = _keep,
    Object? price = _keep,
    bool? noResponses,
    bool? verified,
    bool? free,
    Object? language = _keep,
    Object? country = _keep,
  }) => BoardFilters(
    sort: sort == _keep ? f.sort : sort as String?,
    postedDays: postedDays == _keep ? f.postedDays : postedDays as int?,
    delivery: delivery == _keep ? f.delivery : delivery as String?,
    price: price == _keep ? f.price : price as ({int? min, int? max})?,
    noResponses: noResponses ?? f.noResponses,
    verified: verified ?? f.verified,
    free: free ?? f.free,
    language: language == _keep ? f.language : language as String?,
    country: country == _keep ? f.country : country as BoardCountry?,
  );

  List<Widget> _content(BoardState<T> state) {
    if (state.isFirstLoad) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32.h),
          child: const Center(child: CupertinoActivityIndicator()),
        ),
      ];
    }
    if (state.status == BoardStatus.failure) {
      return [
        MarketSectionError(
          title: LocaleKeys.boardSectionError.tr(),
          onRetry: context.read<BoardCubit<T>>().retry,
        ),
      ];
    }
    if (state.items.isEmpty) return [_empty(state)];
    return [
      AbsorbPointer(
        absorbing: state.reloading,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: state.reloading ? 0.5 : 1,
          child: Column(
            children: [
              for (final (i, item) in state.items.indexed) ...[
                if (i > 0) Gap(12.h),
                widget.itemBuilder(context, item),
              ],
            ],
          ),
        ),
      ),
      if (state.loadingMore)
        Padding(
          padding: EdgeInsets.only(top: 16.h),
          child: const Center(child: CupertinoActivityIndicator()),
        )
      else if (state.loadMoreFailed)
        Padding(
          padding: EdgeInsets.only(top: 16.h),
          child: Column(
            children: [
              Text(
                LocaleKeys.boardFeedError.tr(),
                style: AppTextStyle.lightBodySmallRegular.copyWith(
                  color: Colour.textSecondary,
                ),
              ),
              Gap(8.h),
              OutlinedButton(
                onPressed: context.read<BoardCubit<T>>().loadMore,
                child: Text(LocaleKeys.boardFeedRetry.tr()),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _empty(BoardState<T> state) {
    final cubit = context.read<BoardCubit<T>>();
    final country = state.filters.country;
    final filtered = state.keyword.isNotEmpty || state.filters.needsSearch;
    final title = filtered
        ? LocaleKeys.boardFiltersNoResults.tr()
        : country != null
        ? (_requests
              ? LocaleKeys.boardEmptyRequests.tr(
                  namedArgs: {'country': country.title},
                )
              : LocaleKeys.boardEmptyOffers.tr(
                  namedArgs: {'country': country.title},
                ))
        : (_requests
              ? LocaleKeys.boardEmptyRequestsAll.tr()
              : LocaleKeys.boardEmptyOffersAll.tr());
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colour.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colour.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.travel_explore_rounded,
            size: 32.r,
            color: Colour.textTertiary,
          ),
          Gap(10.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
              color: Colour.textPrimary,
            ),
          ),
          Gap(6.h),
          Text(
            LocaleKeys.boardEmptyHint.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyle.lightBodyMediumRegular.copyWith(
              color: Colour.textSecondary,
            ),
          ),
          Gap(16.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            alignment: WrapAlignment.center,
            children: [
              if (filtered)
                MarketButton(
                  label: LocaleKeys.boardFiltersClearAll.tr(),
                  variant: MarketButtonVariant.outline,
                  onPressed: () {
                    _search.clear();
                    cubit.clearFilters(keyword: true);
                  },
                )
              else if (country != null)
                MarketButton(
                  label: LocaleKeys.boardEmptySeeAll.tr(),
                  variant: MarketButtonVariant.outline,
                  onPressed: () => cubit.applyFilters(BoardFilters.none),
                ),
              MarketButton(
                label: '+ ${LocaleKeys.boardRequestsPost.tr()}',
                onPressed: _postRequest,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Colour.textPrimary : Colour.surface,
    shape: StadiumBorder(
      side: BorderSide(color: selected ? Colour.textPrimary : Colour.border),
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        child: Text(
          label,
          style: AppTextStyle.lightBodySmallMedium.copyWith(
            color: selected ? Colour.surface : Colour.textPrimary,
          ),
        ),
      ),
    ),
  );
}
