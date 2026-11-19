import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../../../domain/entities/market_category.dart';
import '../../../domain/entities/market_listing_entities.dart';
import '../../../domain/entities/medical_travel_entities.dart';
import '../../../domain/usecases/social_market_use_cases.dart';

part 'category_market_event.dart';
part 'category_market_state.dart';

/// Trang của nhãn "Browse by need" — web `CategoryPage` nhánh `need` (Longevity, Mental
/// Health, Personal Helper và Medical Travel): mỗi phần tải độc lập (web stream từng
/// Suspense).
/// - [Medical Travel] Destinations ngay dưới hero.
/// - Mỗi category doanh nghiệp một section service: 1 request cho cả trang
///   (`/public/services/by-category`), category rỗng → ẩn section.
/// - Experts: doanh nghiệp thuộc category của nhãn HOẶC expert có profession của nhãn,
///   xếp `score`.
/// Services / Experts lỗi → khối "Couldn't load"; Destinations lỗi / rỗng → ẩn.
class CategoryMarketBloc
    extends BlocWithApi<CategoryMarketEvent, CategoryMarketState> {
  final GetServicesByCategoryUseCase _getServicesByCategory;
  final GetMarketExpertsUseCase _getExperts;
  final GetDestinationsUseCase _getDestinations;

  /// Số service xin mỗi section (web luôn xin số của desktop `NEED_SECTION_LIMITS` = 3
  /// để mobile / desktop dùng chung cache).
  static const servicesPerSection = 3;

  /// Số service hiện mỗi section trên mobile (`NEED_SECTION_LIMITS.services.mobile`).
  static const servicesShown = 2;

  /// Số expert (web `CATEGORY_LIMITS.experts`).
  static const expertsLimit = 9;

  CategoryMarketBloc({
    required GetServicesByCategoryUseCase getServicesByCategory,
    required GetMarketExpertsUseCase getExperts,
    required GetDestinationsUseCase getDestinations,
  }) : _getServicesByCategory = getServicesByCategory,
       _getExperts = getExperts,
       _getDestinations = getDestinations,
       super(const CategoryMarketState()) {
    on<CategoryMarketStarted>(_onStarted);
    on<CategoryMarketRefreshed>((event, emit) => _loadAll(emit, refresh: true));
    on<CategoryMarketSectionRetried>(
      (event, emit) => switch (event.section) {
        MarketSectionKind.destinations => _loadDestinations(emit),
        MarketSectionKind.experts => _loadExperts(emit),
        MarketSectionKind.services => _loadServices(emit),
      },
    );
  }

  Future<void> _onStarted(
    CategoryMarketStarted event,
    Emitter<CategoryMarketState> emit,
  ) async {
    emit(state.copyWith(scope: event.scope, language: event.language));
    await _loadAll(emit);
  }

  Future<void> _loadAll(
    Emitter<CategoryMarketState> emit, {
    bool refresh = false,
  }) => Future.wait([
    if (state.scope?.isMedicalTravel ?? false)
      _loadDestinations(emit, refresh: refresh),
    _loadServices(emit, refresh: refresh),
    _loadExperts(emit, refresh: refresh),
  ]);

  /// Section theo category (web `NeedSectionsLoader`): category chưa có service → ẩn.
  Future<void> _loadServices(
    Emitter<CategoryMarketState> emit, {
    bool refresh = false,
  }) async {
    final need = state.scope?.need;
    if (need == null) return;
    const section = MarketSectionKind.services;
    // Kéo để làm mới: giữ dữ liệu cũ trên màn trong lúc tải.
    if (!refresh) emit(state.withSection(section, SectionStatus.loading));
    await callApi(
      useCase: _getServicesByCategory,
      param: (categories: need.services, per: servicesPerSection),
      onSuccess: (sections) async => emit(
        state
            .copyWith(categorySections: visibleSections(sections))
            .withSection(section, SectionStatus.success),
      ),
      onFailure: (_) => emit(state.withSection(section, SectionStatus.failure)),
    );
  }

  /// Bỏ category rỗng, mỗi section [servicesShown] service.
  static List<MarketCategorySection> visibleSections(
    List<MarketCategorySection> sections,
  ) => [
    for (final s in sections)
      if (s.items.isNotEmpty)
        MarketCategorySection(
          category: s.category,
          total: s.total,
          items: s.items.take(servicesShown).toList(),
        ),
  ];

  /// Experts của nhãn (web `NeedExpertsLoader`, `sort=score`).
  Future<void> _loadExperts(
    Emitter<CategoryMarketState> emit, {
    bool refresh = false,
  }) async {
    final scope = state.scope;
    if (scope == null) return;
    const section = MarketSectionKind.experts;
    if (!refresh) emit(state.withSection(section, SectionStatus.loading));
    await callApi(
      useCase: _getExperts,
      param: MarketPageParams(
        scope: scope,
        categorySlug: scope.slug,
        limit: expertsLimit,
      ),
      onSuccess: (page) async => emit(
        state
            .copyWith(experts: page.items.take(expertsLimit).toList())
            .withSection(section, SectionStatus.success),
      ),
      onFailure: (_) => emit(state.withSection(section, SectionStatus.failure)),
    );
  }

  Future<void> _loadDestinations(
    Emitter<CategoryMarketState> emit, {
    bool refresh = false,
  }) async {
    const section = MarketSectionKind.destinations;
    if (!refresh) emit(state.withSection(section, SectionStatus.loading));
    await callApi(
      useCase: _getDestinations,
      param: const NoParams(),
      onSuccess: (items) async => emit(
        state
            .copyWith(destinations: items)
            .withSection(section, SectionStatus.success),
      ),
      onFailure: (_) => emit(state.withSection(section, SectionStatus.failure)),
    );
  }
}
