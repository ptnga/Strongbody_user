import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/modules/social_market/data/mappers/market_mapper.dart';
import 'package:strongbody_buyer/modules/social_market/data/repositories/social_market_repository_impl.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_category.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_feed_entities.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_listing_entities.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/medical_travel_entities.dart';
import 'package:strongbody_buyer/modules/social_market/domain/repositories/social_market_repository.dart';
import 'package:strongbody_buyer/modules/social_market/domain/usecases/social_market_use_cases.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/category_market/category_market_bloc.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/engagement/engagement_cubit.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/market_navigation.dart';

class _Storage implements GlobalStorage {
  @override
  bool get isLoggedIn => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Repository giả: ghi lại query service (qua `servicesQuery` thật) + phase coordinator.
class _Repo implements SocialMarketRepository {
  final serviceQueries = <Map<String, dynamic>>[];
  final coordinatorCalls = <CoordinatorsPhase>[];
  final expertCalls = <MarketPageScope?>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  static MarketServiceEntity _s(int id) =>
      MarketMapper.service({'id': id, 'title': 'S$id', 'price': id});

  @override
  Future<Either<Failure, MarketPage<MarketServiceEntity>>> getServices({
    required String categorySlug,
    required int page,
    required int limit,
    bool newestFirst = false,
    MarketPageScope? scope,
    String? orderBy,
    String? orderDir,
    String? language,
  }) async {
    final q = SocialMarketRepositoryImpl.servicesQuery(
      categorySlug: categorySlug,
      page: page,
      limit: limit,
      newestFirst: newestFirst,
      scope: scope,
      orderBy: orderBy,
      orderDir: orderDir,
      language: language,
    );
    serviceQueries.add(q);
    // spotlight: 1..8 · services: 1..12 · language: 3..12.
    final ids = q['order_by'] == 'quality_score'
        ? [for (var i = 1; i <= 8; i++) i]
        : q['language'] != null
        ? [for (var i = 3; i <= 12; i++) i]
        : [for (var i = 1; i <= 12; i++) i];
    return Right(
      MarketPage(items: ids.map(_s).toList(), total: ids.length, totalPages: 1),
    );
  }

  @override
  Future<Either<Failure, MarketPage<MarketExpertEntity>>> getExperts({
    required String categorySlug,
    required int page,
    required int limit,
    MarketPageScope? scope,
  }) async {
    expertCalls.add(scope);
    return const Right(MarketPage(items: [], total: 0, totalPages: 0));
  }

  @override
  Future<
    Either<Failure, ({List<MarketExpertEntity> items, CoordinatorsCursor next})>
  >
  getCoordinators(CoordinatorsPhase cursor) async {
    coordinatorCalls.add(cursor);
    return Right((
      items: [
        for (var i = 1; i <= 12; i++)
          MarketMapper.coordinator({'id': i, 'shop_name': 'C$i'}),
      ],
      next: const CoordinatorsDone(),
    ));
  }

  @override
  Future<Either<Failure, List<MarketDestination>>> getDestinations() async =>
      Right([
        MarketMapper.destination({'id': 1, 'title': 'Thailand', 'code': 'TH'})!,
      ]);

  @override
  Future<Either<Failure, Map<int, EngagementState>>> getEngagement(
    EngagementTarget target,
    List<int> ids,
  ) async => Right({for (final id in ids) id: const EngagementState()});
}

void main() {
  group('servicePrice (web 79f0b5c8a: 1 giá hoặc khoảng giá Tư vấn)', () {
    test(
      'Tư vấn: khoảng price – price_max, nhãn consultation, không gạch giá',
      () {
        final s = MarketMapper.service({
          'id': 1,
          'title': 'Nutrition consult',
          'pricing_mode': 'consultation',
          'price': 50,
          'price_max': 200,
          'original_price': 300,
          'delivery_options': [
            {'delivery_type': 'remote', 'price': 10},
          ],
        });
        expect(s.isConsultation, isTrue);
        expect(s.pricingMode, 'consultation');
        expect(s.priceMax, 200);
        expect(s.price!.consultation, isTrue);
        expect(s.price!.amount, 50);
        expect(s.price!.max, 200);
        expect(s.price!.text, r'$50 – $200');
        expect(s.strikePrice, isNull);
        // Inquiry lưu khoảng giá (web `inquiryItem.price = price.original`).
        expect(MarketNavigation.inquiryPrice(s.price), r'$50 – $200');
      },
    );

    test('Đặt ngay: 1 giá của service, bỏ giá theo hình thức nhận', () {
      final s = MarketMapper.service({
        'id': 2,
        'price': 80,
        // price_max chỉ có nghĩa với Tư vấn.
        'price_max': 120,
        'original_price': 100,
        'delivery_options': [
          {'delivery_type': 'remote', 'price': 45},
          {'delivery_type': 'at_home', 'price': 60},
        ],
      });
      expect(s.isConsultation, isFalse);
      expect(s.price!.text, r'$80');
      expect(s.price!.max, isNull);
      expect(s.price!.from, isFalse);
      expect(s.strikePrice, r'$100');
      expect(MarketNavigation.inquiryPrice(s.price), r'$80');
    });

    test('Tư vấn có price_max = price → hiện 1 giá', () {
      final s = MarketMapper.service({
        'id': 3,
        'pricing_mode': 'consultation',
        'price': 70,
        'price_max': 70,
      });
      expect(s.price!.text, r'$70');
      expect(s.price!.consultation, isTrue);
    });
  });

  group(
    'query /public/services + /expert/balanced (web data.ts / services.ts)',
    () {
      final longevity = MarketPageScope.of(MarketCategory.longevity);

      test('Services (fetchCategoryPackages): không page, thứ tự BE', () {
        expect(
          SocialMarketRepositoryImpl.servicesQuery(
            page: 1,
            limit: 12,
            scope: longevity,
          ),
          {'limit': 12, 'category_slug': 'longevity-1'},
        );
      });

      test('Spotlight: page 1 + order_by quality_score DESC', () {
        expect(
          SocialMarketRepositoryImpl.servicesQuery(
            page: 1,
            limit: 10,
            scope: longevity,
            orderBy: 'quality_score',
            orderDir: 'DESC',
          ),
          {
            'page': 1,
            'limit': 10,
            'order_by': 'quality_score',
            'order_dir': 'DESC',
            'category_slug': 'longevity-1',
          },
        );
      });

      test('Listing theo ngôn ngữ: mới nhất trước + language', () {
        expect(
          SocialMarketRepositoryImpl.servicesQuery(
            page: 2,
            limit: 10,
            newestFirst: true,
            scope: longevity,
            language: 'vi',
          ),
          {
            'page': 2,
            'limit': 10,
            'order_by': 'created_at',
            'order_dir': 'DESC',
            'category_slug': 'longevity-1',
            'language': 'vi',
          },
        );
      });

      test(
        'Medical Travel: service lọc theo cờ, provider gửi cả slug + cờ',
        () {
          expect(
            SocialMarketRepositoryImpl.servicesQuery(
              page: 1,
              limit: 12,
              scope: MarketPageScope.medicalTravel,
            ),
            {'limit': 12, 'is_medical_travel': true},
          );
          expect(
            SocialMarketRepositoryImpl.expertsQuery(
              page: 1,
              limit: 10,
              scope: MarketPageScope.medicalTravel,
            ),
            {
              'page': 1,
              'limit': 10,
              'category_slug': 'medical-travel-2',
              'is_medical_travel': true,
              'sort': 'score_rank',
            },
          );
        },
      );

      test('route listing kèm ?lang=', () {
        expect(
          MarketRoutes.scopeServices(longevity, language: 'vi'),
          '/socialMarket/longevity/services?lang=vi',
        );
        expect(
          MarketRoutes.scopeProviders(MarketPageScope.medicalTravel),
          '/socialMarket/medical-travel/providers',
        );
      });
    },
  );

  test(
    'splitServiceSections: bỏ trùng giữa spotlight / services / ngôn ngữ',
    () {
      List<MarketServiceEntity> ids(Iterable<int> v) => [
        for (final id in v) MarketMapper.service({'id': id}),
      ];
      final r = CategoryMarketBloc.splitServiceSections(
        spotlight: ids([1, 2, 3, 4, 5, 6, 7]),
        latest: ids([1, 8, 2, 9, 10, 11, 12, 13, 14]),
        language: ids([3, 9, 15, 16]),
      );
      expect(r.spotlight!.map((s) => s.id), [1, 2, 3, 4, 5, 6]);
      expect(r.main!.map((s) => s.id), [8, 9, 10, 11, 12, 13]);
      expect(r.language!.map((s) => s.id), [15, 16]);
      // Nguồn lỗi → null (mục đó báo lỗi / ẩn), không kéo theo nguồn khác.
      final failed = CategoryMarketBloc.splitServiceSections(
        spotlight: null,
        latest: ids([1]),
        language: null,
      );
      expect(failed.spotlight, isNull);
      expect(failed.main!.map((s) => s.id), [1]);
    },
  );

  group('expert / seller (web adapters.ts + slim.ts)', () {
    test(
      'profession rác bị bỏ, tên shop của provider, avatar provider trước',
      () {
        final e = MarketMapper.expert({
          'id': 1,
          'shop_name': 'undefined',
          'profession': '76',
          'professions': [
            {'name': ' '},
            {'name': 'Nutritionist'},
          ],
          'is_org_owner': true,
          'organization': {'id': 3, 'name': 'Green Clinic', 'logo': 'logo.png'},
          'user': {'profile_picture': 'me.png', 'is_mobile_verified': true},
          'seller_verified': true,
        });
        expect(e.subtitle, 'Nutritionist');
        expect(e.name, 'Green Clinic');
        expect(e.organization, 'Green Clinic');
        expect(e.avatar, 'me.png');
        expect(e.verified, isTrue);
        expect(
          e.verifications,
          const MarketVerifications(identity: true, phone: true),
        );
        expect(e.cardVerifications!.count, 2);
      },
    );

    test(
      '"undefined" profession → category; coordinator chỉ có cờ danh tính',
      () {
        final e = MarketMapper.expert({
          'id': 2,
          'shop_name': 'Dr B',
          'profession': 'undefined',
          'category': [
            {'id': 1, 'name': 'Longevity'},
          ],
        });
        expect(e.subtitle, 'Longevity');
        expect(e.verifications, isNull);
        final c = MarketMapper.coordinator({'id': 3, 'seller_verified': true});
        expect(c.cardVerifications, const MarketVerifications(identity: true));
      },
    );

    test('seller của service: xác minh từ verification.checks + ngôn ngữ', () {
      final s = MarketMapper.service({
        'id': 4,
        'user': {
          'id': 9,
          'profession': 'null',
          'professions': [
            {'name': 'Coach'},
          ],
          'verification': {
            'checks': [
              {'key': 'identity', 'state': 'verified'},
              {'key': 'phone', 'state': 'in_review'},
              {'key': 'profession', 'state': 'verified'},
            ],
          },
          'seller_profile': {
            'shop_name': 'Fit Co',
            'supported_languages': ['en', 'vi'],
          },
        },
      });
      expect(s.seller.profession, 'Coach');
      expect(
        s.seller.verifications,
        const MarketVerifications(identity: true, diploma: true),
      );
      expect(s.seller.verified, isTrue);
      expect(s.seller.languages, ['English', 'Vietnamese']);
    });

    test('BE cũ chưa có checks → suy từ seller_verified / certificates', () {
      final seller = MarketMapper.seller({
        'id': 5,
        'is_mobile_verified': true,
        'seller_profile': {
          'shop_name': 'Old',
          'certificates': [{}],
        },
      });
      expect(
        seller.verifications,
        const MarketVerifications(phone: true, diploma: true),
      );
      expect(MarketMapper.seller({'id': 6}).verifications, isNull);
    });
  });

  test('EngagementCubit.markContacted: +1 contacted đúng một lần', () async {
    final repo = _Repo();
    final cubit = EngagementCubit(
      target: EngagementTarget.service,
      getEngagement: GetEngagementUseCase(repo),
      setEngagement: SetEngagementUseCase(repo),
      storage: _Storage(),
    );
    cubit.markContacted(7);
    cubit.markContacted(7);
    expect(cubit.state.of(7).contacts, 1);
    expect(cubit.state.of(7).contacted, isTrue);
    expect(
      MarketMapper.engagement({
        'target_id': 7,
        'contacts': 2,
        'my_state': {'contacted': true},
      })!.value.contacted,
      isTrue,
    );
    await cubit.close();
  });

  test(
    'CategoryMarketBloc Medical Travel: destinations + coordinator, lọc theo cờ',
    () async {
      final repo = _Repo();
      final bloc =
          CategoryMarketBloc(
            getServices: GetMarketServicesUseCase(repo),
            getExperts: GetMarketExpertsUseCase(repo),
            getCoordinators: GetCoordinatorsUseCase(repo),
            getDestinations: GetDestinationsUseCase(repo),
          )..add(
            const CategoryMarketStarted(
              MarketPageScope.medicalTravel,
              language: 'vi',
            ),
          );
      await bloc.stream.firstWhere(
        (s) => s.sections.every((k) => !s.isLoading(k)),
      );
      final s = bloc.state;
      expect(s.sections.first, MarketSectionKind.destinations);
      expect(s.destinations.single.country, 'Thailand');
      // Coordinator: phase category trang 1, tối đa 9 card; không gọi /expert/balanced.
      expect(repo.coordinatorCalls.single.category, isTrue);
      expect(repo.coordinatorCalls.single.page, 1);
      expect(s.experts.length, 9);
      expect(repo.expertCalls, isEmpty);
      expect(
        repo.serviceQueries.every(
          (q) =>
              q['is_medical_travel'] == true && !q.containsKey('category_slug'),
        ),
        isTrue,
      );
      expect(repo.serviceQueries.last['language'], 'vi');
      expect(s.spotlight.map((e) => e.id), [1, 2, 3, 4, 5, 6]);
      expect(s.services.map((e) => e.id), [7, 8, 9, 10, 11, 12]);
      // Mọi service ngôn ngữ đều đã có ở 2 mục trên → mục ẩn.
      expect(s.languageServices, isEmpty);
      await bloc.close();
    },
  );
}
