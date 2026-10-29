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

ChatPubNub _newClient({http.Client? httpClient}) {
  return ChatPubNub(
    endpoint: _base['endpoint']!,
    tenant: _base['tenant']!,
    uuid: _base['uuid']!,
    token: _base['token']!,
    httpClient: httpClient,
    webSocketFactory: FakeWebSocketChannel.build,
    heartbeatInterval: Duration.zero,
  );
}

void main() {
  group('sendFile', () {
    test('presigns + uploads + publishes a file envelope', () async {
      final List<Map<String, String>> stages = <Map<String, String>>[];
      final FakeHttpClient fakeHttp = FakeHttpClient((http.Request req) async {
        if (req.method == 'POST' &&
            req.url.path.contains('/v3/files/strongbody/dm_a_b')) {
          stages.add(<String, String>{'stage': 'presign'});
          return http.Response(
            jsonEncode(<String, String>{
              'id': 'file-id-1',
              'name': 'cat.png',
              'uploadUrl': 'https://bucket.s3.amazonaws.com/signed-put',
              'expiresAt': '2030-01-01T00:00:00Z',
            }),
            200,
          );
        }
        if (req.method == 'PUT' &&
            req.url.toString() == 'https://bucket.s3.amazonaws.com/signed-put') {
          stages.add(<String, String>{'stage': 's3'});
          return http.Response('', 200);
        }
        if (req.method == 'POST' &&
            req.url.path.contains('/v3/publish/strongbody/dm_a_b')) {
          stages.add(<String, String>{'stage': 'publish'});
          final Object? body = jsonDecode(req.body);
          expect(body, isA<Map<String, dynamic>>());
          final Map<String, dynamic> msg =
              (body as Map<String, dynamic>)['message'] as Map<String, dynamic>;
          expect(msg['type'], 'file');
          expect(msg['file'], <String, dynamic>{'id': 'file-id-1', 'name': 'cat.png', 'size': 4});
          return http.Response(jsonEncode(<String, String>{'timetoken': '17806530653838033'}), 200);
        }
        return http.Response('not found', 404);
      });

      final ChatPubNub pubnub = _newClient(httpClient: fakeHttp);
      final SendFileResult result = await pubnub.sendFile(
        SendFileParams(
          channel: 'dm_a_b',
          file: SendFilePayload(
            name: 'cat.png',
            data: <int>[1, 2, 3, 4],
            mimeType: 'image/png',
          ),
        ),
      );

      expect(result.id, 'file-id-1');
      expect(result.name, 'cat.png');
      expect(result.timetoken, '17806530653838033');
      expect(stages.map((Map<String, String> s) => s['stage']).toList(),
          <String>['presign', 's3', 'publish']);
      await pubnub.disconnect();
    });

    test('publishType image is forwarded to publish envelope', () async {
      Object? publishedMessage;
      final FakeHttpClient fakeHttp = FakeHttpClient((http.Request req) async {
        if (req.method == 'POST' && req.url.path.contains('/v3/files/')) {
          return http.Response(
            jsonEncode(<String, String>{
              'id': 'img-1',
              'name': 'photo.jpg',
              'uploadUrl': 'https://bucket/put',
              'expiresAt': '2030-01-01T00:00:00Z',
            }),
            200,
          );
        }
        if (req.method == 'PUT') return http.Response('', 200);
        if (req.method == 'POST' && req.url.path.contains('/publish/')) {
          publishedMessage =
              (jsonDecode(req.body) as Map<String, dynamic>)['message'];
          return http.Response(jsonEncode(<String, String>{'timetoken': '1'}), 200);
        }
        return http.Response('', 404);
      });

      final ChatPubNub pubnub = _newClient(httpClient: fakeHttp);
      await pubnub.sendFile(
        SendFileParams(
          channel: 'dm_a_b',
          publishType: 'image',
          file: SendFilePayload(name: 'photo.jpg', data: <int>[1]),
        ),
      );

      expect(publishedMessage, isA<Map<String, dynamic>>());
      expect((publishedMessage as Map<String, dynamic>)['type'], 'image');
      await pubnub.disconnect();
    });

    test('surfaces presign error with typed code', () async {
      final FakeHttpClient fakeHttp = FakeHttpClient((http.Request req) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'error': <String, String>{
              'code': 'no_write_permission',
              'message': 'denied',
            },
          }),
          403,
        );
      });

      final ChatPubNub pubnub = _newClient(httpClient: fakeHttp);
      await expectLater(
        pubnub.sendFile(
          SendFileParams(
            channel: 'c',
            file: SendFilePayload(name: 'x.bin', data: <int>[]),
          ),
        ),
        throwsA(isA<ChatError>().having((ChatError e) => e.code, 'code', 'no_write_permission')),
      );
      await pubnub.disconnect();
    });
  });

  group('getFileUrl', () {
    test('returns sync URL with token query', () {
      final ChatPubNub pubnub = _newClient();
      final String url = pubnub.getFileUrl(
        GetFileUrlParams(channel: 'dm_a_b', id: 'file-id-1', name: 'cat.png'),
      );
      expect(
        url,
        'https://chat-dev.example/v3/files/strongbody/dm_a_b/file-id-1/cat.png?token=alice-jwt',
      );
      pubnub.disconnect();
    });
  });

  group('downloadFile', () {
    test('returns bytes from redirected GET', () async {
      final FakeHttpClient fakeHttp = FakeHttpClient((http.Request req) async {
        expect(req.url.queryParameters['token'], 'alice-jwt');
        return http.Response('file-bytes', 200);
      });

      final ChatPubNub pubnub = _newClient(httpClient: fakeHttp);
      final List<int> bytes = await pubnub.downloadFile(
        GetFileUrlParams(channel: 'dm_a_b', id: 'id1', name: 'doc.pdf'),
      );
      expect(bytes, 'file-bytes'.codeUnits);
      await pubnub.disconnect();
    });
  });
}
