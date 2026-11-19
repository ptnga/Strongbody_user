import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';

import '../../../domain/entities/market_listing_entities.dart';

part 'market_listing_event.dart';
part 'market_listing_state.dart';

/// Tải trang [page] của listing với bộ lọc phụ [filter] (listing service của trang nhãn:
/// slug tab service classification; null = "All").
typedef MarketPageFetcher<T> =
    Future<Either<Failure, MarketPage<T>>> Function(int page, String? filter);

/// Listing "View all" (web `/services/{category}`, `/providers/{category}`): trang 1
/// rồi tự tải trang kế khi cuộn gần cuối (web `useLoadMore` + `useAutoLoadMore`),
/// bỏ trùng theo id; lỗi tải thêm → nút "Try again". Đổi tab classification → tải lại
/// từ trang 1 với bộ lọc mới.
class MarketListingBloc<T>
    extends Bloc<MarketListingEvent, MarketListingState<T>> {
  /// Mỗi lần tải 10 bản ghi (web `LISTING_PAGE_SIZE`).
  static const pageSize = 10;

  final MarketPageFetcher<T> _fetch;
  final Object? Function(T item) _idOf;

  MarketListingBloc({
    required MarketPageFetcher<T> fetch,
    required Object? Function(T item) idOf,
    String? filter,
  }) : _fetch = fetch,
       _idOf = idOf,
       super(MarketListingState<T>(filter: filter)) {
    on<MarketListingStarted>((event, emit) => _first(emit));
    on<MarketListingRefreshed>((event, emit) => _first(emit, refresh: true));
    on<MarketListingFilterChanged>((event, emit) async {
      if (event.filter != state.filter) {
        await _first(emit, filter: () => event.filter);
      }
    });
    on<MarketListingNextPageRequested>(_onNext);
  }

  Future<void> _first(
    Emitter<MarketListingState<T>> emit, {
    bool refresh = false,
    String? Function()? filter,
  }) async {
    final f = filter == null ? state.filter : filter();
    if (!refresh) {
      emit(MarketListingState<T>(status: ListingStatus.loading, filter: f));
    }
    final result = await _fetch(1, f);
    // Đổi tab trong lúc chờ → bỏ kết quả của tab cũ.
    if (state.filter != f) return;
    result.fold(
      (_) => emit(
        refresh
            ? state.copyWith(loadMoreError: false)
            : MarketListingState<T>(status: ListingStatus.failure, filter: f),
      ),
      (page) => emit(
        MarketListingState<T>(
          status: ListingStatus.success,
          filter: f,
          items: page.items,
          page: 1,
          hasMore: page.items.isNotEmpty && 1 < page.totalPages,
        ),
      ),
    );
  }

  Future<void> _onNext(
    MarketListingNextPageRequested event,
    Emitter<MarketListingState<T>> emit,
  ) async {
    if (!state.hasMore || state.loadingMore) return;
    if (state.loadMoreError && !event.retry) return;
    final f = state.filter;
    emit(state.copyWith(loadingMore: true, loadMoreError: false));
    final next = state.page + 1;
    final result = await _fetch(next, f);
    if (state.filter != f) return;
    result.fold(
      (_) => emit(state.copyWith(loadingMore: false, loadMoreError: true)),
      (page) {
        final seen = state.items.map(_idOf).toSet();
        final fresh = page.items.where((i) {
          final id = _idOf(i);
          return id == null || !seen.contains(id);
        });
        emit(
          state.copyWith(
            items: [...state.items, ...fresh],
            page: next,
            hasMore: page.items.isNotEmpty && next < page.totalPages,
            loadingMore: false,
          ),
        );
      },
    );
  }
}
