import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';
import 'package:strongbody_buyer/modules/home/data/datasources/remote/home_remote_datasource.dart';
import 'package:strongbody_buyer/modules/post_request/data/datasources/remote/post_request_remote_datasource.dart';
import 'package:strongbody_buyer/modules/post_request/data/mappers/post_request_mapper.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/my_request_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_form_values.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/widgets/my_requests/my_request_formatters.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/widgets/providers/provider_formatters.dart';

/// ApiClient giả: ghi lại path + query, trả body dựng sẵn.
class _FakeApi implements ApiClient {
  final dynamic body;
  final calls = <({String path, Map<String, dynamic>? query})>[];

  _FakeApi([this.body = const {'code': 0, 'data': <String, dynamic>{}}]);

  @override
  Future<dynamic> request({
    required String path,
    required ApiType method,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    Duration? timeout,
    bool skipAuth = false,
    ResponseType? responseType,
  }) async {
    calls.add((path: path, query: queryParameters));
    return body;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MyRequestEntity _request(String status) => MyRequestEntity(
  id: 1,
  status: status,
  details: const RequestFormValues(description: 'x'),
);

void main() {
  group('Query params match web', () {
    test('GET /user/requests: user_id, page, is_private (no sort)', () async {
      final api = _FakeApi();
      final remote = PostRequestRemoteDataSourceImpl(api);
      await remote.getMyRequests(
        userId: 7,
        page: 2,
        limit: 20,
        isPrivate: true,
      );
      await remote.getMyRequests(userId: 7, page: 1, limit: 3);
      expect(api.calls.first.path, '/user/requests');
      expect(api.calls.first.query, {
        'user_id': 7,
        'page': 2,
        'limit': 20,
        'is_private': true,
      });
      // Menu "recent requests": không lọc theo tab.
      expect(api.calls.last.query!.containsKey('is_private'), isFalse);
    });

    test(
      'offers by request: web BuyerListOffer query, no include_pending',
      () async {
        final api = _FakeApi();
        await PostRequestRemoteDataSourceImpl(api).getRequestOffers(42);
        final q = api.calls.single.query!;
        expect(
          api.calls.single.path,
          '/buyer/offer/sent-offers-by-my-requests',
        );
        expect(q['request_id'], 42);
        expect(q['source'], 'request,chat');
        expect(q['order_by'], 'created_at');
        expect(q['order_dir'], 'desc');
        expect(q.containsKey('include_pending'), isFalse);
      },
    );

    test('new offers badge = web Received offers › Pending total', () async {
      final api = _FakeApi({
        'code': 0,
        'data': {'list': [], 'total': 4, 'total_page': 4},
      });
      final count = await HomeRemoteDataSourceImpl(api).getNewOffersCount();
      expect(count, 4);
      final q = api.calls.single.query!;
      expect(q['status'], 'pending');
      expect(q['source'], 'request,chat');
      expect(q['limit'], 1);
    });
  });

  group('My requests mapping (web ManageRequest)', () {
    test('reads is_private / is_privated and inquiry recipient', () {
      final page = PostRequestMapper.myRequests({
        'list': [
          {
            'id': 1,
            'description': 'a',
            'status': 'active',
            'is_private': false,
          },
          {
            'id': 2,
            'description': 'b',
            'status': 'active',
            'is_privated': 'true',
          },
          {
            'id': 3,
            'description': 'c',
            'status': 'pending',
            'inquiry': {
              'target_type': 'service',
              'target_id': 9,
              'title': ' Back massage ',
              'recipient_id': 55,
              'recipient_name': 'Revival',
              'recipient_avatar': '',
            },
          },
        ],
      });
      final [a, b, c] = page.items;
      expect(a.isPrivate, isFalse);
      expect(b.isPrivate, isTrue);
      expect(c.isPrivate, isTrue);
      expect(c.inquiry!.recipientId, 55);
      expect(c.inquiry!.recipientName, 'Revival');
      expect(c.inquiry!.recipientAvatar, isNull);
      expect(c.inquiry!.title, 'Back massage');
    });

    test('status labels follow web getStatusLabel', () {
      expect(
        MyRequestFormatters.status(_request('pending')),
        'myRequestsStatusPending',
      );
      expect(
        MyRequestFormatters.status(_request('pending_approval')),
        'myRequestsStatusPending',
      );
      expect(
        MyRequestFormatters.status(_request('active')),
        'myRequestsStatusOpen',
      );
      expect(
        MyRequestFormatters.status(_request('closed')),
        'myRequestsStatusClosed',
      );
      for (final s in ['cancelled', 'rejected', 'spam']) {
        expect(
          MyRequestFormatters.status(_request(s)),
          'myRequestsStatusRejected',
          reason: s,
        );
        expect(_request(s).isClosed, isTrue, reason: s);
      }
      expect(MyRequestFormatters.status(_request('draft')), 'Draft');
      expect(_request('pending_approval').isClosed, isFalse);
    });
  });

  group('Offer mapping (web OfferItem / OfferDetail)', () {
    Map<String, dynamic> offer(Map<String, dynamic> seller, [String? status]) =>
        {
          'id': 1,
          'status': status ?? 'pending',
          'price': 70,
          'Seller': seller,
          'Service': {'rating': 4.2},
        };

    test('seller name: organization → shop name, never the account name', () {
      final [org, shop, none] = PostRequestMapper.requestOffers({
        'list': [
          offer({
            'first_name': 'Minh',
            'seller_profile': {
              'shop_name': 'Minh Physio',
              'is_org_owner': true,
              'organization': {'id': 3, 'name': 'Saigon Clinic'},
            },
          }),
          offer({
            'first_name': 'Minh',
            'seller_profile': {'shop_name': ' Minh Physio '},
          }),
          offer({'first_name': 'Minh', 'last_name': 'Pham'}),
        ],
      });
      expect(org.sellerName, 'Saigon Clinic');
      expect(shop.sellerName, 'Minh Physio');
      expect(none.sellerName, isEmpty);
      expect(MyRequestFormatters.sellerName(none), 'offersUnknownSeller');
    });

    test(
      'price is charged in USD; rating from Seller.rating; avatar cleaned',
      () {
        final [a, b] = PostRequestMapper.requestOffers({
          'list': [
            offer({
              'currency': 'VND',
              'rating': 4.8,
              'profile_picture': '{"https://cdn/a.png"}',
            }),
            offer({'profile_picture': '{}'}),
          ],
        });
        expect(a.currency, 'USD');
        expect(a.rating, 4.8);
        expect(a.sellerAvatar, 'https://cdn/a.png');
        expect(b.rating, 4.2); // không có Seller.rating → Service.rating
        expect(b.sellerAvatar, isNull);
      },
    );

    test('Accept & Pay only for pending offers', () {
      final offers = PostRequestMapper.requestOffers({
        'list': [
          for (final s in ['pending', 'accepted', 'delivered', 'declined'])
            offer({}, s),
        ],
      });
      expect(offers.map((o) => o.canPay), [true, false, false, false]);
    });
  });

  group('Providers mapping (web expertToCard)', () {
    test('name/avatar/country from seller profile, not the user account', () {
      final page = PostRequestMapper.providers({
        'list': [
          {
            'id': 1,
            'user_id': 11,
            'shop_name': 'undefined',
            'is_org_owner': true,
            'organization': {
              'id': 5,
              'name': 'Saigon Clinic',
              'logo': 'https://cdn/logo.png',
              'country': {'title': 'Vietnam'},
              'languages': ['vi'],
            },
            'profession': '76',
            'category': [
              {'id': 2, 'name': 'Massage'},
              {'id': 3, 'name': 'Physio'},
            ],
            'primary_category_id': 3,
            'supported_languages': ['en'],
            'user': {
              'first_name': 'Minh',
              'profile_picture': '',
              'country': {'title': 'France'},
            },
          },
          {
            'id': 2,
            'user_id': 12,
            'review_summary': {'rating': 4.5, 'review_count': 3},
            'rating': 1,
            'addresses': [
              {'country': 'Thailand'},
            ],
            'user': {
              'first_name': 'Anh',
              'last_name': 'Le',
              'country': {'title': 'France'},
            },
          },
        ],
      });
      final [org, plain] = page.items;
      expect(org.name, 'Saigon Clinic');
      expect(org.avatarUrl, 'https://cdn/logo.png');
      expect(org.country, 'Vietnam');
      expect(org.profession, 'Physio');
      expect(org.languages, ['vi']);
      expect(plain.name, isEmpty);
      expect(ProviderFormatters.name(plain), 'providersFallbackName');
      expect(plain.country, 'Thailand');
      expect(plain.rating, 4.5);
    });
  });

  test(
    'send-to-provider form omits languages + anonymous (web variant="send")',
    () async {
      final form = await PostRequestMapper.createRequestFormData(
        userId: 7,
        values: const RequestFormValues(
          description: 'Yoga',
          sellerLanguages: ['vi'],
        ),
        sellerUserId: 501,
      );
      final fields = Map.fromEntries(form.fields);
      expect(fields['seller_id'], '501');
      expect(fields.containsKey('seller_languages'), isFalse);
      expect(fields.containsKey('anonymous'), isFalse);
    },
  );
}
