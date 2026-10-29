part of 'matching_providers_bloc.dart';

enum MatchingProvidersStatus { initial, loading, success, failure }

/// Chip lọc ở đầu màn. Chip nào hiện tuỳ request có thông tin tương ứng.
enum ProviderFilter { delivery, dates, budget, language, topRated }

/// Thông tin từ request dùng để tạo chip lọc ("At home", "This weekend", "Under $70"…).
class ProviderRequestContext extends Equatable {
  final List<RequestDeliveryType> deliveryTypes;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? maxBudget;
  final String currency;

  /// Ngôn ngữ người dùng muốn provider nói (khác tiếng Anh) → chip "Speaks …".
  final String? languageCode;

  /// Tóm tắt request nối sau từ khoá trong ô tìm kiếm, vd "At home · Sat 31 Oct".
  final String summary;

  const ProviderRequestContext({
    this.deliveryTypes = const [],
    this.startDate,
    this.endDate,
    this.maxBudget,
    this.currency = 'USD',
    this.languageCode,
    this.summary = '',
  });

  ProviderRequestContext copyWith({String? languageCode, double? maxBudget}) =>
      ProviderRequestContext(
        deliveryTypes: deliveryTypes,
        startDate: startDate,
        endDate: endDate,
        maxBudget: maxBudget ?? this.maxBudget,
        currency: currency,
        languageCode: languageCode ?? this.languageCode,
        summary: summary,
      );

  /// Chip có dữ liệu để hiện.
  List<ProviderFilter> get availableFilters => [
    if (deliveryTypes.isNotEmpty) ProviderFilter.delivery,
    if (startDate != null) ProviderFilter.dates,
    if (maxBudget != null) ProviderFilter.budget,
    if (languageCode != null) ProviderFilter.language,
    ProviderFilter.topRated,
  ];

  @override
  List<Object?> get props => [
    deliveryTypes,
    startDate,
    endDate,
    maxBudget,
    currency,
    languageCode,
    summary,
  ];
}

class MatchingProvidersState extends Equatable {
  final MatchingProvidersStatus status;
  final String keyword;
  final List<ProviderEntity> items;
  final int total;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final List<ProviderEntity> selected;
  final ProviderRequestContext context;
  final Set<ProviderFilter> activeFilters;

  /// Giá / cách cung cấp / lịch rảnh theo provider id — tải dần sau khi có danh sách.
  final Map<int, ProviderExtras> extras;
  final String? errorMessage;

  const MatchingProvidersState({
    this.status = MatchingProvidersStatus.initial,
    this.keyword = '',
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.selected = const [],
    this.context = const ProviderRequestContext(),
    this.activeFilters = const {},
    this.extras = const {},
    this.errorMessage,
  });

  /// Coi `initial` như đang tải để frame đầu không hiện empty state.
  bool get isFirstLoad =>
      status == MatchingProvidersStatus.initial ||
      status == MatchingProvidersStatus.loading;

  bool isSelected(ProviderEntity provider) =>
      selected.any((p) => p.userId == provider.userId);

  bool get hasActiveFilters =>
      activeFilters.any((f) => f != ProviderFilter.topRated);

  /// Danh sách sau khi lọc. Dữ liệu provider còn thiếu (chưa tải / chưa khai báo) thì
  /// vẫn hiện — chỉ ẩn người có dữ liệu mà không khớp.
  List<ProviderEntity> get visibleItems {
    final result = items.where(_matches).toList();
    if (activeFilters.contains(ProviderFilter.topRated)) {
      result.sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        return byRating != 0
            ? byRating
            : b.reviewCount.compareTo(a.reviewCount);
      });
    }
    return result;
  }

  bool _matches(ProviderEntity provider) {
    final e = extras[provider.id];
    if (activeFilters.contains(ProviderFilter.delivery) &&
        e != null &&
        e.deliveryTypes.isNotEmpty &&
        !e.deliveryTypes.any(context.deliveryTypes.contains)) {
      return false;
    }
    final start = context.startDate;
    if (activeFilters.contains(ProviderFilter.dates) &&
        start != null &&
        e != null &&
        e.slots.isNotEmpty &&
        !e.availableBetween(start, context.endDate ?? start)) {
      return false;
    }
    final max = context.maxBudget;
    if (activeFilters.contains(ProviderFilter.budget) &&
        max != null &&
        e?.minPrice != null &&
        e!.minPrice! > max) {
      return false;
    }
    final language = context.languageCode;
    if (activeFilters.contains(ProviderFilter.language) &&
        language != null &&
        provider.languages.isNotEmpty &&
        !provider.languages.any(
          (l) => l.toLowerCase().startsWith(language.toLowerCase()),
        )) {
      return false;
    }
    return true;
  }

  /// "N providers match your request": đang lọc thì đếm danh sách đã lọc, không thì tổng.
  int get matchCount => hasActiveFilters ? visibleItems.length : total;

  MatchingProvidersState copyWith({
    MatchingProvidersStatus? status,
    String? keyword,
    List<ProviderEntity>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    List<ProviderEntity>? selected,
    ProviderRequestContext? context,
    Set<ProviderFilter>? activeFilters,
    Map<int, ProviderExtras>? extras,
    String? errorMessage,
  }) {
    return MatchingProvidersState(
      status: status ?? this.status,
      keyword: keyword ?? this.keyword,
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      selected: selected ?? this.selected,
      context: context ?? this.context,
      activeFilters: activeFilters ?? this.activeFilters,
      extras: extras ?? this.extras,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    keyword,
    items,
    total,
    page,
    hasMore,
    isLoadingMore,
    selected,
    context,
    activeFilters,
    extras,
    errorMessage,
  ];
}
