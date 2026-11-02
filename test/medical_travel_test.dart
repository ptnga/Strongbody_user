import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/modules/chat/domain/usecases/chat_use_cases.dart';
import 'package:strongbody_buyer/modules/social_market/data/datasources/remote/social_market_remote_datasource.dart';
import 'package:strongbody_buyer/modules/social_market/data/mappers/market_mapper.dart';
import 'package:strongbody_buyer/modules/social_market/data/repositories/social_market_repository_impl.dart';
import 'package:strongbody_buyer/modules/social_market/data/services/market_chat_publisher.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_listing_entities.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/medical_travel_entities.dart';
import 'package:strongbody_buyer/modules/social_market/domain/repositories/social_market_repository.dart';
import 'package:strongbody_buyer/modules/social_market/domain/usecases/social_market_use_cases.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/category_market/category_market_bloc.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/medical_travel/medical_travel_cubit.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_rich_text.dart';

/// Datasource giả: expert/featured trả theo (sort, page).
class _Remote implements SocialMarketRemoteDataSource {
  final featuredCalls = <Map<String, dynamic>>[];

  @override
  Future<RawListPage> getFeaturedExperts(Map<String, dynamic> query) async {
    featuredCalls.add(query);
    final category = query['sort'] == 'score';
    final page = query['page'] as int;
    // Category: 2 trang, trang 2 rỗng (hết giữa chừng) → chuyển sang random.
    if (category) {
      return RawListPage(
        items: page == 1
            ? [
                {'id': 1, 'shop_name': 'Clinic A'},
              ]
            : const [],
        total: 1,
        totalPages: 2,
      );
    }
    return RawListPage(
      items: [
        {'id': 10 + page, 'shop_name': 'Random $page'},
      ],
      total: 1,
      totalPages: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements GlobalStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OpenChat implements OpenChatSessionUseCase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements SocialMarketRepository {
  final serviceQueries = <Map<String, dynamic>>[];

  @override
  Future<Either<Failure, MarketPage<MarketServiceEntity>>> getMedicalServices(
    MedicalServiceFilters filters, {
    required int page,
    required int limit,
  }) async {
    serviceQueries.add(filters.toQuery(page: page, limit: limit));
    return Right(
      MarketPage(
        items: [
          MarketMapper.medicalService({
            'id': page,
            'title': 'S$page',
            'is_medical_travel': true,
          }),
        ],
        total: 25,
        totalPages: 3,
      ),
    );
  }

  @override
  Future<
    Either<Failure, ({List<MarketExpertEntity> items, CoordinatorsCursor next})>
  >
  getCoordinators(CoordinatorsPhase cursor) async =>
      const Right((items: <MarketExpertEntity>[], next: CoordinatorsDone()));

  @override
  Future<Either<Failure, List<MarketDestination>>> getDestinations() async =>
      const Right([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'coordinator: organization đại diện → tên org, không lặp "Representative of"',
    () {
      final c = MarketMapper.coordinator({
        'id': 5,
        'user_id': 50,
        'shop_name': 'Dr Rong',
        'is_org_owner': true,
        'seller_verified': true,
        'organization': {
          'id': 2,
          'name': 'Hanoi VitalCare Clinic',
          'description': '<p>Leading <b>clinic</b></p>',
        },
        'review_summary': {'rating': 4.5, 'review_count': 0},
      });
      expect(c.name, 'Hanoi VitalCare Clinic');
      expect(c.representativeOf, isNull);
      expect(c.independent, isFalse);
      expect(c.verified, isTrue);
      expect(c.about, 'Leading clinic');
      // Chưa có review thật → không hiện sao.
      expect(c.hasRating, isFalse);

      final staff = MarketMapper.coordinator({
        'id': 6,
        'shop_name': 'Anna',
        'organization': {'id': 3, 'name': 'Bumrungrad'},
      });
      expect(staff.representativeOf, 'Bumrungrad');
      final independent = MarketMapper.coordinator({
        'id': 7,
        'shop_name': 'Ben',
      });
      expect(independent.independent, isTrue);
    },
  );

  test(
    'medicalService: tên cơ sở trước tên shop, nơi = nước của organization',
    () {
      final s = MarketMapper.medicalService({
        'id': 1,
        'title': 'Imaging',
        'is_medical_travel': true,
        'user': {
          'id': 9,
          'seller_profile': {'shop_name': 'Sergio'},
        },
        'organization': {
          'name': 'BlueNet Hospitals',
          'country': {'title': 'Mexico'},
        },
      });
      expect(s.seller.shopName, 'BlueNet Hospitals');
      expect(s.place, 'Mexico');
      expect(s.seller.id, 9);
      expect(s.isMedicalTravel, isTrue);
    },
  );

  test('serviceDetail: cover trước gallery, chứng nhận, ngôn ngữ, FAQ', () {
    final d = MarketMapper.serviceDetail({
      'id': 18632,
      'user_id': 100071,
      'title': 'Radiology',
      'image': ['a', 'b'],
      'cover_image': ['b', 'c'],
      'duration': 3,
      'duration_unit': 'day',
      'supported_languages': ['es'],
      'is_medical_travel': true,
      'organization': {
        'id': 28,
        'name': 'BlueNet Hospitals',
        'country': {'title': 'Mexico', 'code': 'MX'},
        'accreditations': {'jci_accredited': true, 'iso_9001': false},
      },
      'seller_profile': {'shop_name': 'Sergio', 'slug': 'sergio'},
      'faqs': [
        {
          'question': '<p>Visa?</p>',
          'answers': [
            {'answer': 'Yes'},
          ],
        },
        {'question': 'Empty', 'answer': ''},
      ],
    })!;
    expect(d.images, ['b', 'c', 'a']);
    expect(d.organizationName, 'BlueNet Hospitals');
    expect(d.providerName, 'Sergio');
    expect(d.locationTitle, 'Mexico');
    expect(d.locationFlag, 'https://flagcdn.com/w40/mx.png');
    expect(d.certs, [MarketCert.jciAccredited]);
    expect(d.languages.single.label, 'Spanish');
    expect(d.faqs.single.question, 'Visa?');
  });

  test('phoneCodes: mỗi mã một lựa chọn, kèm cờ, giữ thứ tự', () {
    final codes = MarketMapper.phoneCodes([
      {'code': 'US', 'phone_code': '+1'},
      {'code': 'CA', 'phone_code': '1'},
      {'code': 'VN', 'phone_code': '0084'},
      {'code': 'XX', 'phone_code': ''},
    ]);
    expect(codes.map((c) => c.code), ['+1', '+84']);
    expect(codes.last.label, '🇻🇳 +84');
  });

  test('AppointmentRequest.toJson: bỏ field trống như web payload', () {
    final json = const AppointmentRequest(
      serviceId: 1,
      timeframe: 'specific_date',
      preferredFrom: '2026-11-20',
      firstName: 'An',
      email: 'an@example.com',
      contactPreference: 'email',
    ).toJson();
    expect(json, {
      'service_id': 1,
      'timeframe_type': 'specific_date',
      'first_name': 'An',
      'email': 'an@example.com',
      'contact_preference': 'email',
      'notes': '',
      'preferred_from': '2026-11-20',
    });
  });

  test(
    'MedicalServiceFilters → query /public/services (web buildServicesParams)',
    () {
      final q = const MedicalServiceFilters(
        sort: 'price',
        priceDesc: true,
        minPrice: 500,
        certs: {MarketCert.jciAccredited},
        countryId: 144,
        keyword: ' knee ',
      ).toQuery(page: 2, limit: 8);
      expect(q, {
        'limit': 8,
        'page': 2,
        'is_medical_travel': true,
        'supported_country_id': 144,
        'keyword': 'knee',
        'order_by': 'price',
        'order_dir': 'DESC',
        'min_price': 500.0,
        'jci_accredited': true,
      });
    },
  );

  test(
    'coordinators: hết seller category giữa chừng → nối seller ngẫu nhiên',
    () async {
      final remote = _Remote();
      final repo = SocialMarketRepositoryImpl(
        remote,
        _Storage(),
        _OpenChat(),
        MarketChatPublisher(),
      );
      final first = (await repo.getCoordinators(
        const CoordinatorsPhase(category: true, page: 1, seed: 'abc'),
      )).toNullable()!;
      expect(first.items.single.name, 'Clinic A');
      // Trang category 2 rỗng → cùng lượt chuyển sang random trang 1.
      final second = (await repo.getCoordinators(
        first.next as CoordinatorsPhase,
      )).toNullable()!;
      expect(second.items.single.name, 'Random 1');
      expect(second.next, isA<CoordinatorsDone>());
      expect(remote.featuredCalls.last, {
        'limit': 12,
        'page': 1,
        'sort': 'random',
        'exclude_category_slug': 'medical-travel-2',
        'seed': 'abc',
        'org_owner': true,
        'is_medical_travel': false,
      });
    },
  );

  test(
    'MedicalTravelCubit: đổi lọc tải lại trang 1, "View more" nối trang kế',
    () async {
      final repo = _Repo();
      final cubit = MedicalTravelCubit(
        getCoordinators: GetCoordinatorsUseCase(repo),
        getDestinations: GetDestinationsUseCase(repo),
        getServices: GetMedicalServicesUseCase(repo),
      );
      await cubit.load();
      expect(cubit.state.packagesStatus, SectionStatus.success);
      await cubit.viewMorePackages();
      expect(cubit.state.packages.map((s) => s.id), [1, 2]);
      await cubit.changeFilters(
        cubit.state.filters.copyWith(sort: 'top_rated'),
      );
      expect(cubit.state.packages.map((s) => s.id), [1]);
      expect(repo.serviceQueries.last['order_by'], 'rating');
      await cubit.close();
    },
  );

  test('MarketRichText.lines: danh sách HTML → gạch đầu dòng', () {
    expect(
      MarketRichText.lines(
        '<ul class="x"><li value="1"><span>Lab &amp; imaging</span></li>'
        '<li>Hotel</li></ul><p>Note</p>',
      ),
      ['•Lab & imaging', '•Hotel', 'Note'],
    );
  });
}
