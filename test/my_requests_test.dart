import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/modules/post_request/data/mappers/post_request_mapper.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/my_request_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_form_values.dart';
import 'package:strongbody_buyer/modules/post_request/domain/repositories/post_request_repository.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/get_my_requests_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/get_request_offers_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/my_requests/my_requests_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/request_offers/request_offers_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/widgets/my_requests/my_request_formatters.dart';

class _Storage implements GlobalStorage {
  @override
  bool get isLoggedIn => true;
  @override
  int? get userId => 7;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements PostRequestRepository {
  final offerCalls = <int>[];

  @override
  Future<Either<Failure, MyRequestPage>> getMyRequests({
    required int userId,
    int page = 1,
    int limit = 20,
  }) async => Right(
    PostRequestMapper.myRequests({
      'total_page': 1,
      'list': [
        {
          'id': 1,
          'description': 'Physio. Back pain',
          'status': 'active',
          'offers_count': 2,
        },
        {
          'id': 2,
          'description': 'Nutrition plan',
          'status': 'pending',
          'offers_count': 0,
        },
        {'id': 3, 'description': 'Yoga', 'status': 'closed', 'offers_count': 1},
      ],
    }),
  );

  @override
  Future<Either<Failure, List<RequestOfferEntity>>> getRequestOffers(
    int requestId,
  ) async {
    offerCalls.add(requestId);
    return Right([
      RequestOfferEntity(
        id: requestId * 10,
        status: 'pending',
        sellerName: 'Mai Pham',
        price: 55,
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => initializeDateFormatting());

  group('PostRequestMapper.myRequests', () {
    test('reads budget, delivery, schedule like web requestToFormValues', () {
      final page = PostRequestMapper.myRequests({
        'total_page': 2,
        'list': [
          {
            'id': 9,
            'description': 'Physiotherapy for lower back pain. At home please.',
            'status': 'active',
            'offers_count': 3,
            'responders_count': 12,
            'min_budget': 60,
            'max_budget': 80,
            'currency': 'USD',
            'delivery_type': 'all',
            'deadline': '2026-10-24T02:00:00Z',
            'schedule':
                '{"sat":[{"from":"09:00","to":"17:00"}],"sun":[{"from":"09:00","to":"17:00"}],"xx":1}',
            'voice_url': 'https://cdn/x.m4a',
          },
          {'description': 'no id → skipped'},
        ],
      });
      expect(page.totalPage, 2);
      expect(page.items, hasLength(1));
      final r = page.items.single;
      expect(r.respondersCount, 12);
      expect(r.hasVoice, isTrue);
      expect(r.isClosed, isFalse);
      expect(r.details.budget, '60-80');
      expect(r.details.deliveryTypes, RequestDeliveryType.values);
      expect(r.details.schedule.keys, [WeekDay.sat, WeekDay.sun]);
      // deadline Sat 24 → endDate Sun 25 nhờ lịch liên tiếp.
      expect(r.details.endDate?.day, 25);
    });

    test('maps offers: seller name, price, service rating', () {
      final offers = PostRequestMapper.requestOffers({
        'list': [
          {
            'id': 5,
            'status': 'completed',
            'price': '80',
            'payment_date': '2026-10-12T08:00:00Z',
            'Seller': {
              'first_name': 'Hana',
              'last_name': 'Le',
              'profile_picture': '',
            },
            'Service': {'rating': 4.9},
          },
          {'status': 'pending'},
        ],
      });
      expect(offers, hasLength(1));
      final o = offers.single;
      expect(o.sellerName, 'Hana Le');
      expect(o.sellerAvatar, isNull);
      expect(o.price, 80);
      expect(o.rating, 4.9);
      expect(o.isBooked, isTrue);
      expect(o.paidAt?.day, 12);
    });
  });

  group('MyRequestFormatters', () {
    final now = DateTime(2026, 10, 21, 10); // thứ 4

    test('when: today / tomorrow / this weekend / range', () {
      String? when(DateTime start, [DateTime? end]) => MyRequestFormatters.when(
        RequestFormValues(description: '', deadline: start, endDate: end),
        'en',
        now: now,
      );
      expect(when(DateTime(2026, 10, 21, 9)), 'myRequestsWhenToday');
      expect(when(DateTime(2026, 10, 22, 9)), 'myRequestsWhenTomorrow');
      expect(
        when(DateTime(2026, 10, 24, 9), DateTime(2026, 10, 25)),
        'myRequestsWhenWeekend',
      );
      expect(when(DateTime(2026, 10, 30, 9)), 'Fri 30 Oct');
    });

    test('budget: range and "under"', () {
      expect(
        MyRequestFormatters.budget(
          const RequestFormValues(description: '', budget: '60-80'),
        ),
        r'$60–80',
      );
      expect(
        MyRequestFormatters.budget(
          const RequestFormValues(description: '', budget: '0-100'),
        ),
        'myRequestsBudgetUnder',
      );
    });

    test('initials', () {
      expect(MyRequestFormatters.initials('Mai Pham'), 'MP');
      expect(MyRequestFormatters.initials('gwen'), 'GW');
      expect(MyRequestFormatters.initials(' '), '?');
    });
  });

  test(
    'MyRequestsBloc splits tabs and loads offers only when offers_count > 0',
    () async {
      final repo = _Repo();
      final bloc = MyRequestsBloc(
        getMyRequests: GetMyRequestsUseCase(repo),
        getRequestOffers: GetRequestOffersUseCase(repo),
        storage: _Storage(),
      )..add(const MyRequestsStarted());

      final loaded = await bloc.stream.firstWhere((s) => s.offers.length == 2);
      expect(loaded.visibleItems.map((r) => r.id), [1, 2]);
      expect(repo.offerCalls..sort(), [1, 3]);

      bloc.add(const MyRequestsTabChanged(MyRequestsTab.closed));
      final closed = await bloc.stream.firstWhere(
        (s) => s.tab == MyRequestsTab.closed,
      );
      expect(closed.visibleItems.map((r) => r.id), [3]);
      await bloc.close();
    },
  );

  test('offer mapper reads message, voice file, service info', () {
    final o = PostRequestMapper.requestOffers({
      'list': [
        {
          'id': 1,
          'status': 'pending',
          'title': 'Home physio',
          'description': 'I can come Saturday morning.',
          'price': 70,
          'request_id': 5,
          'Request': {'id': 5, 'description': 'Back pain', 'status': 'active'},
          'Seller': {
            'first_name': 'Minh',
            'last_name': 'Pham',
            'seller_verified': true,
          },
          'Service': {
            'rating': 4.9,
            'review_count': 128,
            'address': ' District 3 ',
            'delivery_lead_time_day': 2,
            'SubCategory': {'name': 'Physiotherapist'},
          },
          'files': [
            {'url': 'https://cdn/doc.pdf', 'type': 'application/pdf'},
            {'url': 'https://cdn/hi.m4a', 'type': ''},
          ],
        },
      ],
    }).single;
    expect(o.description, 'I can come Saturday morning.');
    expect(o.sellerVerified, isTrue);
    expect(o.reviewCount, 128);
    expect(o.profession, 'Physiotherapist');
    expect(o.address, 'District 3');
    expect(o.leadTimeDays, 2);
    expect(o.voiceUrl, 'https://cdn/hi.m4a');
    expect(o.requestId, 5);
    expect(o.request!.description, 'Back pain');
    expect(RequestOffersState(offers: [o]).request!.id, 5);
  });

  test('offers sort: best match, lowest price, soonest; cancelled last', () {
    const offers = [
      RequestOfferEntity(
        id: 1,
        status: 'pending',
        sellerName: 'A',
        price: 80,
        rating: 4.8,
        leadTimeDays: 1,
      ),
      RequestOfferEntity(
        id: 2,
        status: 'pending',
        sellerName: 'B',
        price: 55,
        rating: 4.7,
        leadTimeDays: 3,
      ),
      RequestOfferEntity(
        id: 3,
        status: 'pending',
        sellerName: 'C',
        price: 70,
        rating: 4.9,
        leadTimeDays: 2,
      ),
      RequestOfferEntity(
        id: 4,
        status: 'cancelled',
        sellerName: 'D',
        price: 10,
        rating: 5,
      ),
    ];
    List<int> ids(OfferSort sort) => RequestOffersState(
      offers: offers,
      sort: sort,
    ).sortedOffers.map((o) => o.id).toList();
    expect(ids(OfferSort.bestMatch), [3, 1, 2, 4]);
    expect(ids(OfferSort.lowestPrice), [2, 3, 1, 4]);
    expect(ids(OfferSort.soonest), [1, 3, 2, 4]);
  });
}
