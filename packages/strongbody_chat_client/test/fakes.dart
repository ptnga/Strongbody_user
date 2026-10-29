import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// In-memory WebSocketChannel. Tests drive `serverOpen` / `serverPush` / `serverClose`.
class FakeWebSocketChannel implements WebSocketChannel {
  // The SDK only uses .stream / .sink / .closeCode — every other StreamChannel
  // member is irrelevant to these tests. Forward them to noSuchMethod so we
  // don't have to stub `cast`, `pipe`, `changeSink`, …
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);

  final Uri url;
  final StreamController<dynamic> _incoming =
      StreamController<dynamic>.broadcast();
  final _FakeSink _sink;
  int? _closeCode;
  String? _closeReason;
  bool _closed = false;

  FakeWebSocketChannel(this.url) : _sink = _FakeSink() {
    _sink._channel = this;
  }

  static final List<FakeWebSocketChannel> instances = <FakeWebSocketChannel>[];

  static FakeWebSocketChannel build(Uri url) {
    final FakeWebSocketChannel c = FakeWebSocketChannel(url);
    instances.add(c);
    return c;
  }

  static FakeWebSocketChannel get last => instances.last;
  static void reset() => instances.clear();

  // --- WebSocketChannel surface --------------------------------------------
  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready async {}

  // --- test helpers ---------------------------------------------------------
  void serverPush(Object frame) {
    final String s = frame is String ? frame : jsonEncode(frame);
    _incoming.add(s);
  }

  void serverClose(int code, [String reason = '']) {
    if (_closed) return;
    _closed = true;
    _closeCode = code;
    _closeReason = reason;
    _incoming.close();
  }

  /// Frames the client sent, as JSON-decoded maps.
  List<Map<String, dynamic>> get sentFrames => _sink.sent
      .map((Object e) =>
          e is String ? jsonDecode(e) as Map<String, dynamic> : e as Map<String, dynamic>)
      .toList();
}

class _FakeSink implements WebSocketSink {
  late FakeWebSocketChannel _channel;
  final List<Object> sent = <Object>[];

  @override
  void add(Object? event) {
    if (event != null) sent.add(event);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Object?> stream) async {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    _channel._closeCode = closeCode;
    _channel._closeReason = closeReason;
    _channel._closed = true;
    await _channel._incoming.close();
  }

  @override
  Future<void> get done async {}
}

/// Fake http.Client that responds via the supplied handler. Records calls.
class FakeHttpClient extends http.BaseClient {
  FakeHttpClient(this.handler);

  final Future<http.Response> Function(http.Request req) handler;
  final List<http.Request> calls = <http.Request>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is! http.Request) {
      throw StateError('FakeHttpClient only handles http.Request');
    }
    calls.add(request);
    final http.Response res = await handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
      reasonPhrase: res.reasonPhrase,
    );
  }
}
