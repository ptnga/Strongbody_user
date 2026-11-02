import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../../../domain/entities/market_listing_entities.dart';
import '../../../domain/entities/medical_travel_entities.dart';
import '../../../domain/usecases/social_market_use_cases.dart';
import '../category_market/category_market_bloc.dart' show SectionStatus;

/// Trang Medical Travel (web `CategoryLandingPage`): hàng coordinator, destinations,
/// "Recommended services" có lọc. Các khối tĩnh (Trust, How, FAQ) không cần state.
class MedicalTravelState extends Equatable {
  final List<MarketExpertEntity> coordinators;
  final CoordinatorsCursor? coordinatorsNext;
  final bool coordinatorsLoading;
  final bool coordinatorsError;

  final SectionStatus destinationsStatus;
  final List<MarketDestination> destinations;

  final MedicalServiceFilters filters;
  final SectionStatus packagesStatus;
  final List<MarketServiceEntity> packages;
  final int packagesTotal;
  final int packagesPage;
  final bool packagesLoadingMore;
  final bool packagesMoreError;

  const MedicalTravelState({
    this.coordinators = const [],
    this.coordinatorsNext,
    this.coordinatorsLoading = false,
    this.coordinatorsError = false,
    this.destinationsStatus = SectionStatus.initial,
    this.destinations = const [],
    this.filters = const MedicalServiceFilters(),
    this.packagesStatus = SectionStatus.initial,
    this.packages = const [],
    this.packagesTotal = 0,
    this.packagesPage = 1,
    this.packagesLoadingMore = false,
    this.packagesMoreError = false,
  });

  bool get coordinatorsDone => coordinatorsNext is CoordinatorsDone;

  MedicalTravelState copyWith({
    List<MarketExpertEntity>? coordinators,
    CoordinatorsCursor? coordinatorsNext,
    bool? coordinatorsLoading,
    bool? coordinatorsError,
    SectionStatus? destinationsStatus,
    List<MarketDestination>? destinations,
    MedicalServiceFilters? filters,
    SectionStatus? packagesStatus,
    List<MarketServiceEntity>? packages,
    int? packagesTotal,
    int? packagesPage,
    bool? packagesLoadingMore,
    bool? packagesMoreError,
  }) => MedicalTravelState(
    coordinators: coordinators ?? this.coordinators,
    coordinatorsNext: coordinatorsNext ?? this.coordinatorsNext,
    coordinatorsLoading: coordinatorsLoading ?? this.coordinatorsLoading,
    coordinatorsError: coordinatorsError ?? this.coordinatorsError,
    destinationsStatus: destinationsStatus ?? this.destinationsStatus,
    destinations: destinations ?? this.destinations,
    filters: filters ?? this.filters,
    packagesStatus: packagesStatus ?? this.packagesStatus,
    packages: packages ?? this.packages,
    packagesTotal: packagesTotal ?? this.packagesTotal,
    packagesPage: packagesPage ?? this.packagesPage,
    packagesLoadingMore: packagesLoadingMore ?? this.packagesLoadingMore,
    packagesMoreError: packagesMoreError ?? this.packagesMoreError,
  );

  @override
  List<Object?> get props => [
    coordinators,
    coordinatorsNext,
    coordinatorsLoading,
    coordinatorsError,
    destinationsStatus,
    destinations,
    filters,
    packagesStatus,
    packages,
    packagesTotal,
    packagesPage,
    packagesLoadingMore,
    packagesMoreError,
  ];
}

class MedicalTravelCubit extends Cubit<MedicalTravelState> {
  /// "Recommended services": 10 service mỗi lần (web `RECOMMENDED_PAGE_SIZE`).
  static const packagesPageSize = 10;

  final GetCoordinatorsUseCase _getCoordinators;
  final GetDestinationsUseCase _getDestinations;
  final GetMedicalServicesUseCase _getServices;

  /// Kết quả "View more" của bộ lọc cũ về muộn thì bỏ (web `filtersGen`).
  int _filtersGen = 0;

  MedicalTravelCubit({
    required GetCoordinatorsUseCase getCoordinators,
    required GetDestinationsUseCase getDestinations,
    required GetMedicalServicesUseCase getServices,
  }) : _getCoordinators = getCoordinators,
       _getDestinations = getDestinations,
       _getServices = getServices,
       super(const MedicalTravelState());

  Future<void> load() async {
    // Mỗi lượt xem một seed mới: phần seller ngẫu nhiên khác nhau giữa các lượt.
    final seed = Random().nextInt(1 << 31).toRadixString(36);
    emit(
      MedicalTravelState(
        coordinatorsNext: CoordinatorsPhase(
          category: true,
          page: 1,
          seed: seed,
        ),
        filters: state.filters,
      ),
    );
    await Future.wait([
      loadMoreCoordinators(),
      _loadDestinations(),
      _loadPackages(),
    ]);
  }

  Future<void> loadMoreCoordinators() async {
    final cursor = state.coordinatorsNext;
    if (cursor is! CoordinatorsPhase || state.coordinatorsLoading) return;
    emit(state.copyWith(coordinatorsLoading: true, coordinatorsError: false));
    final result = await _getCoordinators(cursor);
    if (isClosed) return;
    result.fold(
      (_) => emit(
        state.copyWith(coordinatorsLoading: false, coordinatorsError: true),
      ),
      (page) {
        // Lọc trùng: seller vừa vào category giữa 2 lượt tải có thể xuất hiện lại.
        final seen = state.coordinators.map((c) => c.id).toSet();
        emit(
          state.copyWith(
            coordinators: [
              ...state.coordinators,
              ...page.items.where((c) => !seen.contains(c.id)),
            ],
            coordinatorsNext: page.next,
            coordinatorsLoading: false,
          ),
        );
      },
    );
  }

  Future<void> _loadDestinations() async {
    emit(state.copyWith(destinationsStatus: SectionStatus.loading));
    final result = await _getDestinations(const NoParams());
    if (isClosed) return;
    result.fold(
      (_) => emit(state.copyWith(destinationsStatus: SectionStatus.failure)),
      (items) => emit(
        state.copyWith(
          destinationsStatus: SectionStatus.success,
          destinations: items,
        ),
      ),
    );
  }

  /// Đổi sort / chứng nhận → tải lại trang 1.
  Future<void> changeFilters(MedicalServiceFilters filters) async {
    if (filters == state.filters) return;
    emit(state.copyWith(filters: filters));
    await _loadPackages();
  }

  Future<void> retryPackages() => _loadPackages();

  Future<void> _loadPackages() async {
    final gen = ++_filtersGen;
    emit(
      state.copyWith(
        packagesStatus: SectionStatus.loading,
        packagesLoadingMore: false,
        packagesMoreError: false,
      ),
    );
    final result = await _getServices((
      filters: state.filters,
      page: 1,
      limit: packagesPageSize,
    ));
    if (isClosed || gen != _filtersGen) return;
    result.fold(
      (_) => emit(state.copyWith(packagesStatus: SectionStatus.failure)),
      (page) => emit(
        state.copyWith(
          packagesStatus: SectionStatus.success,
          packages: page.items,
          packagesTotal: page.total,
          packagesPage: 1,
        ),
      ),
    );
  }

  Future<void> viewMorePackages() async {
    if (state.packagesLoadingMore ||
        state.packagesStatus == SectionStatus.loading) {
      return;
    }
    final gen = _filtersGen;
    final next = state.packagesPage + 1;
    emit(state.copyWith(packagesLoadingMore: true, packagesMoreError: false));
    final result = await _getServices((
      filters: state.filters,
      page: next,
      limit: packagesPageSize,
    ));
    if (isClosed || gen != _filtersGen) return;
    result.fold(
      (_) => emit(
        state.copyWith(packagesLoadingMore: false, packagesMoreError: true),
      ),
      (page) {
        final seen = state.packages.map((s) => s.id).toSet();
        emit(
          state.copyWith(
            packages: [
              ...state.packages,
              ...page.items.where((s) => !seen.contains(s.id)),
            ],
            packagesTotal: page.total,
            packagesPage: next,
            packagesLoadingMore: false,
          ),
        );
      },
    );
  }
}
