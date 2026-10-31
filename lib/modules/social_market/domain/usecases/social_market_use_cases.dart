import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/market_feed_entities.dart';
import '../entities/market_inquiry.dart';
import '../entities/market_listing_entities.dart';
import '../entities/medical_travel_entities.dart';
import '../repositories/social_market_repository.dart';

class MarketPageParams extends Equatable {
  final String categorySlug;
  final int page;
  final int limit;

  /// Listing: mới nhất trước (service).
  final bool newestFirst;

  const MarketPageParams({
    this.categorySlug = '',
    this.page = 1,
    required this.limit,
    this.newestFirst = false,
  });

  @override
  List<Object?> get props => [categorySlug, page, limit, newestFirst];
}

class GetMarketServicesUseCase
    implements UseCase<MarketPage<MarketServiceEntity>, MarketPageParams> {
  final SocialMarketRepository _repository;
  GetMarketServicesUseCase(this._repository);

  @override
  Future<Either<Failure, MarketPage<MarketServiceEntity>>> call(
    MarketPageParams p,
  ) => _repository.getServices(
    categorySlug: p.categorySlug,
    page: p.page,
    limit: p.limit,
    newestFirst: p.newestFirst,
  );
}

class GetMarketExpertsUseCase
    implements UseCase<MarketPage<MarketExpertEntity>, MarketPageParams> {
  final SocialMarketRepository _repository;
  GetMarketExpertsUseCase(this._repository);

  @override
  Future<Either<Failure, MarketPage<MarketExpertEntity>>> call(
    MarketPageParams p,
  ) => _repository.getExperts(
    categorySlug: p.categorySlug,
    page: p.page,
    limit: p.limit,
  );
}

class GetPublicOffersUseCase
    implements UseCase<MarketPage<MarketOfferEntity>, MarketPageParams> {
  final SocialMarketRepository _repository;
  GetPublicOffersUseCase(this._repository);

  @override
  Future<Either<Failure, MarketPage<MarketOfferEntity>>> call(
    MarketPageParams p,
  ) => _repository.getPublicOffers(page: p.page, limit: p.limit);
}

class GetPublicRequestsUseCase
    implements UseCase<MarketPage<MarketRequestEntity>, MarketPageParams> {
  final SocialMarketRepository _repository;
  GetPublicRequestsUseCase(this._repository);

  @override
  Future<Either<Failure, MarketPage<MarketRequestEntity>>> call(
    MarketPageParams p,
  ) => _repository.getPublicRequests(page: p.page, limit: p.limit);
}

class GetHealthSolutionsUseCase
    implements UseCase<List<HealthSolutionEntity>, NoParams> {
  final SocialMarketRepository _repository;
  GetHealthSolutionsUseCase(this._repository);

  @override
  Future<Either<Failure, List<HealthSolutionEntity>>> call(NoParams params) =>
      _repository.getHealthSolutions();
}

class GetEngagementUseCase
    implements
        UseCase<
          Map<int, EngagementState>,
          ({EngagementTarget target, List<int> ids})
        > {
  final SocialMarketRepository _repository;
  GetEngagementUseCase(this._repository);

  @override
  Future<Either<Failure, Map<int, EngagementState>>> call(
    ({EngagementTarget target, List<int> ids}) p,
  ) => _repository.getEngagement(p.target, p.ids);
}

class SetEngagementUseCase
    implements
        UseCase<
          int?,
          ({
            EngagementKind kind,
            EngagementTarget target,
            int targetId,
            bool on,
          })
        > {
  final SocialMarketRepository _repository;
  SetEngagementUseCase(this._repository);

  @override
  Future<Either<Failure, int?>> call(
    ({EngagementKind kind, EngagementTarget target, int targetId, bool on}) p,
  ) => _repository.setEngagement(
    kind: p.kind,
    target: p.target,
    targetId: p.targetId,
    on: p.on,
  );
}

/// → user id người nhận (mở chat).
class SendInquiryUseCase implements UseCase<int, MarketInquiry> {
  final SocialMarketRepository _repository;
  SendInquiryUseCase(this._repository);

  @override
  Future<Either<Failure, int>> call(MarketInquiry inquiry) =>
      _repository.sendInquiry(inquiry);
}

/// "I want a solution of this type" (role seeker) → số provider được báo.
class MatchHealthSolutionUseCase
    implements UseCase<int, ({int solutionId, String message})> {
  final SocialMarketRepository _repository;
  MatchHealthSolutionUseCase(this._repository);

  @override
  Future<Either<Failure, int>> call(({int solutionId, String message}) p) =>
      _repository.matchHealthSolution(
        solutionId: p.solutionId,
        message: p.message,
      );
}

// ------------------------------------------------------------ medical travel

class GetCoordinatorsUseCase
    implements
        UseCase<
          ({List<MarketExpertEntity> items, CoordinatorsCursor next}),
          CoordinatorsPhase
        > {
  final SocialMarketRepository _repository;
  GetCoordinatorsUseCase(this._repository);

  @override
  Future<
    Either<Failure, ({List<MarketExpertEntity> items, CoordinatorsCursor next})>
  >
  call(CoordinatorsPhase cursor) => _repository.getCoordinators(cursor);
}

class GetDestinationsUseCase
    implements UseCase<List<MarketDestination>, NoParams> {
  final SocialMarketRepository _repository;
  GetDestinationsUseCase(this._repository);

  @override
  Future<Either<Failure, List<MarketDestination>>> call(NoParams params) =>
      _repository.getDestinations();
}

class GetMedicalServicesUseCase
    implements
        UseCase<
          MarketPage<MarketServiceEntity>,
          ({MedicalServiceFilters filters, int page, int limit})
        > {
  final SocialMarketRepository _repository;
  GetMedicalServicesUseCase(this._repository);

  @override
  Future<Either<Failure, MarketPage<MarketServiceEntity>>> call(
    ({MedicalServiceFilters filters, int page, int limit}) p,
  ) => _repository.getMedicalServices(p.filters, page: p.page, limit: p.limit);
}

class GetCountrySellersUseCase
    implements
        UseCase<
          MarketPage<MarketExpertEntity>,
          ({CountrySellerFilters filters, int page, int limit})
        > {
  final SocialMarketRepository _repository;
  GetCountrySellersUseCase(this._repository);

  @override
  Future<Either<Failure, MarketPage<MarketExpertEntity>>> call(
    ({CountrySellerFilters filters, int page, int limit}) p,
  ) => _repository.getCountrySellers(p.filters, page: p.page, limit: p.limit);
}

class GetServiceDetailUseCase implements UseCase<MarketServiceDetail, int> {
  final SocialMarketRepository _repository;
  GetServiceDetailUseCase(this._repository);

  @override
  Future<Either<Failure, MarketServiceDetail>> call(int id) =>
      _repository.getServiceDetail(id);
}

class SendAppointmentRequestUseCase
    implements UseCase<Unit, AppointmentRequest> {
  final SocialMarketRepository _repository;
  SendAppointmentRequestUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(AppointmentRequest req) =>
      _repository.sendAppointmentRequest(req);
}

class GetCountryUseCase implements UseCase<MarketCountry, String> {
  final SocialMarketRepository _repository;
  GetCountryUseCase(this._repository);

  @override
  Future<Either<Failure, MarketCountry>> call(String code) =>
      _repository.getCountry(code);
}

class GetPhoneCodesUseCase implements UseCase<List<PhoneCodeOption>, NoParams> {
  final SocialMarketRepository _repository;
  GetPhoneCodesUseCase(this._repository);

  @override
  Future<Either<Failure, List<PhoneCodeOption>>> call(NoParams params) =>
      _repository.getPhoneCodes();
}
