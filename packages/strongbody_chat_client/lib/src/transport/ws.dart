import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../types.dart';

/// Convert an absolute http(s):// or ws(s):// URL prefix to ws:// or wss://.
String toWsBase(String endpoint) {
  String s = endpoint.trim();
  if (s.startsWith('https://')) {
    s = 'wss://${s.substring(8)}';
  } else if (s.startsWith('http://')) {
    s = 'ws://${s.substring(7)}';
  }
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  // Strip invalid explicit port 0 (Android WebSocket throws :0 / not upgraded).
  s = s.replaceFirst(RegExp(r':0(?=/|$)'), '');
  return s;
}

Uri buildSubscribeUri({
  required String endpoint,
  required String token,
  required String tenant,
}) {
  final baseUri = Uri.parse(toWsBase(endpoint));
  final defaultPort = baseUri.scheme == 'wss' ? 443 : 80;
  final port = baseUri.hasPort && baseUri.port != 0 ? baseUri.port : defaultPort;
  return baseUri.replace(
    port: port,
    path: '/v3/subscribe',
    queryParameters: <String, String>{
      'token': token,
      'tenant': tenant,
    },
  );
}

/// Factory signature: build a [WebSocketChannel] from a URL. Injectable for tests.
typedef WebSocketFactory = WebSocketChannel Function(Uri url);

class _SubscriptionState {
  final Set<String> channels = <String>{};
  bool withPresence = false;
  String? timetoken;
}

/// Long-lived WebSocket connection. Owns the subscription set, heartbeat
/// timer, and reconnect timer. Drives three outbound streams:
/// messages, presence, status.
class WsConnection {
  final String endpoint;
  final String tenant;
  final String token;
  final Duration heartbeatInterval;
  final Duration initialReconnectDelay;
  final Duration maxReconnectDelay;
  final WebSocketFactory webSocketFactory;
  final math.Random _rng;

  final StreamController<MessageEvent> _messages =
      StreamController<MessageEvent>.broadcast();
  final StreamController<MessageEditedEvent> _messageEdited =
      StreamController<MessageEditedEvent>.broadcast();
  final StreamController<MessageDeletedEvent> _messageDeleted =
      StreamController<MessageDeletedEvent>.broadcast();
  final StreamController<PresenceEvent> _presence =
      StreamController<PresenceEvent>.broadcast();
  final StreamController<StatusEvent> _status =
      StreamController<StatusEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSub;
  Timer? _hbTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  /// Đã từng có kết nối chạy được → lần mở sau là reconnect (báo `reconnected`).
  bool _everConnected = false;

  /// Kết nối hiện tại chưa nhận frame nào (handshake có thể vẫn hỏng).
  bool _awaitingFirstFrame = false;
  bool _closed = false;
  bool _fatal = false; // 4401/4403 — don't auto-reconnect
  final _SubscriptionState _state = _SubscriptionState();

  WsConnection({
    required this.endpoint,
    required this.tenant,
    required this.token,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.initialReconnectDelay = const Duration(seconds: 1),
    this.maxReconnectDelay = const Duration(seconds: 30),
    WebSocketFactory? webSocketFactory,
    math.Random? random,
  })  : webSocketFactory = webSocketFactory ??
            ((Uri u) => WebSocketChannel.connect(u)),
        _rng = random ?? math.Random();

  Stream<MessageEvent> get messages => _messages.stream;
  Stream<MessageEditedEvent> get messageEdited => _messageEdited.stream;
  Stream<MessageDeletedEvent> get messageDeleted => _messageDeleted.stream;
  Stream<PresenceEvent> get presence => _presence.stream;
  Stream<StatusEvent> get status => _status.stream;

  bool get isOpen => _channel != null && !_closed;

  void connect() {
    if (_closed || _channel != null || _fatal) return;
    final Uri url = buildSubscribeUri(
      endpoint: endpoint,
      token: token,
      tenant: tenant,
    );
    try {
      _channel = webSocketFactory(url);
    } catch (e) {
      _scheduleReconnect();
      return;
    }

    _channelSub = _channel!.stream.listen(
      _onFrame,
      onError: (_) {
        // Treat errors as close — the close handler will fire next.
      },
      onDone: _onClose,
      cancelOnError: false,
    );

    // Chỉ reset backoff khi nhận frame đầu tiên (connect() lỗi bất đồng bộ → nếu reset
    // ở đây mọi lần thử lại đều dùng delay nhỏ nhất).
    _awaitingFirstFrame = true;
    _startHeartbeat();

    if (_state.channels.isNotEmpty) {
      _send(<String, dynamic>{
        'op': 'subscribe',
        'channels': _state.channels.toList(),
        'withPresence': _state.withPresence,
        if (_state.timetoken != null) 'timetoken': _state.timetoken,
      });
    }
  }

  void subscribe(Iterable<String> channels,
      {bool withPresence = false, String? timetoken}) {
    _state.channels.addAll(channels);
    if (withPresence) _state.withPresence = true;
    if (timetoken != null) _state.timetoken = timetoken;

    if (isOpen) {
      _send(<String, dynamic>{
        'op': 'subscribe',
        'channels': channels.toList(),
        'withPresence': _state.withPresence,
        if (timetoken != null) 'timetoken': timetoken,
      });
    } else if (!_fatal) {
      connect();
    }
  }

  void unsubscribe(Iterable<String> channels) {
    final List<String> list = channels.toList();
    if (list.isEmpty) {
      _state.channels.clear();
    } else {
      for (final String c in list) {
        _state.channels.remove(c);
      }
    }
    if (isOpen) {
      _send(<String, dynamic>{'op': 'unsubscribe', 'channels': list});
    }
  }

  Future<void> close() async {
    _closed = true;
    _hbTimer?.cancel();
    _reconnectTimer?.cancel();
    final WebSocketChannel? ch = _channel;
    _channel = null;
    await _channelSub?.cancel();
    if (ch != null) {
      try {
        await ch.sink.close(1000, 'client closed');
      } catch (_) {}
    }
    await _messages.close();
    await _messageEdited.close();
    await _messageDeleted.close();
    await _presence.close();
    await _status.close();
  }

  // --- internals ------------------------------------------------------------

  void _send(Object payload) {
    final WebSocketChannel? ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(payload));
    } catch (_) {
      // socket may have died between isOpen and add; ignore.
    }
  }

  void _onFrame(Object? raw) {
    if (_awaitingFirstFrame) {
      _awaitingFirstFrame = false;
      _reconnectAttempt = 0;
      if (_everConnected && !_status.isClosed) {
        // Có thể đã lỡ tin trong lúc mất kết nối → bên dùng tự tải lại history.
        _status.add(
          const StatusEvent(
            category: StatusCategory.reconnected,
            statusCode: 200,
          ),
        );
      }
      _everConnected = true;
    }
    if (raw is! String) return;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    final Object? evt = decoded['event'];
    if (evt is! String) return;
    switch (evt) {
      case 'message':
        _messages.add(MessageEvent.fromJson(decoded));
        break;
      case 'message_edited':
        _messageEdited.add(MessageEditedEvent.fromJson(decoded));
        break;
      case 'message_deleted':
        _messageDeleted.add(MessageDeletedEvent.fromJson(decoded));
        break;
      case 'presence':
        _presence.add(PresenceEvent.fromJson(decoded));
        break;
      case 'status':
        _status.add(StatusEvent.fromJson(decoded));
        break;
      default:
        break;
    }
  }

  void _onClose() {
    final int? code = _channel?.closeCode;
    _hbTimer?.cancel();
    _hbTimer = null;
    _channel = null;
    _channelSub?.cancel();
    _channelSub = null;

    final int effectiveCode = code ?? 1006;
    _status.add(StatusEvent(
      category: _categoryFor(effectiveCode),
      statusCode: effectiveCode,
    ));

    if (_closed) return;
    if (effectiveCode == 4401 || effectiveCode == 4403) {
      _fatal = true;
      return;
    }
    _scheduleReconnect();
  }

  void _startHeartbeat() {
    _hbTimer?.cancel();
    if (heartbeatInterval == Duration.zero) return;
    _hbTimer = Timer.periodic(heartbeatInterval, (_) {
      if (isOpen) _send(<String, dynamic>{'op': 'hb'});
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final int attempt = _reconnectAttempt++;
    final int baseMs = math.min<int>(
      maxReconnectDelay.inMilliseconds,
      initialReconnectDelay.inMilliseconds * (1 << attempt),
    );
    // jitter ±20%
    final int jittered = (baseMs * (0.8 + 0.4 * _rng.nextDouble())).floor();
    _reconnectTimer = Timer(Duration(milliseconds: jittered), () {
      _reconnectTimer = null;
      if (!_closed) connect();
    });
  }

  String _categoryFor(int code) {
    if (code == 1000) return StatusCategory.disconnected;
    if (code == 4401 || code == 4403) return StatusCategory.accessDenied;
    if (code == 4408) return StatusCategory.networkIssues;
    return StatusCategory.unknown;
  }
}
