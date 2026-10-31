import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/network/exception.dart';
import 'package:strongbody_buyer/core/utils/app_logger.dart';
import 'package:strongbody_buyer/modules/chat/domain/usecases/chat_use_cases.dart';

import '../../domain/entities/market_feed_entities.dart';
import '../../domain/entities/market_inquiry.dart';
import '../../domain/entities/market_listing_entities.dart';
import '../../domain/entities/medical_travel_entities.dart';
import '../../domain/repositories/social_market_repository.dart';
import '../datasources/remote/social_market_remote_datasource.dart';
import '../mappers/market_mapper.dart';
import '../services/market_chat_publisher.dart';

class SocialMarketRepositoryImpl implements SocialMarketRepository {
  final SocialMarketRemoteDataSource _remote;
  final GlobalStorage _storage;
  final OpenChatSessionUseCase _openChat;
  final MarketChatPublisher _publisher;

  SocialMarketRepositoryImpl(
    this._remote,
    this._storage,
    this._openChat,
    this._publisher,
  );

  Future<Either<Failure, T>> _guard<T>(
    Future<T> Function() run,
    String fallback,
  ) async {
    try {
      return Right(await run());
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['message']?.toString() : null;
      final status = e.response?.statusCode;
      return Left(
        status == 401 || status == 403
            ? UnauthorizedFailure(message ?? fallback, statusCode: status)
            : ServerFailure(message ?? fallback, statusCode: status),
      );
    } catch (e) {
      AppLogger.e(e);
      return Left(Failure(fallback));
    }
  }

  static MarketPage<T> _page<T extends Object>(
    RawListPage raw,
    T? Function(Map<String, dynamic>) map,
  ) => MarketPage<T>(
    items: raw.items.map(map).nonNulls.toList(),
    total: raw.total,
    totalPages: raw.totalPages,
  );

  @override
  Future<Either<Failure, MarketPage<MarketServiceEntity>>> getServices({
    required String categorySlug,
    required int page,
    required int limit,
    bool newestFirst = false,
  }) => _guard(() async {
    final raw = await _remote.getServices({
      'page': ?(page > 1 || newestFirst ? page : null),
      'limit': limit,
      if (newestFirst) ...{'order_by': 'created_at', 'order_dir': 'DESC'},
      'category_slug': categorySlug,
    });
    return _page(raw, MarketMapper.service);
  }, 'Cannot load services');

  @override
  Future<Either<Failure, MarketPage<MarketExpertEntity>>> getExperts({
    required String categorySlug,
    required int page,
    required int limit,
  }) => _guard(() async {
    final raw = await _remote.getExperts({
      'page': page,
      'limit': limit,
      'category_slug': categorySlug,
      'sort': 'score_rank',
    });
    return _page(raw, MarketMapper.expert);
  }, 'Cannot load providers');

  @override
  Future<Either<Failure, MarketPage<MarketOfferEntity>>> getPublicOffers({
    required int page,
    required int limit,
  }) => _guard(
    () async => _page(
      await _remote.getPublicOffers(page: page, limit: limit),
      MarketMapper.offer,
    ),
    'Cannot load offers',
  );

  @override
  Future<Either<Failure, MarketPage<MarketRequestEntity>>> getPublicRequests({
    required int page,
    required int limit,
  }) => _guard(
    () async => _page(
      await _remote.getPublicRequests(page: page, limit: limit),
      MarketMapper.request,
    ),
    'Cannot load requests',
  );

  @override
  Future<Either<Failure, List<HealthSolutionEntity>>> getHealthSolutions() =>
      _guard(() async {
        final raw = await _remote.getHealthSolutions({
          'page': 1,
          'limit': 50,
          'order_by': 'id',
          'order_dir': 'DESC',
        });
        return raw.items.map(MarketMapper.solution).nonNulls.toList();
      }, 'Cannot load solutions');

  @override
  Future<Either<Failure, Map<int, EngagementState>>> getEngagement(
    EngagementTarget target,
    List<int> ids,
  ) => _guard(() async {
    final items = await _remote.getEngagementSummary(
      targetType: target.apiValue,
      targetIds: ids,
      withAuth: _storage.isLoggedIn,
    );
    return Map.fromEntries(items.map(MarketMapper.engagement).nonNulls);
  }, 'Cannot load engagement');

  @override
  Future<Either<Failure, int?>> setEngagement({
    required EngagementKind kind,
    required EngagementTarget target,
    required int targetId,
    required bool on,
  }) => _guard(
    () => _remote.setEngagement(
      kind: kind.name,
      targetType: target.apiValue,
      targetId: targetId,
      on: on,
    ),
    'Cannot update',
  );

  @override
  Future<Either<Failure, int>> sendInquiry(MarketInquiry inquiry) =>
      _guard(() async {
        // 0. Inquiry là bản ghi nghiệp vụ bắt buộc — lỗi thì dừng, không chat.
        final saved = await _remote.createInquiry({
          'recipient_user_id': inquiry.recipientUserId,
          'target_type': inquiry.kind.name,
          'target_id': inquiry.itemId,
          'message': inquiry.content.trim(),
          'budget_from': inquiry.budgetFrom,
          'budget_to': inquiry.budgetTo,
          'budget_currency': inquiry.budgetCurrency,
          'item_title': inquiry.itemTitle,
          'item_image': inquiry.itemImage,
          'item_price': inquiry.itemPrice,
          'delivery_type': inquiry.deliveryType,
          'schedule': inquiry.schedule,
          'deadline': inquiry.deadline,
        }, inquiry.attachmentPaths);
        final savedInquiry = saved['inquiry'];
        final recipient = savedInquiry is Map
            ? num.tryParse('${savedInquiry['recipient_user_id']}')?.toInt()
            : null;
        final recipientId = recipient ?? inquiry.recipientUserId;

        // 1. Kênh DM + 2. card + 3. bookkeeping service + 4. lời nhắn.
        final session = (await _openChat(
          recipientId,
        )).getOrElse((f) => throw Exception(f.message));
        await _publisher.publishInquiry(
          session: session,
          kind: inquiry.kind.name,
          cardData: inquiry.cardData,
          content: inquiry.content.trim(),
          afterCard: inquiry.kind != InquiryKind.service
              ? null
              : () async {
                  // Best-effort như web: lỗi không chặn card / text.
                  try {
                    final allowed = await _remote.checkMessageService(
                      serviceId: inquiry.itemId,
                      channelId: session.channelId,
                    );
                    if (allowed) {
                      await _remote.sendMessageService(
                        serviceId: inquiry.itemId,
                        channelId: session.channelId,
                      );
                    }
                  } catch (e) {
                    AppLogger.w('Service bookkeeping failed', e);
                  }
                },
        );
        return recipientId;
      }, 'Cannot send inquiry');

  @override
  Future<Either<Failure, int>> matchHealthSolution({
    required int solutionId,
    required String message,
  }) => _guard(
    () => _remote.createHealthSolutionMatching(
      solutionId: solutionId,
      role: 'seeker',
      message: message,
    ),
    'Cannot send',
  );

  // --------------------------------------------------------- medical travel

  /// Hàng coordinator (web `fetchCoordinatorsPage`): Medical Travel chỉ liệt kê seller
  /// là owner của organization; hết seller của category thì nối seller ngẫu nhiên.
  @override
  Future<
    Either<Failure, ({List<MarketExpertEntity> items, CoordinatorsCursor next})>
  >
  getCoordinators(CoordinatorsPhase cursor) => _guard(() async {
    CoordinatorsCursor current = cursor;
    while (current is CoordinatorsPhase) {
      final phase = current;
      final raw = await _remote.getFeaturedExperts({
        'limit': coordinatorsPageSize,
        'page': phase.page,
        'sort': phase.category ? 'score' : 'random',
        if (phase.category) 'category_slug': medicalTravelSlug,
        if (!phase.category) ...{
          'exclude_category_slug': medicalTravelSlug,
          'seed': phase.seed,
        },
        'org_owner': true,
        'is_medical_travel': phase.category,
      });
      final CoordinatorsCursor next = phase.page < raw.totalPages
          ? CoordinatorsPhase(
              category: phase.category,
              page: phase.page + 1,
              seed: phase.seed,
            )
          : phase.category
          ? CoordinatorsPhase(category: false, page: 1, seed: phase.seed)
          : const CoordinatorsDone();
      if (raw.items.isNotEmpty) {
        return (
          items: raw.items.map(MarketMapper.coordinator).toList(),
          next: next,
        );
      }
      current = next;
    }
    return (
      items: const <MarketExpertEntity>[],
      next: const CoordinatorsDone(),
    );
  }, 'Cannot load coordinators');

  /// Slug category Medical Travel (web `MEDICAL_TRAVEL.slug`).
  static const medicalTravelSlug = 'medical-travel-2';

  /// Card mỗi lượt của hàng coordinator (web `COORDINATORS_PAGE_SIZE`).
  static const coordinatorsPageSize = 12;

  @override
  Future<Either<Failure, List<MarketDestination>>> getDestinations() => _guard(
    () async => (await _remote.getDestinations())
        .map(MarketMapper.destination)
        .nonNulls
        .toList(),
    'Cannot load destinations',
  );

  @override
  Future<Either<Failure, MarketPage<MarketServiceEntity>>> getMedicalServices(
    MedicalServiceFilters filters, {
    required int page,
    required int limit,
  }) => _guard(
    () async => _page(
      await _remote.getServices(filters.toQuery(page: page, limit: limit)),
      MarketMapper.medicalService,
    ),
    'Cannot load services',
  );

  @override
  Future<Either<Failure, MarketPage<MarketExpertEntity>>> getCountrySellers(
    CountrySellerFilters filters, {
    required int page,
    required int limit,
  }) => _guard(
    () async => _page(
      await _remote.getExperts(filters.toQuery(page: page, limit: limit)),
      MarketMapper.coordinator,
    ),
    'Cannot load providers',
  );

  @override
  Future<Either<Failure, MarketServiceDetail>> getServiceDetail(int id) =>
      _guard(() async {
        final detail = MarketMapper.serviceDetail(
          await _remote.getServiceDetail(id),
        );
        if (detail == null) throw Exception('Service not found');
        return detail;
      }, 'Cannot load service');

  @override
  Future<Either<Failure, Unit>> sendAppointmentRequest(
    AppointmentRequest req,
  ) => _guard(() async {
    await _remote.createAppointmentRequest(req.toJson());
    return unit;
  }, 'Could not send your request. Please try again.');

  @override
  Future<Either<Failure, MarketCountry>> getCountry(String code) =>
      _guard(() async {
        final country = MarketMapper.country(
          await _remote.getCountryByCode(code),
          code,
        );
        if (country == null) throw Exception('Destination not found');
        return country;
      }, 'Destination not found');

  @override
  Future<Either<Failure, List<PhoneCodeOption>>> getPhoneCodes() => _guard(
    () async => MarketMapper.phoneCodes(await _remote.getActiveCountries()),
    'Cannot load countries',
  );
}
