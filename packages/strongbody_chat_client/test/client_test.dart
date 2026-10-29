import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:strongbody_chat_client/strongbody_chat_client.dart';
import 'package:test/test.dart';

import 'fakes.dart';

const Map<String, String> _base = <String, String>{
  'endpoint': 'wss://chat-dev.example',
  'tenant': 'strongbody',
  'uuid': 'alice',
  'token': 'alice-jwt',
};

ChatPubNub _newClient({
  http.Client? httpClient,
  WebSocketFactory? wsFactory,
  Duration hb = Duration.zero,
  Duration initialReconnect = const Duration(milliseconds: 50),
  Duration maxReconnect = const Duration(milliseconds: 100),
}) {
  return ChatPubNub(
    endpoint: _base['endpoint']!,
    tenant: _base['tenant']!,
    uuid: _base['uuid']!,
    token: _base['token']!,
    httpClient: httpClient,
    webSocketFactory: wsFactory ?? FakeWebSocketChannel.build,
    heartbeatInterval: hb,
    initialReconnectDelay: initialReconnect,
    maxReconnectDelay: maxReconnect,
  );
}

void main() {
  setUp(() => FakeWebSocketChannel.reset());

  group('constructor', () {
    test('rejects missing fields', () {
      expect(() => ChatPubNub(endpoint: '', tenant: 't', uuid: 'u', token: 'k'),
          throwsA(isA<AssertionError>()));
      expect(() => ChatPubNub(endpoint: 'x', tenant: '', uuid: 'u', token: 'k'),
          throwsA(isA<AssertionError>()));
      expect(() => ChatPubNub(endpoint: 'x', tenant: 't', uuid: '', token: 'k'),
          throwsA(isA<AssertionError>()));
      expect(() => ChatPubNub(endpoint: 'x', tenant: 't', uuid: 'u', token: ''),
          throwsA(isA<AssertionError>()));
    });
  });

  group('subscribe + streams', () {
    test('subscribing sends the op once the socket opens', () async {
      final ChatPubNub pubnub = _newClient();
      pubnub.subscribe(channels: <String>{'dm_a_b'}, withPresence: true);
      // tiny wait for the connect microtask
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final FakeWebSocketChannel ws = FakeWebSocketChannel.last;
      expect(ws.sentFrames, isNotEmpty);
      final Map<String, dynamic> frame = ws.sentFrames.last;
      expect(frame['op'], 'subscribe');
      expect(frame['channels'], <String>['dm_a_b']);
      expect(frame['withPresence'], true);
      await pubnub.disconnect();
    });

    test('message frames stream through .messages', () async {
      final ChatPubNub pubnub = _newClient();
      pubnub.subscribe(channels: <String>{'dm_a_b'});
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final Future<MessageEvent> first = pubnub.messages.first;
      final FakeWebSocketChannel ws = FakeWebSocketChannel.last;
      ws.serverPush(<String, dynamic>{
        'event': 'message',
        'channel': 'dm_a_b',
        'timetoken': '17800000000000000',
        'publisher': 'bob',
        'message': <String, dynamic>{'type': 'text', 'content': 'hi'},
      });

      final MessageEvent e = await first;
      expect(e.channel, 'dm_a_b');
      expect(e.publisher, 'bob');
      expect((e.message as Map<String, dynamic>)['content'], 'hi');
      await pubnub.disconnect();
    });

    test('presence frames stream through .presence', () async {
      final ChatPubNub pubnub = _newClient();
      pubnub.subscribe(
          channels: <String>{'presence_global'}, withPresence: true);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final Future<PresenceEvent> first = pubnub.presence.first;
      FakeWebSocketChannel.last.serverPush(<String, dynamic>{
        'event': 'presence',
        'channel': 'presence_global',
        'action': 'join',
        'uuid': 'alice',
        'occupancy': 42,
        'timetoken': '17800000000000001',
        'timestamp': 1717200000,
      });

      final PresenceEvent e = await first;
      expect(e.action, 'join');
      expect(e.occupancy, 42);
      await pubnub.disconnect();
    });

    test('malformed frames are ignored', () async {
      final ChatPubNub pubnub = _newClient();
      pubnub.subscribe(channels: <String>{'dm_a_b'});
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final List<MessageEvent> seen = <MessageEvent>[];
      final StreamSubscription<MessageEvent> sub =
          pubnub.messages.listen(seen.add);
      final FakeWebSocketChannel ws = FakeWebSocketChannel.last;
      ws.serverPush('not-json');
      ws.serverPush('{');
      ws.serverPush(<String, dynamic>{
        'event': 'message',
        'channel': 'dm_a_b',
        'timetoken': '1',
        'publisher': 'bob',
        'message': <String, dynamic>{},
      });
      // let microtasks drain
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(seen, hasLength(1));
      await sub.cancel();
      await pubnub.disconnect();
    });

    test('empty channels set is rejected', () async {
      final ChatPubNub pubnub = _newClient();
      expect(
          () => pubnub.subscribe(channels: <String>{}), throwsArgumentError);
      await pubnub.disconnect();
    });

    test('unsubscribe sends the op when connected', () async {
      final ChatPubNub pubnub = _newClient();
      pubnub.subscribe(channels: <String>{'dm_a_b'});
      await Future<void>.delayed(const Duration(milliseconds: 10));

      pubnub.unsubscribe(channels: <String>{'dm_a_b'});
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final FakeWebSocketChannel ws = FakeWebSocketChannel.last;
      expect(ws.sentFrames.last['op'], 'unsubscribe');
      expect(ws.sentFrames.last['channels'], <String>['dm_a_b']);
      await pubnub.disconnect();
    });
  });

  group('reconnect', () {
    test('reconnects after close 1011 and re-sends the subscribe op',
        () async {
      final ChatPubNub pubnub = _newClient(
          initialReconnect: const Duration(milliseconds: 10),
          maxReconnect: const Duration(milliseconds: 20));
      pubnub.subscribe(channels: <String>{'dm_a_b'});
      await Future<void>.delayed(const Duration(milliseconds: 10));

      FakeWebSocketChannel.last.serverClose(1011, 'server bounce');
      // wait past the backoff window
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(FakeWebSocketChannel.instances.length, greaterThanOrEqualTo(2));
      final FakeWebSocketChannel ws2 = FakeWebSocketChannel.last;
      expect(
          ws2.sentFrames.any((Map<String, dynamic> f) =>
              f['op'] == 'subscribe' &&
              (f['channels'] as List<dynamic>).contains('dm_a_b')),
          isTrue);
      await pubnub.disconnect();
    });

    test('does NOT reconnect after close 4401', () async {
      final ChatPubNub pubnub = _newClient(
          initialReconnect: const Duration(milliseconds: 10),
          maxReconnect: const Duration(milliseconds: 20));
      pubnub.subscribe(channels: <String>{'dm_a_b'});
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final List<StatusEvent> statuses = <StatusEvent>[];
      final StreamSubscription<StatusEvent> sub =
          pubnub.status.listen(statuses.add);

      FakeWebSocketChannel.last.serverClose(4401, 'token expired');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(FakeWebSocketChannel.instances.length, 1);
      expect(statuses.map((StatusEvent s) => s.category),
          contains(StatusCategory.accessDenied));
      await sub.cancel();
      await pubnub.disconnect();
    });

    test('does NOT reconnect after close 4403', () async {
      final ChatPubNub pubnub = _newClient(
          initialReconnect: const Duration(milliseconds: 10),
          maxReconnect: const Duration(milliseconds: 20));
      pubnub.subscribe(channels: <String>{'dm_a_b'});
      await Future<void>.delayed(const Duration(milliseconds: 10));

      FakeWebSocketChannel.last.serverClose(4403, 'tenant_mismatch');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(FakeWebSocketChannel.instances.length, 1);
      await pubnub.disconnect();
    });
  });

  group('fetchMessages', () {
    test('GETs /v3/history and parses channels wrapper', () async {
      final FakeHttpClient fake = FakeHttpClient((http.Request req) async {
        expect(req.method, 'GET');
        expect(
          req.url.path,
          '/v3/history/strongbody/dm_a_b',
        );
        expect(req.url.queryParameters['count'], '10');
        expect(req.headers['Authorization'], 'Bearer alice-jwt');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'channels': <String, dynamic>{
              'dm_a_b': <Map<String, dynamic>>[
                <String, dynamic>{
                  'timetoken': '17800000000000001',
                  'publisher': 'alice',
                  'message': <String, dynamic>{
                    'type': 'text',
                    'content': 'hi',
                  },
                },
              ],
            },
            'more': <String, dynamic>{'start': '17800000000000001', 'count': 10},
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final ChatPubNub pubnub = _newClient(httpClient: fake);

      final FetchMessagesResult res = await pubnub.fetchMessages(
        channel: 'dm_a_b',
        count: 10,
      );

      expect(res.messages, hasLength(1));
      expect(res.messages.first.timetoken, '17800000000000001');
      expect(res.more?.start, '17800000000000001');
      await pubnub.disconnect();
    });
  });

  group('publish', () {
    test('POSTs to /v3/publish with Bearer token and returns the timetoken',
        () async {
      final FakeHttpClient fake =
          FakeHttpClient((http.Request _) async => http.Response(
                jsonEncode(<String, String>{'timetoken': '17806530653838033'}),
                200,
                headers: <String, String>{'content-type': 'application/json'},
              ));
      final ChatPubNub pubnub = _newClient(httpClient: fake);

      final PublishResult res = await pubnub.publish(
        channel: 'dm_a_b',
        message: <String, dynamic>{'type': 'text', 'content': 'hi'},
      );

      expect(res.timetoken, '17806530653838033');
      expect(fake.calls, hasLength(1));
      final http.Request call = fake.calls.first;
      expect(call.url.toString(),
          'https://chat-dev.example/v3/publish/strongbody/dm_a_b');
      expect(call.headers['Authorization'], 'Bearer alice-jwt');
      await pubnub.disconnect();
    });

    test('threads meta + storeInHistory into the body', () async {
      final FakeHttpClient fake =
          FakeHttpClient((http.Request req) async {
        final Map<String, dynamic> body =
            jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['meta'], <String, dynamic>{'badge': 3});
        expect(body['storeInHistory'], false);
        return http.Response(jsonEncode(<String, String>{'timetoken': '1'}), 200,
            headers: <String, String>{'content-type': 'application/json'});
      });
      final ChatPubNub pubnub = _newClient(httpClient: fake);
      await pubnub.publish(
        channel: 'dm_a_b',
        message: <String, dynamic>{'x': 1},
        meta: <String, dynamic>{'badge': 3},
        storeInHistory: false,
      );
      await pubnub.disconnect();
    });

    test('throws ChatError(invalid_token) on 401', () async {
      final FakeHttpClient fake =
          FakeHttpClient((http.Request _) async => http.Response(
                jsonEncode(<String, dynamic>{
                  'error': <String, String>{
                    'code': 'invalid_token',
                    'message': 'token expired',
                  },
                }),
                401,
                headers: <String, String>{'content-type': 'application/json'},
              ));
      final ChatPubNub pubnub = _newClient(httpClient: fake);
      try {
        await pubnub.publish(
            channel: 'dm_a_b', message: <String, dynamic>{'x': 1});
        fail('should have thrown');
      } catch (e) {
        expect(isInvalidToken(e), isTrue);
      }
      await pubnub.disconnect();
    });

    test('throws ChatError(no_write_permission) on 403', () async {
      final FakeHttpClient fake =
          FakeHttpClient((http.Request _) async => http.Response(
                jsonEncode(<String, dynamic>{
                  'error': <String, String>{
                    'code': 'no_write_permission',
                    'message': 'denied',
                  },
                }),
                403,
                headers: <String, String>{'content-type': 'application/json'},
              ));
      final ChatPubNub pubnub = _newClient(httpClient: fake);
      try {
        await pubnub.publish(
            channel: 'dm_a_b', message: <String, dynamic>{'x': 1});
        fail('should have thrown');
      } catch (e) {
        expect(isNoWritePermission(e), isTrue);
      }
      await pubnub.disconnect();
    });

    test('throws ChatError(tenant_mismatch) on 403', () async {
      final FakeHttpClient fake =
          FakeHttpClient((http.Request _) async => http.Response(
                jsonEncode(<String, dynamic>{
                  'error': <String, String>{
                    'code': 'tenant_mismatch',
                    'message': 'wrong tenant',
                  },
                }),
                403,
                headers: <String, String>{'content-type': 'application/json'},
              ));
      final ChatPubNub pubnub = _newClient(httpClient: fake);
      try {
        await pubnub.publish(
            channel: 'dm_a_b', message: <String, dynamic>{'x': 1});
        fail('should have thrown');
      } catch (e) {
        expect(isTenantMismatch(e), isTrue);
      }
      await pubnub.disconnect();
    });

    test('rejects empty channel', () async {
      final ChatPubNub pubnub = _newClient();
      expect(
          () => pubnub.publish(
              channel: '', message: <String, dynamic>{'x': 1}),
          throwsArgumentError);
      await pubnub.disconnect();
    });
  });
}
