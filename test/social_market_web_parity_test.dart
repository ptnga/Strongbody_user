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
    String? subCategory,
    String? classification,
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

  final sectionCalls = <List<String>>[];

  @override
  Future<Either<Failure, List<MarketCategorySection>>> getServicesByCategory({
    required List<String> categories,
    required int per,
  }) async {
    sectionCalls.add(categories);
    return Right([
      MarketCategorySection(
        category: const MarketBusinessCategory(
          slug: 'dental-clinic',
          name: 'Dental Clinic',
        ),
        total: 3,
        items: [_s(1), _s(2), _s(3)],
      ),
    ]);
  }

  @override
  Future<Either<Failure, MarketPage<MarketExpertEntity>>> getExperts({
    required String categorySlug,
    required int page,
    required int limit,
    MarketPageScope? scope,
  }) async {
    expertCalls.add(scope);
    return Right(
      MarketPage(
        items: [
          for (var i = 1; i <= 12; i++)
            MarketMapper.expert({'id': i, 'shop_name': 'E$i'}),
        ],
        total: 12,
        totalPages: 2,
      ),
    );
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

      final need = longevity.need!;

      test('Trang nhãn: service theo các category doanh nghiệp của nhãn', () {
        expect(
          SocialMarketRepositoryImpl.servicesQuery(
            page: 1,
            limit: 12,
            scope: longevity,
          ),
          {'limit': 12, 'provider_category_slugs': need.services.join(',')},
        );
      });

      test('Listing đã chọn category + tab classification (web data.ts)', () {
        expect(
          SocialMarketRepositoryImpl.servicesQuery(
            page: 2,
            limit: 10,
            newestFirst: true,
            scope: longevity,
            subCategory: 'yoga-studio-center',
            classification: 'hatha-yoga',
          ),
          {
            'page': 2,
            'limit': 10,
            'order_by': 'created_at',
            'order_dir': 'DESC',
            'provider_category_slugs': 'yoga-studio-center',
            'service_classification_slug': 'hatha-yoga',
          },
        );
        // Category không thuộc nhãn → cả nhãn, bỏ tab classification.
        final q = SocialMarketRepositoryImpl.servicesQuery(
          page: 1,
          limit: 10,
          newestFirst: true,
          scope: longevity,
          subCategory: 'dental-clinic',
          classification: 'x',
        );
        expect(q['provider_category_slugs'], need.services.join(','));
        expect(q.containsKey('service_classification_slug'), isFalse);
      });

      test('Experts của nhãn: category HOẶC profession, sort score', () {
        expect(
          SocialMarketRepositoryImpl.expertsQuery(
            page: 1,
            limit: 9,
            scope: MarketPageScope.medicalTravel,
          ),
          {
            'page': 1,
            'limit': 9,
            'provider_category_slugs': MarketPageScope
                .medicalTravel
                .need!
                .services
                .join(','),
            'profession_slugs': 'dentist-2026',
            'sort': 'score',
          },
        );
        // Longevity gồm cả category Health product trong phạm vi expert.
        expect(
          SocialMarketRepositoryImpl.expertsQuery(
            page: 1,
            limit: 9,
            scope: longevity,
          )['provider_category_slugs'],
          [...need.services, ...need.products].join(','),
        );
      });

      test('route listing kèm ?category=', () {
        expect(
          MarketRoutes.scopeServices(longevity, category: 'dental-clinic'),
          '/socialMarket/longevity/services?category=dental-clinic',
        );
        expect(
          MarketRoutes.scopeProviders(MarketPageScope.medicalTravel),
          '/socialMarket/medical-travel/providers',
        );
      });
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
        // Người đại diện organization → logo của organization (web 6a0496ba6).
        expect(e.avatar, 'logo.png');
        expect(e.verified, isTrue);
        expect(
          e.verifications,
          const MarketVerifications(identity: true, phone: true),
        );
        expect(e.cardVerifications!.count, 2);
      },
    );

    test(
      '"undefined" profession → không lấy category; coordinator chỉ có cờ danh tính',
      () {
        final e = MarketMapper.expert({
          'id': 2,
          'shop_name': 'Dr B',
          'profession': 'undefined',
          'category': [
            {'id': 1, 'name': 'Longevity'},
          ],
        });
        // Web providerLine: category tự gán không mô tả người bán → không có dòng phụ.
        expect(e.subtitle, isNull);
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
    'CategoryMarketBloc Medical Travel: destinations + section theo category + experts của nhãn',
    () async {
      final repo = _Repo();
      final bloc =
          CategoryMarketBloc(
            getServicesByCategory: GetServicesByCategoryUseCase(repo),
            getExperts: GetMarketExpertsUseCase(repo),
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
      expect(
        repo.sectionCalls.single,
        MarketPageScope.medicalTravel.need!.services,
      );
      expect(s.categorySections.single.items.map((e) => e.id), [1, 2]);
      // Experts: /expert/balanced theo nhãn (không còn hàng coordinator), tối đa 9.
      expect(repo.coordinatorCalls, isEmpty);
      expect(repo.expertCalls.single, MarketPageScope.medicalTravel);
      expect(s.experts.length, 9);
      await bloc.close();
    },
  );
}
