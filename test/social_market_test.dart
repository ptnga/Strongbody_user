import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/modules/social_market/data/mappers/market_mapper.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_category.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_feed_entities.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_inquiry.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_listing_entities.dart';
import 'package:strongbody_buyer/modules/social_market/domain/repositories/social_market_repository.dart';
import 'package:strongbody_buyer/modules/social_market/domain/usecases/social_market_use_cases.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/category_market/category_market_bloc.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/engagement/engagement_cubit.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/market_listing/market_listing_bloc.dart';

class _Storage implements GlobalStorage {
  @override
  bool get isLoggedIn => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements SocialMarketRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final serviceCalls = <({String slug, int page, int limit, bool newest})>[];
  bool failExperts = false;
  bool failToggle = false;
  int? toggleCount = 5;

  @override
  Future<Either<Failure, MarketPage<MarketServiceEntity>>> getServices({
    required String categorySlug,
    required int page,
    required int limit,
    bool newestFirst = false,
  }) async {
    serviceCalls.add((
      slug: categorySlug,
      page: page,
      limit: limit,
      newest: newestFirst,
    ));
    return Right(
      MarketPage(
        items: [
          MarketMapper.service({'id': page * 10, 'title': 'S$page'}),
          // Trùng id giữa các trang → listing phải bỏ.
          MarketMapper.service({'id': 1, 'title': 'dup'}),
        ],
        total: 30,
        totalPages: 3,
      ),
    );
  }

  @override
  Future<Either<Failure, MarketPage<MarketExpertEntity>>> getExperts({
    required String categorySlug,
    required int page,
    required int limit,
  }) async => failExperts
      ? Left(ServerFailure('boom'))
      : const Right(MarketPage(items: [], total: 0, totalPages: 0));

  @override
  Future<Either<Failure, MarketPage<MarketOfferEntity>>> getPublicOffers({
    required int page,
    required int limit,
  }) async => const Right(MarketPage(items: [], total: 0, totalPages: 0));

  @override
  Future<Either<Failure, MarketPage<MarketRequestEntity>>> getPublicRequests({
    required int page,
    required int limit,
  }) async => const Right(MarketPage(items: [], total: 0, totalPages: 0));

  @override
  Future<Either<Failure, List<HealthSolutionEntity>>>
  getHealthSolutions() async => const Right([]);

  @override
  Future<Either<Failure, Map<int, EngagementState>>> getEngagement(
    EngagementTarget target,
    List<int> ids,
  ) async => Right({
    for (final id in ids) id: const EngagementState(saves: 2, contacts: 1),
  });

  @override
  Future<Either<Failure, int?>> setEngagement({
    required EngagementKind kind,
    required EngagementTarget target,
    required int targetId,
    required bool on,
  }) async => failToggle ? Left(ServerFailure('x')) : Right(toggleCount);

  @override
  Future<Either<Failure, int>> sendInquiry(MarketInquiry inquiry) async =>
      const Right(1);

  @override
  Future<Either<Failure, int>> matchHealthSolution({
    required int solutionId,
    required String message,
  }) async => const Right(0);
}

void main() {
  group('MarketMapper.service (web ServiceCard / service-meta)', () {
    test('giá thấp nhất trong các hình thức + "From" khi nhiều mức', () {
      final s = MarketMapper.service({
        'id': 1,
        'title': 'Massage',
        'currency': 'GBP',
        'price': 999,
        'original_price': 100,
        'description': '<p>Relax &amp; <b>recover</b></p>',
        'delivery_options': [
          {'delivery_type': 'at_home', 'price': 80, 'radius_value': 10},
          {'delivery_type': 'remote', 'price': 45},
          {'delivery_type': 'at_office', 'price': 60, 'is_active': false},
        ],
      });
      expect(s.deliveries.map((d) => d.type), [
        MarketDeliveryType.remote,
        MarketDeliveryType.atHome,
      ]);
      expect(s.price!.text, '£45');
      expect(s.price!.from, isTrue);
      expect(s.coverage, '10 km');
      expect(s.description, 'Relax & recover');
      // original_price cao hơn giá thấp nhất → giá gạch ngang cùng đơn vị tiền.
      expect(s.strikePrice, '£100');
    });

    test('service luồng cũ: hình thức suy từ cột type, giá từ price', () {
      final s = MarketMapper.service({
        'id': 2,
        'type': 'hybrid',
        'price': 2100,
        'original_price': 2500,
      });
      final noPromo = MarketMapper.service({
        'id': 4,
        'price': 70,
        'original_price': 70,
      });
      // original_price bằng giá bán → không gạch ngang (web `strikePrice`).
      expect(noPromo.strikePrice, isNull);
      expect(s.deliveries.map((d) => d.type), [
        MarketDeliveryType.remote,
        MarketDeliveryType.atOffice,
      ]);
      expect(s.price!.text, r'$2,100');
      expect(s.strikePrice, r'$2,500');
    });

    test(
      'seller: tên shop + nước từ hồ sơ seller (không lấy tên tài khoản)',
      () {
        final s = MarketMapper.service({
          'id': 3,
          'user': {
            'id': 77,
            'first_name': 'Private',
            'profile_picture': 'a.png',
            'seller_profile': {
              'shop_name': 'Blue Clinic',
              'slug': 'blue',
              'addresses': [
                {'country': 'Vietnam', 'country_code': 'VN'},
              ],
            },
          },
        });
        expect(s.seller.id, 77);
        expect(s.seller.shopName, 'Blue Clinic');
        expect(s.seller.country, 'Vietnam');
        expect(s.seller.flag, 'https://flagcdn.com/w40/vn.png');
        expect(s.place, 'Vietnam');
      },
    );
  });

  test('MarketMapper.expert: organization đại diện + rating + ngôn ngữ', () {
    final e = MarketMapper.expert({
      'id': 9,
      'user_id': 90,
      'shop_name': 'Dr A',
      'is_org_owner': true,
      'organization': {
        'id': 4,
        'name': 'BlueNet Hospitals',
        'country': {'title': 'Mexico', 'flag': 'https://flagcdn.com/mx.svg'},
      },
      'professions': [
        {'name': 'Palm Reader'},
      ],
      'review_summary': {'rating': 4.8, 'review_count': 12},
      'certificates': [{}],
      'language_items': [
        {'code': 'en', 'title': 'English'},
      ],
      'years_of_experience': 0,
    });
    expect(e.name, 'BlueNet Hospitals');
    expect(e.country, 'Mexico');
    expect(e.flag, 'https://flagcdn.com/w40/mx.png');
    expect(e.subtitle, 'Palm Reader');
    expect(e.hasRating, isTrue);
    expect(e.verified, isTrue);
    expect(e.languages, ['English']);
    expect(e.yearsOfExperience, isNull);
  });

  test('MarketMapper.offer: tên shop, giá theo hình thức, lịch, vị trí', () {
    final o = MarketMapper.offer({
      'id': 5,
      'seller_id': 100,
      'seller': {
        'id': 100,
        'first_name': 'Dao',
        'last_name': 'Hong',
        'seller_profile': {
          'shop_name': 'Dao Hong Tham',
          'country': {'title': 'Vietnam', 'code': 'VN'},
        },
      },
      'detail': 'I can help',
      'price_remote': null,
      'price_at_office': 7,
      'price_at_home': 5,
      'schedule': {
        'mon': [
          {'from': '09:00', 'to': '12:00'},
        ],
        'note': 'ignored',
      },
      'service_location': {'city': 'Hanoi', 'radius_km': 5},
    });
    expect(o.sellerName, 'Dao Hong Tham');
    expect(o.country, 'Vietnam');
    expect(o.prices.map((p) => p.mode), ['at_office', 'at_home']);
    expect(o.minPrice, 5);
    expect(o.schedule.single.times, '09:00–12:00');
    expect(o.serviceLocation.map((l) => l.key), ['city', 'radius_km']);
  });

  test('MarketMapper.request: ngân sách min = max hiện 1 giá', () {
    final exact = MarketMapper.request({
      'id': 1,
      'description': 'x',
      'min_budget': 80,
      'max_budget': 80,
      'currency': 'EUR',
    });
    expect(exact.budget, isA<BudgetExact>());
    expect((exact.budget! as BudgetExact).amount, '€80');
    final range = MarketMapper.request({
      'id': 2,
      'description': 'y',
      'min_budget': 60,
      'max_budget': 90,
      'user': {
        'first_name': 'Anna',
        'country': {'title': 'USA'},
      },
      'category': {'name': 'Health Pro Advisory'},
      'categories': [
        {'name': 'Health Pro Advisory'},
      ],
    });
    expect(range.budget, isA<BudgetRange>());
    expect(range.authorFirstName, 'Anna');
    expect(range.country, 'USA');
    expect(range.categories, ['Health Pro Advisory']);
  });

  group('EngagementCubit (web EngagementProvider)', () {
    late _Repo repo;
    late EngagementCubit cubit;

    setUp(() {
      repo = _Repo();
      cubit = EngagementCubit(
        target: EngagementTarget.service,
        getEngagement: GetEngagementUseCase(repo),
        setEngagement: SetEngagementUseCase(repo),
        storage: _Storage(),
      );
    });

    tearDown(() => cubit.close());

    test('nạp summary rồi lưu: optimistic + đồng bộ số từ server', () async {
      await cubit.load([1, null, 2]);
      expect(cubit.state.of(1).saves, 2);
      final done = cubit.toggle(1, EngagementKind.save);
      expect(cubit.state.of(1).saved, isTrue);
      expect(cubit.state.of(1).saves, 3);
      expect(cubit.state.isPending(1, EngagementKind.save), isTrue);
      await done;
      expect(cubit.state.of(1).saves, 5);
      expect(cubit.state.isPending(1, EngagementKind.save), isFalse);
    });

    test('lỗi → trả lại trạng thái cũ và báo lỗi', () async {
      await cubit.load([1]);
      repo.failToggle = true;
      await cubit.toggle(1, EngagementKind.like);
      expect(cubit.state.of(1).liked, isFalse);
      expect(cubit.state.of(1).likes, 0);
      expect(cubit.state.errorCount, 1);
    });
  });

  test(
    'MarketListingBloc: tải thêm trang kế, bỏ trùng id, hết trang thì dừng',
    () async {
      final repo = _Repo();
      final bloc = MarketListingBloc<MarketServiceEntity>(
        fetch: (page) => GetMarketServicesUseCase(repo)(
          MarketPageParams(
            categorySlug: MarketCategory.longevity.slug,
            page: page,
            limit: 10,
            newestFirst: true,
          ),
        ),
        idOf: (s) => s.id,
      );
      bloc.add(const MarketListingStarted());
      await bloc.stream.firstWhere((s) => s.status == ListingStatus.success);
      expect(bloc.state.items.map((s) => s.id), [10, 1]);
      bloc.add(const MarketListingNextPageRequested());
      await bloc.stream.firstWhere((s) => s.page == 2 && !s.loadingMore);
      expect(bloc.state.items.map((s) => s.id), [10, 1, 20]);
      bloc.add(const MarketListingNextPageRequested());
      await bloc.stream.firstWhere((s) => s.page == 3 && !s.loadingMore);
      expect(bloc.state.hasMore, isFalse);
      expect(repo.serviceCalls.last, (
        slug: 'longevity-1',
        page: 3,
        limit: 10,
        newest: true,
      ));
      await bloc.close();
    },
  );

  test('CategoryMarketBloc: mục lỗi không chặn các mục khác', () async {
    final repo = _Repo()..failExperts = true;
    final bloc = CategoryMarketBloc(
      getServices: GetMarketServicesUseCase(repo),
      getExperts: GetMarketExpertsUseCase(repo),
      getOffers: GetPublicOffersUseCase(repo),
      getRequests: GetPublicRequestsUseCase(repo),
      getSolutions: GetHealthSolutionsUseCase(repo),
    )..add(const CategoryMarketStarted(MarketCategory.healthProAdvisory));
    await bloc.stream.firstWhere(
      (s) => MarketSectionKind.values.every((k) => !s.isLoading(k)),
    );
    expect(bloc.state.status(MarketSectionKind.sellers), SectionStatus.failure);
    expect(
      bloc.state.status(MarketSectionKind.services),
      SectionStatus.success,
    );
    // Mục Selling: 6 service của category, thứ tự mặc định BE.
    expect(repo.serviceCalls.single, (
      slug: 'health-pro-advisory-1',
      page: 1,
      limit: 6,
      newest: false,
    ));
    await bloc.close();
  });
}
