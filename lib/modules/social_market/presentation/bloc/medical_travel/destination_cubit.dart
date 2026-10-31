import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../../../domain/entities/market_listing_entities.dart';
import '../../../domain/entities/medical_travel_entities.dart';
import '../../../domain/usecases/social_market_use_cases.dart';
import '../category_market/category_market_bloc.dart' show SectionStatus;

enum DestinationTab { services, sellers }

/// Một list có phân trang của trang destination (web `usePagedList`).
class PagedList<T> extends Equatable {
  final SectionStatus status;
  final List<T> items;
  final int total;
  final int page;
  final int totalPages;
  final bool loadingMore;

  const PagedList({
    this.status = SectionStatus.initial,
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.totalPages = 0,
    this.loadingMore = false,
  });

  bool get hasMore => page < totalPages;

  @override
  List<Object?> get props => [
    status,
    items,
    total,
    page,
    totalPages,
    loadingMore,
  ];
}

class DestinationState extends Equatable {
  final SectionStatus countryStatus;
  final MarketCountry? country;
  final DestinationTab tab;
  final MedicalServiceFilters serviceFilters;
  final CountrySellerFilters? sellerFilters;
  final PagedList<MarketServiceEntity> services;
  final PagedList<MarketExpertEntity> sellers;

  /// "Explore other destinations".
  final List<MarketDestination> others;

  const DestinationState({
    this.countryStatus = SectionStatus.initial,
    this.country,
    this.tab = DestinationTab.services,
    this.serviceFilters = const MedicalServiceFilters(),
    this.sellerFilters,
    this.services = const PagedList(),
    this.sellers = const PagedList(),
    this.others = const [],
  });

  DestinationState copyWith({
    SectionStatus? countryStatus,
    MarketCountry? country,
    DestinationTab? tab,
    MedicalServiceFilters? serviceFilters,
    CountrySellerFilters? sellerFilters,
    PagedList<MarketServiceEntity>? services,
    PagedList<MarketExpertEntity>? sellers,
    List<MarketDestination>? others,
  }) => DestinationState(
    countryStatus: countryStatus ?? this.countryStatus,
    country: country ?? this.country,
    tab: tab ?? this.tab,
    serviceFilters: serviceFilters ?? this.serviceFilters,
    sellerFilters: sellerFilters ?? this.sellerFilters,
    services: services ?? this.services,
    sellers: sellers ?? this.sellers,
    others: others ?? this.others,
  );

  @override
  List<Object?> get props => [
    countryStatus,
    country,
    tab,
    serviceFilters,
    sellerFilters,
    services,
    sellers,
    others,
  ];
}

/// Trang destination của Medical Travel (web `/destination/{code}/medical-travel`):
/// hero nước, 2 tab Services / Providers mỗi tab một bộ lọc riêng, nước khác.
class DestinationCubit extends Cubit<DestinationState> {
  /// Lưới 2 cột nên lấy số chẵn (web `DESTINATION_PAGE_SIZE` / `SELLERS_PAGE_SIZE`).
  static const pageSize = 8;

  final GetCountryUseCase _getCountry;
  final GetMedicalServicesUseCase _getServices;
  final GetCountrySellersUseCase _getSellers;
  final GetDestinationsUseCase _getDestinations;
  int _servicesGen = 0;
  int _sellersGen = 0;

  DestinationCubit({
    required GetCountryUseCase getCountry,
    required GetMedicalServicesUseCase getServices,
    required GetCountrySellersUseCase getSellers,
    required GetDestinationsUseCase getDestinations,
  }) : _getCountry = getCountry,
       _getServices = getServices,
       _getSellers = getSellers,
       _getDestinations = getDestinations,
       super(const DestinationState());

  Future<void> load(
    String code, {
    DestinationTab tab = DestinationTab.services,
  }) async {
    emit(DestinationState(countryStatus: SectionStatus.loading, tab: tab));
    final result = await _getCountry(code);
    if (isClosed) return;
    final country = result.toNullable();
    if (country == null) {
      emit(state.copyWith(countryStatus: SectionStatus.failure));
      return;
    }
    emit(
      state.copyWith(
        countryStatus: SectionStatus.success,
        country: country,
        serviceFilters: MedicalServiceFilters(countryId: country.id),
        sellerFilters: CountrySellerFilters(countryId: country.id),
      ),
    );
    await Future.wait([_loadServices(), _loadSellers(), _loadOthers()]);
  }

  void selectTab(DestinationTab tab) => emit(state.copyWith(tab: tab));

  Future<void> changeServiceFilters(MedicalServiceFilters filters) async {
    if (filters == state.serviceFilters) return;
    emit(state.copyWith(serviceFilters: filters));
    await _loadServices();
  }

  Future<void> changeSellerFilters(CountrySellerFilters filters) async {
    if (filters == state.sellerFilters) return;
    emit(state.copyWith(sellerFilters: filters));
    await _loadSellers();
  }

  Future<void> retry() =>
      state.tab == DestinationTab.services ? _loadServices() : _loadSellers();

  Future<void> loadMore() => state.tab == DestinationTab.services
      ? _loadServices(more: true)
      : _loadSellers(more: true);

  Future<void> _loadServices({bool more = false}) async {
    final current = state.services;
    if (more && (current.loadingMore || !current.hasMore)) return;
    final gen = more ? _servicesGen : ++_servicesGen;
    emit(state.copyWith(services: _start(current, more)));
    final page = more ? current.page + 1 : 1;
    final result = await _getServices((
      filters: state.serviceFilters,
      page: page,
      limit: pageSize,
    ));
    if (isClosed || gen != _servicesGen) return;
    emit(state.copyWith(services: _done(state.services, result, page, more)));
  }

  Future<void> _loadSellers({bool more = false}) async {
    final filters = state.sellerFilters;
    if (filters == null) return;
    final current = state.sellers;
    if (more && (current.loadingMore || !current.hasMore)) return;
    final gen = more ? _sellersGen : ++_sellersGen;
    emit(state.copyWith(sellers: _start(current, more)));
    final page = more ? current.page + 1 : 1;
    final result = await _getSellers((
      filters: filters,
      page: page,
      limit: pageSize,
    ));
    if (isClosed || gen != _sellersGen) return;
    emit(state.copyWith(sellers: _done(state.sellers, result, page, more)));
  }

  Future<void> _loadOthers() async {
    final result = await _getDestinations(const NoParams());
    if (isClosed) return;
    final code = state.country?.code;
    result.fold(
      (_) {},
      (items) => emit(
        state.copyWith(
          others: items
              .where((d) => d.code != null && d.code!.toUpperCase() != code)
              .take(6)
              .toList(),
        ),
      ),
    );
  }

  static PagedList<T> _start<T>(PagedList<T> current, bool more) => more
      ? PagedList(
          status: current.status,
          items: current.items,
          total: current.total,
          page: current.page,
          totalPages: current.totalPages,
          loadingMore: true,
        )
      : PagedList(status: SectionStatus.loading, items: current.items);

  static PagedList<T> _done<T extends Object>(
    PagedList<T> current,
    Either<Failure, MarketPage<T>> result,
    int page,
    bool more,
  ) => result.fold(
    (_) => more
        ? PagedList(
            status: current.status,
            items: current.items,
            total: current.total,
            page: current.page,
            // Tải thêm lỗi → dừng ("Show more" bấm lại được).
            totalPages: current.totalPages,
          )
        : PagedList(status: SectionStatus.failure, items: current.items),
    (data) => PagedList(
      status: SectionStatus.success,
      items: more ? [...current.items, ...data.items] : data.items,
      total: data.total,
      page: page,
      totalPages: data.totalPages,
    ),
  );
}
