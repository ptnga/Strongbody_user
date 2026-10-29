part of 'lion_points_bloc.dart';

enum LionPointsStatus { loading, success, failure }

class LionPointsState extends Equatable {
  final LionPointsStatus status;
  final LionWallet? wallet;
  final List<LionLedgerItem> items;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  const LionPointsState({
    this.status = LionPointsStatus.loading,
    this.wallet,
    this.items = const [],
    this.page = 1,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  LionPointsState copyWith({
    LionPointsStatus? status,
    LionWallet? wallet,
    List<LionLedgerItem>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return LionPointsState(
      status: status ?? this.status,
      wallet: wallet ?? this.wallet,
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    status,
    wallet,
    items,
    page,
    hasMore,
    isLoadingMore,
  ];
}
