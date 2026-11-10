part of 'my_requests_bloc.dart';

/// signedOut: chưa đăng nhập → hiện lời nhắc đăng nhập thay cho danh sách.
enum MyRequestsStatus { initial, loading, success, failure, signedOut }

/// Tab như web `/buyer/request/management`: request công khai / request gửi riêng
/// một provider — BE lọc bằng `is_private` (không lọc phía app).
enum MyRequestsTab { public, private }

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
    this.tab = MyRequestsTab.public,
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

  /// Tab đang chọn đã có ít nhất một request.
  bool get hasAnyRequest => items.isNotEmpty || hasMore;

  /// Web luôn hiện thanh Public | Private cho người đã đăng nhập (kể cả khi trống).
  bool get showTabs => status != MyRequestsStatus.signedOut;

  /// `is_private` gửi lên BE cho tab đang chọn.
  bool get isPrivate => tab == MyRequestsTab.private;

  /// Request của tab đang chọn (thứ tự của API).
  List<MyRequestEntity> get visibleItems => items;

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
