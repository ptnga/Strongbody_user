part of 'category_market_bloc.dart';

/// Các mục của trang, theo thứ tự web `CategoryPage`: [Destinations — chỉ Medical
/// Travel] · In the spotlight · Services · services theo ngôn ngữ · Experts.
enum MarketSectionKind { destinations, spotlight, services, language, experts }

enum SectionStatus { initial, loading, success, failure }

class CategoryMarketState extends Equatable {
  final MarketPageScope? scope;
  final String language;
  final Map<MarketSectionKind, SectionStatus> statuses;
  final List<MarketDestination> destinations;
  final List<MarketServiceEntity> spotlight;
  final List<MarketServiceEntity> services;
  final List<MarketServiceEntity> languageServices;
  final List<MarketExpertEntity> experts;

  const CategoryMarketState({
    this.scope,
    this.language = 'en',
    this.statuses = const {},
    this.destinations = const [],
    this.spotlight = const [],
    this.services = const [],
    this.languageServices = const [],
    this.experts = const [],
  });

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
    List<MarketServiceEntity>? spotlight,
    List<MarketServiceEntity>? services,
    List<MarketServiceEntity>? languageServices,
    List<MarketExpertEntity>? experts,
  }) => CategoryMarketState(
    scope: scope ?? this.scope,
    language: language ?? this.language,
    statuses: statuses ?? this.statuses,
    destinations: destinations ?? this.destinations,
    spotlight: spotlight ?? this.spotlight,
    services: services ?? this.services,
    languageServices: languageServices ?? this.languageServices,
    experts: experts ?? this.experts,
  );

  @override
  List<Object?> get props => [
    scope?.route,
    language,
    statuses,
    destinations,
    spotlight,
    services,
    languageServices,
    experts,
  ];
}
