part of 'category_market_bloc.dart';

/// Các phần của trang nhãn, theo thứ tự web `CategoryPage`: [Destinations — chỉ Medical
/// Travel] · các section theo category doanh nghiệp · Experts.
enum MarketSectionKind { destinations, services, experts }

enum SectionStatus { initial, loading, success, failure }

class CategoryMarketState extends Equatable {
  final MarketPageScope? scope;
  final String language;
  final Map<MarketSectionKind, SectionStatus> statuses;
  final List<MarketDestination> destinations;

  /// Section service theo category doanh nghiệp (đã bỏ category rỗng).
  final List<MarketCategorySection> categorySections;
  final List<MarketExpertEntity> experts;

  const CategoryMarketState({
    this.scope,
    this.language = 'en',
    this.statuses = const {},
    this.destinations = const [],
    this.categorySections = const [],
    this.experts = const [],
  });

  /// Mọi service đang hiện (nạp số engagement).
  Iterable<int?> get serviceIds =>
      categorySections.expand((s) => s.items).map((s) => s.id);

  SectionStatus status(MarketSectionKind section) =>
      statuses[section] ?? SectionStatus.initial;

  /// initial cũng coi là đang tải (skeleton ngay lần đầu).
  bool isLoading(MarketSectionKind section) {
    final s = status(section);
    return s == SectionStatus.initial || s == SectionStatus.loading;
  }

  /// Mục có trên trang này (Destinations chỉ Medical Travel).
  List<MarketSectionKind> get sections => [
    for (final k in MarketSectionKind.values)
      if (k != MarketSectionKind.destinations ||
          (scope?.isMedicalTravel ?? false))
        k,
  ];

  CategoryMarketState withSection(
    MarketSectionKind section,
    SectionStatus status,
  ) => copyWith(statuses: {...statuses, section: status});

  CategoryMarketState withSections(
    Iterable<MarketSectionKind> sections,
    SectionStatus status,
  ) => copyWith(statuses: {...statuses, for (final s in sections) s: status});

  CategoryMarketState copyWith({
    MarketPageScope? scope,
    String? language,
    Map<MarketSectionKind, SectionStatus>? statuses,
    List<MarketDestination>? destinations,
    List<MarketCategorySection>? categorySections,
    List<MarketExpertEntity>? experts,
  }) => CategoryMarketState(
    scope: scope ?? this.scope,
    language: language ?? this.language,
    statuses: statuses ?? this.statuses,
    destinations: destinations ?? this.destinations,
    categorySections: categorySections ?? this.categorySections,
    experts: experts ?? this.experts,
  );

  @override
  List<Object?> get props => [
    scope?.route,
    language,
    statuses,
    destinations,
    categorySections,
    experts,
  ];
}
