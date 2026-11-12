import 'dart:math';

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

/// Trang category — web `CategoryPage` (chung cho Longevity, Health Pro Advisory,
/// Personal Helper và Medical Travel): mỗi mục tải độc lập (web stream từng Suspense).
/// - "In the spotlight": điểm AI refine cao nhất (`order_by=quality_score`).
/// - Services: thứ tự mặc định BE, bỏ service đã ở spotlight.
/// - "Care that speaks your language": seller làm việc bằng ngôn ngữ giao diện, bỏ
///   service đã có ở 2 mục trên.
/// - Experts: seller của category xếp `score_rank`; Medical Travel = coordinator.
/// Services / Experts lỗi → khối "Couldn't load"; các mục khác lỗi / rỗng → ẩn.
class CategoryMarketBloc
    extends BlocWithApi<CategoryMarketEvent, CategoryMarketState> {
  final GetMarketServicesUseCase _getServices;
  final GetMarketExpertsUseCase _getExperts;
  final GetCoordinatorsUseCase _getCoordinators;
  final GetDestinationsUseCase _getDestinations;

  /// Số item mỗi section (web `CATEGORY_LIMITS`): service 6, expert 9.
  static const servicesLimit = 6;
  static const expertsLimit = 9;

  /// Lấy dư để còn chỗ bỏ service trùng giữa các section (web `SERVICES_FETCH`).
  static const servicesFetch = 12;

  /// Trang 1 của listing (web `LISTING_PAGE_SIZE`) — spotlight / ngôn ngữ dùng cùng hàm.
  static const listingPageSize = 10;

  static const _serviceSections = [
    MarketSectionKind.spotlight,
    MarketSectionKind.services,
    MarketSectionKind.language,
  ];

  CategoryMarketBloc({
    required GetMarketServicesUseCase getServices,
    required GetMarketExpertsUseCase getExperts,
    required GetCoordinatorsUseCase getCoordinators,
    required GetDestinationsUseCase getDestinations,
  }) : _getServices = getServices,
       _getExperts = getExperts,
       _getCoordinators = getCoordinators,
       _getDestinations = getDestinations,
       super(const CategoryMarketState()) {
    on<CategoryMarketStarted>(_onStarted);
    on<CategoryMarketRefreshed>((event, emit) => _loadAll(emit, refresh: true));
    on<CategoryMarketSectionRetried>(
      (event, emit) => switch (event.section) {
        MarketSectionKind.destinations => _loadDestinations(emit),
        MarketSectionKind.experts => _loadExperts(emit),
        _ => _loadServices(emit),
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

  MarketPageParams _params({
    required int limit,
    String? orderBy,
    String? orderDir,
    bool newestFirst = false,
    String? language,
  }) => MarketPageParams(
    scope: state.scope,
    categorySlug: state.scope?.slug ?? '',
    limit: limit,
    orderBy: orderBy,
    orderDir: orderDir,
    newestFirst: newestFirst,
    language: language,
  );

  /// Spotlight + Services + ngôn ngữ: gọi song song rồi bỏ trùng (web
  /// `loadServiceSections` + `LanguageServicesLoader`).
  Future<void> _loadServices(
    Emitter<CategoryMarketState> emit, {
    bool refresh = false,
  }) async {
    if (state.scope == null) return;
    // Kéo để làm mới: giữ dữ liệu cũ trên màn trong lúc tải.
    if (!refresh) {
      emit(state.withSections(_serviceSections, SectionStatus.loading));
    }
    final results = await Future.wait([
      _getServices(
        _params(
          limit: listingPageSize,
          orderBy: 'quality_score',
          orderDir: 'DESC',
        ),
      ),
      _getServices(_params(limit: servicesFetch)),
      _getServices(
        _params(
          limit: listingPageSize,
          newestFirst: true,
          language: state.language,
        ),
      ),
    ]);
    if (isClosed) return;
    final sections = splitServiceSections(
      spotlight: results[0].toNullable()?.items,
      latest: results[1].toNullable()?.items,
      language: results[2].toNullable()?.items,
    );
    emit(
      state
          .copyWith(
            spotlight: sections.spotlight ?? const [],
            services: sections.main ?? const [],
            languageServices: sections.language ?? const [],
          )
          .withSection(
            MarketSectionKind.spotlight,
            sections.spotlight == null
                ? SectionStatus.failure
                : SectionStatus.success,
          )
          .withSection(
            MarketSectionKind.services,
            sections.main == null
                ? SectionStatus.failure
                : SectionStatus.success,
          )
          .withSection(
            MarketSectionKind.language,
            sections.language == null
                ? SectionStatus.failure
                : SectionStatus.success,
          ),
    );
  }

  /// Bỏ service trùng giữa các section (null = nguồn đó lỗi).
  static ({
    List<MarketServiceEntity>? spotlight,
    List<MarketServiceEntity>? main,
    List<MarketServiceEntity>? language,
  })
  splitServiceSections({
    required List<MarketServiceEntity>? spotlight,
    required List<MarketServiceEntity>? latest,
    required List<MarketServiceEntity>? language,
    int limit = servicesLimit,
  }) {
    final top = spotlight?.take(limit).toList();
    final taken = {...?top?.map((s) => s.id).nonNulls};
    final main = latest
        ?.where((s) => !taken.contains(s.id))
        .take(limit)
        .toList();
    final seen = {...taken, ...?main?.map((s) => s.id).nonNulls};
    final own = language
        ?.where((s) => !seen.contains(s.id))
        .take(limit)
        .toList();
    return (spotlight: top, main: main, language: own);
  }

  Future<void> _loadExperts(
    Emitter<CategoryMarketState> emit, {
    bool refresh = false,
  }) async {
    final scope = state.scope;
    if (scope == null) return;
    const section = MarketSectionKind.experts;
    if (!refresh) emit(state.withSection(section, SectionStatus.loading));
    void fail(String _) =>
        emit(state.withSection(section, SectionStatus.failure));
    void done(List<MarketExpertEntity> items) => emit(
      state
          .copyWith(experts: items.take(expertsLimit).toList())
          .withSection(section, SectionStatus.success),
    );

    if (scope.isMedicalTravel) {
      // Medical Travel: seller là coordinator (owner của organization) - web getCoordinators.
      await callApi(
        useCase: _getCoordinators,
        param: CoordinatorsPhase(
          category: true,
          page: 1,
          seed: Random().nextInt(1 << 31).toRadixString(36),
        ),
        onSuccess: (r) async => done(r.items),
        onFailure: fail,
      );
      return;
    }
    await callApi(
      useCase: _getExperts,
      param: _params(limit: expertsLimit),
      onSuccess: (page) async => done(page.items),
      onFailure: fail,
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
