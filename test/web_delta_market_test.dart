// Social Market theo web live-v1 5141e6132..df3c3b780: classification trên card, nhãn
// "Browse by need" theo category doanh nghiệp, tab classification của listing, provider
// theo loại / organization, xác minh theo checks, Like · Save ở chi tiết, "0 saved".
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/modules/social_market/data/mappers/market_mapper.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_category.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_feed_entities.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_listing_entities.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_need.dart';
import 'package:strongbody_buyer/modules/social_market/domain/repositories/social_market_repository.dart';
import 'package:strongbody_buyer/modules/social_market/domain/usecases/social_market_use_cases.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/category_market/category_market_bloc.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/engagement/engagement_cubit.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/market_listing/listing_facets_cubit.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/market_listing/market_listing_bloc.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/listing_facets.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_service_card.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_ui.dart';

class _Storage implements GlobalStorage {
  @override
  bool get isLoggedIn => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements SocialMarketRepository {
  final saves = <int, int>{};
  final classificationCalls = <String>[];
  final sectionCalls = <List<String>>[];
  bool failClassifications = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Either<Failure, Map<int, EngagementState>>> getEngagement(
    EngagementTarget target,
    List<int> ids,
  ) async =>
      Right({for (final id in ids) id: EngagementState(saves: saves[id] ?? 0)});

  @override
  Future<Either<Failure, List<MarketCategorySection>>> getServicesByCategory({
    required List<String> categories,
    required int per,
  }) async {
    sectionCalls.add(categories);
    return const Right([
      MarketCategorySection(
        category: MarketBusinessCategory(slug: 'yoga-studio-center', name: 'Y'),
        total: 5,
        items: [],
      ),
      MarketCategorySection(
        category: MarketBusinessCategory(slug: 'pilates-studio', name: 'P'),
        total: 0,
        items: [],
      ),
    ]);
  }

  @override
  Future<Either<Failure, MarketClassifications>> getServiceClassifications(
    String categorySlug,
  ) async {
    classificationCalls.add(categorySlug);
    if (failClassifications) return Left(ServerFailure('x'));
    return Right(
      MarketMapper.classifications({
        'category': {'id': 7, 'slug': categorySlug, 'name': 'Yoga Studio'},
        'list': [
          {'id': 1, 'slug': 'hatha', 'name': 'Hatha', 'count': 3},
          {'id': 2, 'slug': 'empty', 'name': 'Empty', 'count': 0},
        ],
      }),
    );
  }
}

EngagementCubit _engagement(_Repo repo) => EngagementCubit(
  target: EngagementTarget.service,
  getEngagement: GetEngagementUseCase(repo),
  setEngagement: SetEngagementUseCase(repo),
  storage: _Storage(),
);

Future<void> _pump(WidgetTester tester, Widget child, EngagementCubit cubit) {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('service card data (f76eed762 / 428000b92 / eb66bc6af)', () {
    test('classification từ service_classifications (bỏ tên rỗng, trùng)', () {
      final s = MarketMapper.service({
        'id': 1,
        'service_classifications': [
          {'id': 1, 'name': 'Hatha yoga'},
          {'id': 2, 'name': ' '},
          {'id': 3, 'name': 'Prenatal'},
          {'id': 4, 'name': 'Hatha yoga'},
        ],
      });
      expect(s.classifications, ['Hatha yoga', 'Prenatal']);
      expect(MarketMapper.service({'id': 2}).classifications, isEmpty);
      // Medical Travel giữ classification.
      final mt = MarketMapper.medicalService({
        'id': 3,
        'service_classifications': [
          {'name': 'Dental implants'},
        ],
      });
      expect(mt.classifications, ['Dental implants']);
    });

    test(
      'service thuộc organization → card hiện organization, chat tới seller',
      () {
        final s = MarketMapper.service({
          'id': 1,
          'user': {
            'id': 77,
            'profile_picture': 'me.png',
            'seller_profile': {
              'shop_name': 'Dr Lan',
              'supported_languages': ['vi'],
              'addresses': [
                {'country': 'Vietnam', 'country_code': 'VN'},
              ],
            },
          },
          'organization': {
            'id': 5,
            'name': 'Sunrise Clinic',
            'logo': 'org.png',
            'languages': ['en'],
            'country': {'title': 'Thailand', 'code': 'TH'},
          },
        });
        expect(s.seller.id, 77);
        expect(s.seller.shopName, 'Sunrise Clinic');
        expect(s.seller.avatar, 'org.png');
        expect(s.seller.country, 'Thailand');
        expect(s.seller.flag, 'https://flagcdn.com/w40/th.png');
        expect(s.seller.languages, ['English']);
        expect(s.place, 'Thailand');
        // Organization thiếu tên → giữ seller.
        final plain = MarketMapper.service({
          'id': 2,
          'user': {
            'id': 8,
            'seller_profile': {'shop_name': 'Solo'},
          },
          'organization': {'id': 9, 'name': ''},
        });
        expect(plain.seller.shopName, 'Solo');
      },
    );

    test('chi tiết: người đứng tên + avatar là organization của service', () {
      final d = MarketMapper.serviceDetail({
        'id': 1,
        'user_id': 2,
        'user': {'profile_picture': 'seller.png'},
        'seller_profile': {'shop_name': 'Seller'},
        'organization': {'id': 3, 'name': 'Org', 'logo': 'org.png'},
      })!;
      expect(d.providerName, 'Org');
      expect(d.providerAvatar, 'org.png');
      final own = MarketMapper.serviceDetail({
        'id': 1,
        'user': {'profile_picture': 'seller.png'},
        'seller_profile': {'shop_name': 'Seller'},
      })!;
      expect(own.providerName, 'Seller');
      expect(own.providerAvatar, 'seller.png');
    });
  });

  group('xác minh theo checks (4bb4eb9d8 / 75b3e7e75)', () {
    test('mọi mục verified, kể cả tổ chức và loại BE thêm sau', () {
      final v = MarketMapper.verificationsFromChecks([
        {'key': 'identity', 'state': 'verified'},
        {'key': 'phone', 'state': 'in_review'},
        {'key': 'organisation', 'state': 'verified'},
        {'key': 'business_license', 'state': 'verified'},
      ])!;
      expect(v.identity, isTrue);
      expect(v.phone, isFalse);
      expect(v.organization, isTrue);
      expect(v.others, ['business_license']);
      expect(v.count, 3);
      expect(MarketMapper.verificationsFromChecks([]), isNull);
    });

    test('expert đọc user.verification.checks', () {
      final e = MarketMapper.expert({
        'id': 1,
        'shop_name': 'A',
        'seller_verified': false,
        'user': {
          'verification': {
            'checks': [
              {'key': 'organisation', 'state': 'verified'},
            ],
          },
        },
      });
      expect(e.cardVerifications!.organization, isTrue);
      expect(e.cardVerifications!.count, 1);
    });
  });

  group('dòng phụ theo loại provider (6a0496ba6)', () {
    test('Business: category doanh nghiệp, không dùng nghề', () {
      final e = MarketMapper.expert({
        'id': 1,
        'shop_name': 'Spa',
        'provider_type': 'wellness',
        'profession': 'Therapist',
        'provider_category': {
          'slug': 'spa-wellness-center',
          'name': 'Spa & Wellness Center',
        },
      });
      expect(e.subtitle, isNull);
      expect(e.providerCategory, (
        slug: 'spa-wellness-center',
        name: 'Spa & Wellness Center',
      ));
      expect(
        MarketNeed.categoryName('spa-wellness-center', 'Spa', 'vi'),
        'Spa / Trung tâm chăm sóc sức khỏe và thư giãn',
      );
      expect(
        MarketNeed.categoryName('spa-wellness-center', 'Spa', 'en'),
        'Spa',
      );
    });

    test(
      'Expert: profession onboarding trước chữ nghề tự gõ; seller cũ ngược lại',
      () {
        final expert = MarketMapper.expert({
          'id': 1,
          'provider_type': 'expert',
          'profession': 'Coach',
          'professions': [
            {'name': 'Dietitian'},
          ],
        });
        expect(expert.subtitle, 'Dietitian');
        final legacy = MarketMapper.expert({
          'id': 2,
          'profession': 'Coach',
          'professions': [
            {'name': 'Dietitian'},
          ],
        });
        expect(legacy.subtitle, 'Coach');
      },
    );
  });

  test('offer: chỉ tên shop / organization, không rơi về họ tên tài khoản', () {
    final noShop = MarketMapper.offer({
      'id': 1,
      'seller': {'id': 2, 'first_name': 'Real', 'last_name': 'Name'},
    });
    expect(noShop.sellerName, isNull);
    final org = MarketMapper.offer({
      'id': 2,
      'seller': {
        'id': 3,
        'profile_picture': 'me.png',
        'seller_profile': {
          'shop_name': 'Me',
          'is_org_owner': true,
          'organization': {'id': 4, 'name': 'Org Co', 'logo': 'org.png'},
        },
      },
    });
    expect(org.sellerName, 'Org Co');
    expect(org.sellerAvatar, 'org.png');
  });

  group('nhãn "Browse by need" (23152f66f)', () {
    test('Mental Health thay Health Pro Advisory trên menu', () {
      expect(MarketCategory.values.map((c) => c.route), [
        'longevity',
        'mental',
        'personal-helper',
      ]);
      expect(MarketCategory.fromRoute('health-pro-advisory'), isNull);
    });

    test('phạm vi service / provider của nhãn', () {
      final mental = MarketPageScope.of(MarketCategory.mental);
      final need = mental.need!;
      expect(mental.servicesScope, {
        'provider_category_slugs': need.services.join(','),
      });
      expect(mental.servicesScopeFor('psychiatric-hospital'), {
        'provider_category_slugs': 'psychiatric-hospital',
      });
      // Chip không thuộc nhãn → cả nhãn.
      expect(
        mental.servicesScopeFor('dental-clinic')['provider_category_slugs'],
        need.services.join(','),
      );
      expect(
        mental.providersScope['profession_slugs'],
        contains('psychologist-2026'),
      );
      expect(
        const MarketNeed(services: [], professions: []).servicesScope(),
        'none',
      );
    });

    test('section theo category: bỏ category rỗng, mỗi section 2 service', () {
      final sections = CategoryMarketBloc.visibleSections([
        MarketCategorySection(
          category: const MarketBusinessCategory(slug: 'a', name: 'A'),
          total: 9,
          items: [
            for (var i = 1; i <= 3; i++) MarketMapper.service({'id': i}),
          ],
        ),
        const MarketCategorySection(
          category: MarketBusinessCategory(slug: 'b', name: 'B'),
          total: 0,
          items: [],
        ),
      ]);
      expect(sections.single.items.map((s) => s.id), [1, 2]);
    });

    test('by-category + classifications mapper', () {
      final section = MarketMapper.categorySection({
        'category': {'id': 1, 'slug': 'dental-clinic', 'name': 'Dental Clinic'},
        'total': 12,
        'items': [
          {'id': 5, 'title': 'Implant'},
        ],
      })!;
      expect(section.total, 12);
      expect(section.items.single.title, 'Implant');
      expect(MarketMapper.categorySection({'total': 1}), isNull);
      final c = MarketMapper.classifications({'category': null, 'list': []});
      expect(c.category, isNull);
    });
  });

  group('listing đã chọn category: tab classification (b2ff5aacc …)', () {
    final scope = MarketPageScope.of(MarketCategory.longevity);

    test('chưa chọn category → chip các category có service', () async {
      final repo = _Repo();
      final cubit = ListingFacetsCubit(
        getSections: GetServicesByCategoryUseCase(repo),
        getClassifications: GetServiceClassificationsUseCase(repo),
      );
      await cubit.load(scope, null);
      expect(cubit.state.chips.map((c) => c.slug), ['yoga-studio-center']);
      expect(repo.classificationCalls, isEmpty);
      await cubit.close();
    });

    test('đã chọn category → tab classification + tên category', () async {
      final repo = _Repo();
      final cubit = ListingFacetsCubit(
        getSections: GetServicesByCategoryUseCase(repo),
        getClassifications: GetServiceClassificationsUseCase(repo),
      );
      await cubit.load(scope, 'Yoga-Studio-Center');
      expect(cubit.state.category, 'yoga-studio-center');
      expect(cubit.state.selected!.name, 'Yoga Studio');
      expect(cubit.state.tabs.map((t) => t.slug), ['hatha', 'empty']);
      expect(repo.sectionCalls, isEmpty);
      // Category không thuộc nhãn → coi như chưa chọn.
      expect(ListingFacetsCubit.validCategory(scope, 'dental-clinic'), isNull);
      repo.failClassifications = true;
      await cubit.load(scope, 'yoga-studio-center');
      expect(cubit.state.status, SectionStatus.failure);
      await cubit.close();
    });

    test('đổi tab → tải lại trang 1 với classification mới', () async {
      final calls = <(int, String?)>[];
      final bloc = MarketListingBloc<int>(
        fetch: (page, filter) async {
          calls.add((page, filter));
          return Right(
            MarketPage(
              items: [page * 10 + (filter?.length ?? 0)],
              total: 2,
              totalPages: 2,
            ),
          );
        },
        idOf: (i) => i,
      )..add(const MarketListingStarted());
      await bloc.stream.firstWhere((s) => s.status == ListingStatus.success);
      bloc.add(const MarketListingNextPageRequested());
      await bloc.stream.firstWhere((s) => s.page == 2 && !s.loadingMore);
      bloc.add(const MarketListingFilterChanged('hatha'));
      await bloc.stream.firstWhere(
        (s) => s.status == ListingStatus.success && s.filter == 'hatha',
      );
      expect(bloc.state.items, [15]);
      expect(bloc.state.page, 1);
      // Cùng tab → không tải lại.
      bloc.add(const MarketListingFilterChanged('hatha'));
      await Future<void>.delayed(Duration.zero);
      expect(calls, [(1, null), (2, null), (1, 'hatha')]);
      await bloc.close();
    });

    test('thanh tab: vừa hết thì không cần More; tràn thì gom + tab cắt chữ', () {
      expect(
        ClassificationTabs.fitTabs(
          available: 300,
          widths: [50, 80, 80],
          more: 70,
        ),
        (fit: 2, partial: false),
      );
      // All 50 + More 70 + gap: vừa 1 tab 100 (đã dùng 228), còn 320 - 232 = 88 ≥ 72 → thêm
      // 1 tab cắt chữ.
      expect(
        ClassificationTabs.fitTabs(
          available: 320,
          widths: [50, 100, 140, 120],
          more: 70,
        ),
        (fit: 2, partial: true),
      );
      // Tab đang chọn bị gom → thay tab cuối trên thanh.
      expect(ClassificationTabs.shownTabs([1, 2, 3, 4], 2, (t) => t == 4), [
        1,
        4,
      ]);
      expect(ClassificationTabs.shownTabs([1, 2, 3], 0, (t) => t == 3), [3]);
    });
  });

  group('card widgets', () {
    testWidgets(
      'grid card: badge classification "+N", không nhãn Consultation, ẩn "0 saved"',
      (tester) async {
        final repo = _Repo()..saves[2] = 3;
        final cubit = _engagement(repo);
        await cubit.load([1, 2]);
        final consult = MarketMapper.service({
          'id': 1,
          'title': 'Consult',
          'pricing_mode': 'consultation',
          'price': 50,
          'price_max': 200,
          'service_classifications': [
            {'name': 'Nutrition'},
            {'name': 'Weight loss'},
            {'name': 'Diabetes'},
          ],
        });
        await _pump(
          tester,
          Column(
            children: [
              MarketServiceGridCard(service: consult),
              MarketServiceGridCard(
                service: MarketMapper.service({'id': 2, 'title': 'Saved'}),
              ),
            ],
          ),
          cubit,
        );
        await tester.pump();
        expect(find.text('Nutrition'), findsOneWidget);
        expect(find.text('Weight loss'), findsOneWidget);
        expect(find.text('Diabetes'), findsNothing);
        expect(find.text('+1'), findsOneWidget);
        expect(find.text(r'$50 – $200'), findsOneWidget);
        expect(find.text('Consultation'), findsNothing);
        // Service 1 chưa ai lưu → không có dòng "saved"; service 2 có.
        expect(find.text('marketSaved'), findsOneWidget);
        // Không có ảnh → ảnh dự phòng chung.
        expect(find.byType(MarketImageFallback), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('thanh tab classification không tràn ở 375px', (tester) async {
      final cubit = _engagement(_Repo());
      String? picked = 'none';
      await _pump(
        tester,
        ClassificationTabs(
          title: 'Yoga',
          active: 't9',
          tabs: [
            for (var i = 0; i < 10; i++)
              MarketClassificationFacet(
                slug: 't$i',
                name: 'Classification $i',
                count: 1,
              ),
          ],
          onSelect: (s) => picked = s,
        ),
        cubit,
      );
      expect(find.text('marketListingMoreClassifications'), findsOneWidget);
      // Tab đang chọn luôn nằm trên thanh.
      expect(find.text('Classification 9'), findsOneWidget);
      await tester.tap(find.text('marketListingAllClassifications'));
      expect(picked, isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
