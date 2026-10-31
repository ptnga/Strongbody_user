import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';

import '../entities/market_feed_entities.dart';
import '../entities/market_inquiry.dart';
import '../entities/market_listing_entities.dart';
import '../entities/medical_travel_entities.dart';

abstract class SocialMarketRepository {
  /// Service theo category. `newestFirst` = listing (web `fetchServicesPage`);
  /// không có = mục Selling (web `fetchCategoryPackages`, thứ tự mặc định BE).
  Future<Either<Failure, MarketPage<MarketServiceEntity>>> getServices({
    required String categorySlug,
    required int page,
    required int limit,
    bool newestFirst = false,
  });

  /// Seller của category, xếp `score_rank`.
  Future<Either<Failure, MarketPage<MarketExpertEntity>>> getExperts({
    required String categorySlug,
    required int page,
    required int limit,
  });

  Future<Either<Failure, MarketPage<MarketOfferEntity>>> getPublicOffers({
    required int page,
    required int limit,
  });

  Future<Either<Failure, MarketPage<MarketRequestEntity>>> getPublicRequests({
    required int page,
    required int limit,
  });

  /// Mục Solutions: 50 mới nhất theo id.
  Future<Either<Failure, List<HealthSolutionEntity>>> getHealthSolutions();

  Future<Either<Failure, Map<int, EngagementState>>> getEngagement(
    EngagementTarget target,
    List<int> ids,
  );

  /// Bật/tắt like / save → số đếm mới từ server.
  Future<Either<Failure, int?>> setEngagement({
    required EngagementKind kind,
    required EngagementTarget target,
    required int targetId,
    required bool on,
  });

  /// Gửi inquiry → user id người nhận (để mở chat).
  Future<Either<Failure, int>> sendInquiry(MarketInquiry inquiry);

  /// "I want a solution of this type" → số provider được báo.
  Future<Either<Failure, int>> matchHealthSolution({
    required int solutionId,
    required String message,
  });

  // Medical Travel
  /// Một lượt của hàng coordinator + vị trí tiếp theo.
  Future<
    Either<Failure, ({List<MarketExpertEntity> items, CoordinatorsCursor next})>
  >
  getCoordinators(CoordinatorsPhase cursor);

  Future<Either<Failure, List<MarketDestination>>> getDestinations();

  Future<Either<Failure, MarketPage<MarketServiceEntity>>> getMedicalServices(
    MedicalServiceFilters filters, {
    required int page,
    required int limit,
  });

  Future<Either<Failure, MarketPage<MarketExpertEntity>>> getCountrySellers(
    CountrySellerFilters filters, {
    required int page,
    required int limit,
  });

  Future<Either<Failure, MarketServiceDetail>> getServiceDetail(int id);

  Future<Either<Failure, Unit>> sendAppointmentRequest(AppointmentRequest req);

  Future<Either<Failure, MarketCountry>> getCountry(String code);

  Future<Either<Failure, List<PhoneCodeOption>>> getPhoneCodes();
}
