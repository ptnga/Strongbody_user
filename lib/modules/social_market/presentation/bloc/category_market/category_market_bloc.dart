import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../../../domain/entities/market_category.dart';
import '../../../domain/entities/market_feed_entities.dart';
import '../../../domain/entities/market_listing_entities.dart';
import '../../../domain/usecases/social_market_use_cases.dart';

part 'category_market_event.dart';
part 'category_market_state.dart';

/// Trang Social Market của 1 category — web `MarketplacePage` (category): mỗi mục
/// tải độc lập (web stream từng Suspense), mục lỗi hiện khối "Couldn't load".
/// - Selling / Profiles lọc theo category.
/// - Offers / Requests / Solutions GIỮ NGUYÊN như trang chủ (API chưa lọc được
///   theo category provider_2026).
class CategoryMarketBloc
    extends BlocWithApi<CategoryMarketEvent, CategoryMarketState> {
  final GetMarketServicesUseCase _getServices;
  final GetMarketExpertsUseCase _getExperts;
  final GetPublicOffersUseCase _getOffers;
  final GetPublicRequestsUseCase _getRequests;
  final GetHealthSolutionsUseCase _getSolutions;

  /// Số service ở mục Selling khi lọc theo category (web `CATEGORY_SERVICES_LIMIT`).
  static const servicesLimit = 6;
  static const sellersLimit = 6;
  static const offersLimit = 6;
  static const requestsLimit = 3;

  CategoryMarketBloc({
    required GetMarketServicesUseCase getServices,
    required GetMarketExpertsUseCase getExperts,
    required GetPublicOffersUseCase getOffers,
    required GetPublicRequestsUseCase getRequests,
    required GetHealthSolutionsUseCase getSolutions,
  }) : _getServices = getServices,
       _getExperts = getExperts,
       _getOffers = getOffers,
       _getRequests = getRequests,
       _getSolutions = getSolutions,
       super(const CategoryMarketState()) {
    on<CategoryMarketStarted>(_onStarted);
    on<CategoryMarketRefreshed>(
      (event, emit) => _loadAll(emit, state.category, refresh: true),
    );
    on<CategoryMarketSectionRetried>(
      (event, emit) => _load(emit, event.section, state.category),
    );
  }

  Future<void> _onStarted(
    CategoryMarketStarted event,
    Emitter<CategoryMarketState> emit,
  ) async {
    emit(state.copyWith(category: event.category));
    await _loadAll(emit, event.category);
  }

  Future<void> _loadAll(
    Emitter<CategoryMarketState> emit,
    MarketCategory? category, {
    bool refresh = false,
  }) => Future.wait([
    for (final section in MarketSectionKind.values)
      _load(emit, section, category, refresh: refresh),
  ]);

  Future<void> _load(
    Emitter<CategoryMarketState> emit,
    MarketSectionKind section,
    MarketCategory? category, {
    bool refresh = false,
  }) async {
    if (category == null) return;
    // Kéo để làm mới: giữ dữ liệu cũ trên màn trong lúc tải.
    if (!refresh) {
      emit(state.withSection(section, SectionStatus.loading));
    }
    final slug = category.slug;
    void fail(String _) =>
        emit(state.withSection(section, SectionStatus.failure));

    switch (section) {
      case MarketSectionKind.services:
        await callApi(
          useCase: _getServices,
          param: MarketPageParams(categorySlug: slug, limit: servicesLimit),
          onSuccess: (page) async =>
              emit(state.copyWith(services: page.items).loaded(section)),
          onFailure: fail,
        );
      case MarketSectionKind.sellers:
        await callApi(
          useCase: _getExperts,
          param: MarketPageParams(categorySlug: slug, limit: sellersLimit),
          onSuccess: (page) async =>
              emit(state.copyWith(sellers: page.items).loaded(section)),
          onFailure: fail,
        );
      case MarketSectionKind.offers:
        await callApi(
          useCase: _getOffers,
          param: const MarketPageParams(limit: offersLimit),
          onSuccess: (page) async =>
              emit(state.copyWith(offers: page.items).loaded(section)),
          onFailure: fail,
        );
      case MarketSectionKind.requests:
        await callApi(
          useCase: _getRequests,
          param: const MarketPageParams(limit: requestsLimit),
          onSuccess: (page) async =>
              emit(state.copyWith(requests: page.items).loaded(section)),
          onFailure: fail,
        );
      case MarketSectionKind.solutions:
        await callApi(
          useCase: _getSolutions,
          param: const NoParams(),
          onSuccess: (items) async =>
              emit(state.copyWith(solutions: items).loaded(section)),
          onFailure: fail,
        );
    }
  }
}
