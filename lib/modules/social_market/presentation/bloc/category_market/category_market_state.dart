part of 'category_market_bloc.dart';

/// Các mục của trang, theo thứ tự web: Selling · Profiles · Offers · Requests · Solutions.
enum MarketSectionKind { services, sellers, offers, requests, solutions }

enum SectionStatus { initial, loading, success, failure }

class CategoryMarketState extends Equatable {
  final MarketCategory? category;
  final Map<MarketSectionKind, SectionStatus> statuses;
  final List<MarketServiceEntity> services;
  final List<MarketExpertEntity> sellers;
  final List<MarketOfferEntity> offers;
  final List<MarketRequestEntity> requests;
  final List<HealthSolutionEntity> solutions;

  const CategoryMarketState({
    this.category,
    this.statuses = const {},
    this.services = const [],
    this.sellers = const [],
    this.offers = const [],
    this.requests = const [],
    this.solutions = const [],
  });

  SectionStatus status(MarketSectionKind section) =>
      statuses[section] ?? SectionStatus.initial;

  /// initial cũng coi là đang tải (skeleton ngay lần đầu).
  bool isLoading(MarketSectionKind section) {
    final s = status(section);
    return s == SectionStatus.initial || s == SectionStatus.loading;
  }

  CategoryMarketState withSection(
    MarketSectionKind section,
    SectionStatus status,
  ) => copyWith(statuses: {...statuses, section: status});

  CategoryMarketState loaded(MarketSectionKind section) =>
      withSection(section, SectionStatus.success);

  CategoryMarketState copyWith({
    MarketCategory? category,
    Map<MarketSectionKind, SectionStatus>? statuses,
    List<MarketServiceEntity>? services,
    List<MarketExpertEntity>? sellers,
    List<MarketOfferEntity>? offers,
    List<MarketRequestEntity>? requests,
    List<HealthSolutionEntity>? solutions,
  }) => CategoryMarketState(
    category: category ?? this.category,
    statuses: statuses ?? this.statuses,
    services: services ?? this.services,
    sellers: sellers ?? this.sellers,
    offers: offers ?? this.offers,
    requests: requests ?? this.requests,
    solutions: solutions ?? this.solutions,
  );

  @override
  List<Object?> get props => [
    category,
    statuses,
    services,
    sellers,
    offers,
    requests,
    solutions,
  ];
}
