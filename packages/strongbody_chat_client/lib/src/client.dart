import 'dart:async';

import 'package:http/http.dart' as http;

import 'transport/files.dart' as file_transport;
import 'transport/rest.dart';
import 'transport/ws.dart';
import 'types.dart';

/// PubNub-compatible client for chat-server.
///
/// Drop-in counterpart to the JavaScript ChatPubNub. Mirrors the surface of
/// the existing `pubnub` 7.x Dart package: stream-based listeners, a single
/// publish method, optional withPresence flag on subscribe.
///
/// Usage:
/// ```dart
/// final pubnub = ChatPubNub(
///   endpoint: 'wss://chat-dev.strongbody.ai',
///   tenant: 'strongbody',
///   uuid: 'alice',
///   token: jwt,
/// );
///
/// pubnub.messages.listen((e) => print('${e.publisher}: ${e.message}'));
/// pubnub.status.listen((e) => print('status: ${e.category}'));
/// pubnub.subscribe(channels: {'dm_alice_bob'});
///
/// final res = await pubnub.publish(
///   channel: 'dm_alice_bob',
///   message: {'type': 'text', 'content': 'hi'},
/// );
///
/// await pubnub.disconnect();
/// ```
class ChatPubNub {
  final String endpoint;
  final String tenant;
  final String uuid;
  final String token;

  final WsConnection _ws;
  final RestTransport _rest;

  ChatPubNub({
    required this.endpoint,
    required this.tenant,
    required this.uuid,
    required this.token,
    Duration heartbeatInterval = const Duration(seconds: 30),
    Duration initialReconnectDelay = const Duration(seconds: 1),
    Duration maxReconnectDelay = const Duration(seconds: 30),
    http.Client? httpClient,
    WebSocketFactory? webSocketFactory,
  })  : assert(endpoint.isNotEmpty, 'endpoint is required'),
        assert(tenant.isNotEmpty, 'tenant is required'),
        assert(uuid.isNotEmpty, 'uuid is required'),
        assert(token.isNotEmpty, 'token is required'),
        _ws = WsConnection(
          endpoint: endpoint,
          tenant: tenant,
          token: token,
          heartbeatInterval: heartbeatInterval,
          initialReconnectDelay: initialReconnectDelay,
          maxReconnectDelay: maxReconnectDelay,
          webSocketFactory: webSocketFactory,
        ),
        _rest = RestTransport(
          endpoint: endpoint,
          tenant: tenant,
          token: token,
          httpClient: httpClient,
        );

  /// Broadcast stream of `message` envelopes.
  Stream<MessageEvent> get messages => _ws.messages;

  /// Broadcast stream of `message_edited` envelopes.
  Stream<MessageEditedEvent> get messageEdited => _ws.messageEdited;

  /// Broadcast stream of `message_deleted` envelopes.
  Stream<MessageDeletedEvent> get messageDeleted => _ws.messageDeleted;

  /// Broadcast stream of `presence` envelopes (only meaningful when subscribed
  /// `withPresence: true`).
  Stream<PresenceEvent> get presence => _ws.presence;

  /// Broadcast stream of `status` envelopes (connect, access denied, etc.).
  Stream<StatusEvent> get status => _ws.status;

  /// Subscribe to one or more channels. Lazily opens the WebSocket if needed.
  void subscribe({
    required Set<String> channels,
    bool withPresence = false,
    String? timetoken,
  }) {
    if (channels.isEmpty) {
      throw ArgumentError('channels must be non-empty');
    }
    _ws.subscribe(channels, withPresence: withPresence, timetoken: timetoken);
  }

  /// Unsubscribe from channels. Empty set = leave all.
  void unsubscribe({required Set<String> channels}) {
    _ws.unsubscribe(channels);
  }

  /// Convenience: unsubscribe from everything.
  void unsubscribeAll() => _ws.unsubscribe(const <String>[]);

  /// Fetch persisted messages for a channel (PubNub fetchMessages parity).
  ///
  /// Pass [start] from [FetchMessagesResult.more.start] to load older pages.
  Future<FetchMessagesResult> fetchMessages({
    required String channel,
    int count = 25,
    String? start,
    String? end,
    bool reverse = false,
  }) {
    if (channel.isEmpty) {
      throw ArgumentError('channel is required');
    }
    return _rest.fetchMessages(
      channel: channel,
      count: count,
      start: start,
      end: end,
      reverse: reverse,
    );
  }

  file_transport.FileTransportOpts get _fileOpts =>
      file_transport.FileTransportOpts(
        endpoint: endpoint,
        tenant: tenant,
        token: token,
        httpClient: _rest.httpClient,
      );

  /// Upload a file and publish a file message (presign → S3 PUT → publish).
  ///
  /// Set [SendFileParams.publishType] to `"image"` for image messages.
  Future<SendFileResult> sendFile(SendFileParams params) {
    return file_transport.sendFile(_fileOpts, _rest, params);
  }

  /// Return a download URL for a previously uploaded file (sync, PubNub parity).
  String getFileUrl(GetFileUrlParams params) {
    return file_transport.getFileUrl(_fileOpts, params);
  }

  /// Download file bytes (follows chat-server 302 redirect to S3).
  Future<List<int>> downloadFile(GetFileUrlParams params) {
    return file_transport.downloadFile(_fileOpts, params);
  }

  /// Publish a message to a channel.
  ///
  /// Throws [ChatError] on chat-server errors (use isInvalidToken etc.).
  Future<PublishResult> publish({
    required String channel,
    required Object message,
    Object? meta,
    bool? storeInHistory,
  }) {
    if (channel.isEmpty) {
      throw ArgumentError('channel is required');
    }
    return _rest.publish(
      channel: channel,
      message: message,
      meta: meta,
      storeInHistory: storeInHistory,
    );
  }

  /// Fetch current subscribers on one or more channels (PubNub hereNow parity).
  Future<HereNowResult> hereNow(HereNowParams params) {
    return _rest.hereNow(params);
  }

  /// Tear down the WebSocket + HTTP client. The instance is unusable after this.
  Future<void> disconnect() async {
    _rest.close();
    await _ws.close();
  }
}
