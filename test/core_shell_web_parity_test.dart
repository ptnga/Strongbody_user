import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';
import 'package:strongbody_buyer/core/services/last_visit_service.dart';
import 'package:strongbody_buyer/core/streams/auth_event_bus.dart';
import 'package:strongbody_buyer/core/utils/app_locale.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_badge_notifier.dart';
import 'package:strongbody_buyer/modules/home/presentation/bloc/home_menu/home_menu_cubit.dart';
import 'package:strongbody_buyer/modules/home/presentation/new_offers_badge_notifier.dart';
import 'package:strongbody_buyer/modules/home/presentation/widgets/home_menu_drawer.dart';

const _base = 'https://api.test/v1';

/// JWT không ký (chỉ cần payload `exp`).
String _jwt(DateTime exp) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.'
      '${part({'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

class _Storage implements GlobalStorage {
  _Storage({this.accessToken, this.refreshToken});

  @override
  String? accessToken;
  @override
  String? refreshToken;
  int cleared = 0;

  @override
  bool get isLoggedIn => accessToken != null;
  @override
  String get locale => 'vi';
  @override
  int? get userId => isLoggedIn ? 7 : null;
  @override
  String? get userName => null;
  @override
  String? get userEmail => null;
  @override
  String? get referralCode => null;
  @override
  Map<String, dynamic>? get pendingRequest => null;
  @override
  Future<void> init() async {}
  @override
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {}
  @override
  Future<void> saveUser({required int id, String? name, String? email}) async {}
  @override
  Future<void> saveAccessToken(
    String accessToken, {
    String? refreshToken,
  }) async {
    this.accessToken = accessToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      this.refreshToken = refreshToken;
    }
  }

  @override
  Future<void> saveLocale(String locale) async {}
  @override
  Future<void> savePendingRequest(Map<String, dynamic> json) async {}
  @override
  Future<void> clearPendingRequest() async {}
  @override
  Future<void> clearUser() async {
    cleared++;
    accessToken = null;
    refreshToken = null;
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

({ApiClient client, _Adapter api, _Adapter refresh}) _client(
  _Storage storage, {
  required FutureOr<ResponseBody> Function(RequestOptions) api,
  FutureOr<ResponseBody> Function(RequestOptions)? refresh,
}) {
  final apiAdapter = _Adapter(api);
  final refreshAdapter = _Adapter(
    refresh ?? (_) => _json(500, {'message': 'unexpected'}),
  );
  final client = ApiClient(
    Dio()..httpClientAdapter = apiAdapter,
    storage,
    refreshDio: Dio()..httpClientAdapter = refreshAdapter,
  );
  return (client: client, api: apiAdapter, refresh: refreshAdapter);
}

class _Badge extends ValueNotifier<int>
    implements NewOffersBadgeNotifier, ChatBadgeNotifier {
  _Badge() : super(0);

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MenuCubit extends Cubit<HomeMenuState> implements HomeMenuCubit {
  _MenuCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=$_base');
    final badge = _Badge();
    GetIt.I
      ..registerSingleton<NewOffersBadgeNotifier>(badge)
      ..registerSingleton<ChatBadgeNotifier>(badge);
  });

  group('JWT expiry (web next-auth parseTokenExpiry)', () {
    final now = DateTime(2026, 11, 10, 12);

    test('reads exp and treats past / near-expiry tokens as expired', () {
      final exp = DateTime(2026, 11, 10, 13);
      expect(
        ApiClient.tokenExpiry(_jwt(exp))!.millisecondsSinceEpoch,
        exp.millisecondsSinceEpoch,
      );
      expect(ApiClient.isTokenExpired(_jwt(exp), now), isFalse);
      expect(
        ApiClient.isTokenExpired(
          _jwt(now.subtract(const Duration(minutes: 1))),
          now,
        ),
        isTrue,
      );
      // Trong khoảng skew → refresh luôn.
      expect(
        ApiClient.isTokenExpired(
          _jwt(now.add(const Duration(seconds: 5))),
          now,
        ),
        isTrue,
      );
    });

    test('opaque tokens are never refreshed proactively', () {
      expect(ApiClient.tokenExpiry('opaque-token'), isNull);
      expect(ApiClient.isTokenExpired('opaque-token', now), isFalse);
      expect(ApiClient.isTokenExpired('a.%%%.c', now), isFalse);
    });
  });

  group('refresh response (web refreshAccessToken: code === 0)', () {
    test('accepts code 0 with data.accessToken or top-level accessToken', () {
      expect(
        ApiClient.parseRefreshResponse({
          'code': 0,
          'data': {'accessToken': 'new', 'refreshToken': 'r2'},
        }),
        (accessToken: 'new', refreshToken: 'r2'),
      );
      expect(
        ApiClient.parseRefreshResponse({'code': 0, 'accessToken': 'top'}),
        (accessToken: 'top', refreshToken: null),
      );
    });

    test('rejects non-zero / missing code or missing token', () {
      expect(
        ApiClient.parseRefreshResponse({
          'code': 401,
          'data': {'accessToken': 'x'},
        }),
        isNull,
      );
      expect(
        ApiClient.parseRefreshResponse({
          'data': {'accessToken': 'x'},
        }),
        isNull,
      );
      expect(ApiClient.parseRefreshResponse({'code': 0, 'data': {}}), isNull);
      expect(ApiClient.parseRefreshResponse('oops'), isNull);
    });
  });

  group('ApiClient headers + session (web apiFetch / RefreshTokenGuard)', () {
    test('sends Bearer, Scope, locale and Accept-Language', () async {
      final storage = _Storage(accessToken: 'opaque', refreshToken: 'r');
      final c = _client(storage, api: (_) => _json(200, {'code': 0}));
      await c.client.request(path: '/x', method: ApiType.get);
      final headers = c.api.requests.single.headers;
      expect(headers['Authorization'], 'Bearer opaque');
      expect(headers['Scope'], 'strongbody-ai');
      expect(headers['locale'], 'vi');
      expect(headers['Accept-Language'], 'vi');
    });

    test('caller headers win; skipAuth sends no token', () async {
      final storage = _Storage(accessToken: 'opaque');
      final c = _client(storage, api: (_) => _json(200, {'code': 0}));
      await c.client.request(
        path: '/public/x',
        method: ApiType.get,
        skipAuth: true,
        headers: {'Accept-Language': 'de'},
      );
      final headers = c.api.requests.single.headers;
      expect(headers['Authorization'], isNull);
      expect(headers['Accept-Language'], 'de');
      expect(headers['locale'], 'vi');
    });

    test(
      'expired JWT is refreshed once before sending (concurrent requests)',
      () async {
        final expired = _jwt(DateTime.now().subtract(const Duration(hours: 1)));
        final storage = _Storage(accessToken: expired, refreshToken: 'r1');
        final c = _client(
          storage,
          api: (_) => _json(200, {'code': 0}),
          refresh: (o) async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return _json(200, {
              'code': 0,
              'data': {'accessToken': 'fresh'},
            });
          },
        );
        await Future.wait([
          c.client.request(path: '/a', method: ApiType.get),
          c.client.request(path: '/b', method: ApiType.get),
        ]);
        expect(c.refresh.requests, hasLength(1));
        expect(c.refresh.requests.single.headers['Authorization'], 'Bearer r1');
        expect(c.refresh.requests.single.path, '$_base/auth/refresh-token');
        expect(
          c.api.requests.map((r) => r.headers['Authorization']),
          everyElement('Bearer fresh'),
        );
        expect(storage.accessToken, 'fresh');
        expect(storage.refreshToken, 'r1');
      },
    );

    test(
      '401 → refresh rejected (code != 0) → signs out with expired',
      () async {
        final storage = _Storage(accessToken: 'opaque', refreshToken: 'r1');
        final events = <AuthEvent>[];
        final sub = AuthEventBus.stream.listen(events.add);
        final c = _client(
          storage,
          api: (_) => _json(401, {'message': 'Unauthorized'}),
          refresh: (_) => _json(200, {'code': 401, 'message': 'expired'}),
        );
        await expectLater(
          c.client.request(path: '/x', method: ApiType.get),
          throwsA(isA<DioException>()),
        );
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        expect(storage.cleared, 1);
        expect(events.whereType<UserLoggedOut>().single.expired, isTrue);
      },
    );

    test('401 → refresh OK → request retried with new token', () async {
      final storage = _Storage(accessToken: 'old', refreshToken: 'r1');
      final c = _client(
        storage,
        api: (o) => o.headers['Authorization'] == 'Bearer new'
            ? _json(200, {'code': 0, 'data': 'ok'})
            : _json(200, {'code': 401}),
        refresh: (_) => _json(200, {
          'code': 0,
          'data': {'accessToken': 'new', 'refreshToken': 'r2'},
        }),
      );
      final body = await c.client.request(path: '/x', method: ApiType.get);
      expect(body, {'code': 0, 'data': 'ok'});
      expect(c.api.requests, hasLength(2));
      expect(storage.refreshToken, 'r2');
    });

    test('refresh 5xx keeps the session (mobile: flaky network)', () async {
      final storage = _Storage(accessToken: 'opaque', refreshToken: 'r1');
      final c = _client(
        storage,
        api: (_) => _json(401, {'message': 'Unauthorized'}),
        refresh: (_) => _json(503, {'message': 'down'}),
      );
      await expectLater(
        c.client.request(path: '/x', method: ApiType.get),
        throwsA(isA<DioException>()),
      );
      expect(storage.cleared, 0);
      expect(storage.accessToken, 'opaque');
    });

    test('rejection while logging out is not reported as expiry', () async {
      final storage = _Storage(accessToken: 'opaque', refreshToken: 'r1');
      final events = <AuthEvent>[];
      final sub = AuthEventBus.stream.listen(events.add);
      final c = _client(
        storage,
        api: (_) => _json(401, {}),
        refresh: (_) => _json(401, {'message': 'revoked'}),
      );
      await expectLater(
        c.client.request(path: '/public/auth/logout', method: ApiType.post),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(events.whereType<UserLoggedOut>().single.expired, isFalse);
    });
  });

  group('AppLocale (web proxy: saved → Accept-Language → en)', () {
    test('saved locale wins', () {
      expect(AppLocale.resolve('vi', const [Locale('en', 'US')]), 'vi');
    });

    test('falls back to first supported device language, then en', () {
      expect(
        AppLocale.resolve(null, const [Locale('fr'), Locale('vi', 'VN')]),
        'vi',
      );
      expect(AppLocale.resolve('xx', const [Locale('en', 'GB')]), 'en');
      expect(AppLocale.resolve(null, const [Locale('ja')]), 'en');
      expect(AppLocale.resolve(null, const []), 'en');
    });
  });

  group('LastVisitService (web BuyerLastVisitTracker)', () {
    test('posts last-visit when logged in, throttled; skips guests', () async {
      var now = DateTime(2026, 11, 10, 12);
      final storage = _Storage(accessToken: 'opaque');
      final c = _client(storage, api: (_) => _json(200, {'code': 0}));
      final service = LastVisitService(c.client, storage, now: () => now);

      await service.touch();
      await service.touch();
      expect(c.api.requests, hasLength(1));
      expect(c.api.requests.single.method, 'POST');
      expect(c.api.requests.single.path, LastVisitService.path);

      now = now.add(LastVisitService.minInterval);
      await service.touch();
      await service.touch(force: true);
      expect(c.api.requests, hasLength(3));

      storage.accessToken = null;
      await service.touch(force: true);
      expect(c.api.requests, hasLength(3));
    });

    test('API errors are swallowed', () async {
      final storage = _Storage(accessToken: 'opaque');
      final c = _client(storage, api: (_) => _json(500, {}));
      await LastVisitService(c.client, storage).touch();
      expect(c.api.requests, hasLength(1));
    });
  });

  group('HomeMenuDrawer auth gating (web Drawer / buildAccountNav)', () {
    Future<void> pump(WidgetTester tester, HomeMenuState state) {
      // Màn điện thoại thật (375x812) — mặc định 800x600 làm ScreenUtil phóng to chữ.
      tester.view
        ..physicalSize = const Size(1125, 2436)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          child: MaterialApp(
            home: Scaffold(
              body: BlocProvider<HomeMenuCubit>.value(
                value: _MenuCubit(state),
                child: const HomeMenuDrawer(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('guest: sign up + sign in, no Messages / My requests', (
      tester,
    ) async {
      await pump(tester, const HomeMenuState());
      expect(find.text('navUserSignUp'), findsOneWidget);
      expect(find.text('authSignIn'), findsOneWidget);
      expect(find.text('navSocialMarket'), findsOneWidget);
      expect(find.text('homeMenuNewRequest'), findsOneWidget);
      expect(find.text('myRequestsTitle'), findsNothing);
      expect(find.text('messagesTitle'), findsNothing);
    });

    testWidgets('logged in: My requests + Messages, no sign up', (
      tester,
    ) async {
      await pump(
        tester,
        const HomeMenuState(loggedIn: true, userId: 7, name: 'Ann Lee'),
      );
      expect(find.text('myRequestsTitle'), findsOneWidget);
      expect(find.text('messagesTitle'), findsOneWidget);
      expect(find.text('Ann Lee'), findsOneWidget);
      expect(find.text('navUserSignUp'), findsNothing);
      expect(find.text('authSignIn'), findsNothing);
    });
  });
}
