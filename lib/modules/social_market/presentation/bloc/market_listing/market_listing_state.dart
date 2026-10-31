part of 'market_listing_bloc.dart';

enum ListingStatus { initial, loading, success, failure }

class MarketListingState<T> extends Equatable {
  final ListingStatus status;
  final List<T> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreError;

  const MarketListingState({
    this.status = ListingStatus.initial,
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreError = false,
  });

  bool get isFirstLoad =>
      status == ListingStatus.initial || status == ListingStatus.loading;

  MarketListingState<T> copyWith({
    List<T>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreError,
  }) => MarketListingState<T>(
    status: status,
    items: items ?? this.items,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: loadMoreError ?? this.loadMoreError,
  );

  @override
  List<Object?> get props => [
    status,
    items,
    page,
    hasMore,
    loadingMore,
    loadMoreError,
  ];
}
