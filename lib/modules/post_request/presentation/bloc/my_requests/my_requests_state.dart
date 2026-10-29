part of 'my_requests_bloc.dart';

/// signedOut: chưa đăng nhập → hiện lời nhắc đăng nhập thay cho danh sách.
enum MyRequestsStatus { initial, loading, success, failure, signedOut }

/// Active = pending + active; Closed = closed / expired / canceled.
enum MyRequestsTab { active, closed }

class MyRequestsState extends Equatable {
  final MyRequestsStatus status;
  final MyRequestsTab tab;
  final List<MyRequestEntity> items;

  /// Offer theo `request_id` — chỉ tải cho request có `offers_count > 0`.
  final Map<int, List<RequestOfferEntity>> offers;

  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  const MyRequestsState({
    this.status = MyRequestsStatus.initial,
    this.tab = MyRequestsTab.active,
    this.items = const [],
    this.offers = const {},
    this.page = 1,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  /// Coi `initial` như đang tải để frame đầu không hiện empty state.
  bool get isFirstLoad =>
      status == MyRequestsStatus.initial || status == MyRequestsStatus.loading;

  /// Đã có ít nhất một request (tab nào cũng được).
  bool get hasAnyRequest => items.isNotEmpty || hasMore;

  /// Tab Active | Closed chỉ hiện khi đã đăng nhập và có request (hoặc đang tải).
  bool get showTabs =>
      status != MyRequestsStatus.signedOut &&
      status != MyRequestsStatus.failure &&
      (isFirstLoad || hasAnyRequest);

  /// Request của tab đang chọn (giữ thứ tự mới nhất trước của API).
  List<MyRequestEntity> get visibleItems =>
      items.where((r) => r.isClosed == (tab == MyRequestsTab.closed)).toList();

  MyRequestsState copyWith({
    MyRequestsStatus? status,
    MyRequestsTab? tab,
    List<MyRequestEntity>? items,
    Map<int, List<RequestOfferEntity>>? offers,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
  }) {
    return MyRequestsState(
      status: status ?? this.status,
      tab: tab ?? this.tab,
      items: items ?? this.items,
      offers: offers ?? this.offers,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    tab,
    items,
    offers,
    page,
    hasMore,
    isLoadingMore,
    errorMessage,
  ];
}
