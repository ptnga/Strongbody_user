import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';

import '../../../domain/entities/board_entities.dart';
import '../../../domain/usecases/home_board_use_cases.dart';

enum BoardStatus { initial, loading, success, failure }

class BoardState<T> extends Equatable {
  final BoardStatus status;
  final List<T> items;
  final int page;
  final int totalPage;
  final bool loadingMore;
  final bool loadMoreFailed;

  /// Đổi tìm / lọc: giữ danh sách cũ (mờ, không bấm được) tới khi có kết quả mới.
  final bool reloading;
  final String keyword;
  final BoardFilters filters;
  final int? topicId;

  /// Tổng kết quả khi tìm / lọc ("{n} results").
  final int? total;

  /// Nước có item (facet DB); `null` = không tải được (ẩn nhóm Country).
  final List<BoardCountry>? countries;

  /// Số item theo nước của lần tìm gần nhất.
  final Map<int, int>? countryCounts;

  /// Offer: ngôn ngữ có kết quả (facet search).
  final List<String>? languages;

  const BoardState({
    this.status = BoardStatus.initial,
    this.items = const [],
    this.page = 0,
    this.totalPage = 0,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.reloading = false,
    this.keyword = '',
    this.filters = BoardFilters.none,
    this.topicId,
    this.total,
    this.countries,
    this.countryCounts,
    this.languages,
  });

  bool get isFirstLoad =>
      status == BoardStatus.initial || status == BoardStatus.loading;
  bool get hasMore => page < totalPage;
  bool get isSearching => keyword.trim().isNotEmpty || !filters.isEmpty;

  BoardState<T> copyWith({
    BoardStatus? status,
    List<T>? items,
    int? page,
    int? totalPage,
    bool? loadingMore,
    bool? loadMoreFailed,
    bool? reloading,
    String? keyword,
    BoardFilters? filters,
    int? topicId,
    bool clearTopic = false,
    int? total,
    bool clearTotal = false,
    List<BoardCountry>? countries,
    Map<int, int>? countryCounts,
    bool clearCountryCounts = false,
    List<String>? languages,
  }) => BoardState<T>(
    status: status ?? this.status,
    items: items ?? this.items,
    page: page ?? this.page,
    totalPage: totalPage ?? this.totalPage,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    reloading: reloading ?? this.reloading,
    keyword: keyword ?? this.keyword,
    filters: filters ?? this.filters,
    topicId: clearTopic ? null : (topicId ?? this.topicId),
    total: clearTotal ? null : (total ?? this.total),
    countries: countries ?? this.countries,
    countryCounts: clearCountryCounts
        ? null
        : (countryCounts ?? this.countryCounts),
    languages: languages ?? this.languages,
  );

  @override
  List<Object?> get props => [
    status,
    items,
    page,
    totalPage,
    loadingMore,
    loadMoreFailed,
    reloading,
    keyword,
    filters,
    topicId,
    total,
    countries,
    countryCounts,
    languages,
  ];
}

/// Một board của trang chủ (web `Boards.tsx` + `boardFeed.ts`): cuộn tải thêm 10
/// item / trang, bỏ item trùng id; đổi từ khoá / bộ lọc / chủ đề → tải lại từ trang 1
/// (kết quả của lần tải cũ bị bỏ).
class BoardCubit<T> extends Cubit<BoardState<T>> {
  final BoardKind kind;
  final Future<Either<Failure, BoardPage<T>>> Function(BoardQuery) _fetch;
  final int? Function(T item) _idOf;
  final GetBoardCountriesUseCase _getCountries;
  String _locale = 'en';
  int _run = 0;

  /// Web `BoardLoader`: seed base-36 mới mỗi lần mở board.
  String? _seed;

  BoardCubit({
    required this.kind,
    required Future<Either<Failure, BoardPage<T>>> Function(BoardQuery) fetch,
    required int? Function(T item) idOf,
    required GetBoardCountriesUseCase getCountries,
  }) : _fetch = fetch,
       _idOf = idOf,
       _getCountries = getCountries,
       super(BoardState<T>());

  Future<void> start({required String locale}) async {
    _locale = locale;
    _seed = Random().nextInt(1 << 31).toRadixString(36);
    emit(state.copyWith(status: BoardStatus.loading));
    _getCountries(kind).then((result) {
      if (isClosed) return;
      result.match((_) {}, (list) => emit(state.copyWith(countries: list)));
    });
    await _reload();
  }

  BoardQuery _query(int page) => BoardQuery(
    page: page,
    keyword: state.keyword,
    filters: state.filters,
    topicId: state.topicId,
    locale: _locale,
    seed: kind == BoardKind.offers ? _seed : null,
  );

  Future<void> _reload() async {
    final run = ++_run;
    emit(
      state.copyWith(
        reloading: state.items.isNotEmpty,
        loadMoreFailed: false,
        status: state.items.isEmpty ? BoardStatus.loading : null,
      ),
    );
    final result = await _fetch(_query(1));
    if (isClosed || run != _run) return;
    result.match(
      (_) => emit(
        state.copyWith(
          status: BoardStatus.failure,
          items: const [],
          page: 0,
          totalPage: 0,
          reloading: false,
          clearTotal: true,
        ),
      ),
      (page) => emit(
        state.copyWith(
          status: BoardStatus.success,
          items: page.items,
          page: 1,
          totalPage: page.totalPage,
          reloading: false,
          total: page.total,
          clearTotal: page.total == null,
          countryCounts: page.countryCounts,
          clearCountryCounts: page.countryCounts == null,
          languages: page.languages,
        ),
      ),
    );
  }

  Future<void> retry() => _reload();

  Future<void> loadMore() async {
    if (state.status != BoardStatus.success ||
        state.loadingMore ||
        state.reloading ||
        !state.hasMore) {
      return;
    }
    final run = _run;
    emit(state.copyWith(loadingMore: true, loadMoreFailed: false));
    final result = await _fetch(_query(state.page + 1));
    if (isClosed || run != _run) return;
    result.match(
      (_) => emit(state.copyWith(loadingMore: false, loadMoreFailed: true)),
      (page) {
        final seen = state.items.map(_idOf).toSet();
        emit(
          state.copyWith(
            items: [
              ...state.items,
              ...page.items.where((item) => !seen.contains(_idOf(item))),
            ],
            page: state.page + 1,
            totalPage: page.totalPage,
            loadingMore: false,
          ),
        );
      },
    );
  }

  /// Tìm theo từ khoá (search v2 không lọc được chủ đề → bỏ chủ đề).
  Future<void> search(String keyword) async {
    final q = keyword.trim();
    if (q == state.keyword.trim()) return;
    emit(state.copyWith(keyword: q, clearTopic: q.isNotEmpty));
    await _reload();
  }

  Future<void> applyFilters(BoardFilters filters) async {
    if (filters == state.filters) return;
    emit(state.copyWith(filters: filters));
    await _reload();
  }

  /// Chọn / bỏ chủ đề (board Requests): đang tìm / lọc thì bỏ tìm / lọc trước.
  Future<void> toggleTopic(int id) async {
    final next = state.topicId == id ? null : id;
    emit(
      state.copyWith(
        topicId: next,
        clearTopic: next == null,
        keyword: next == null ? null : '',
        filters: next == null ? null : BoardFilters.none,
      ),
    );
    await _reload();
  }

  /// "Clear filters": bỏ bộ lọc + nước ([keyword] = bỏ cả từ khoá, như ở màn trống).
  Future<void> clearFilters({bool keyword = false}) async {
    emit(
      state.copyWith(filters: BoardFilters.none, keyword: keyword ? '' : null),
    );
    await _reload();
  }
}
