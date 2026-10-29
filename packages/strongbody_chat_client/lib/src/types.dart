/// Per-channel permission bits (1 = granted, 0 = not).
class Perm {
  final int r; // read: subscribe + history
  final int w; // write: publish + sendFile
  final int e; // edit: update existing message (StrongBody-only)
  final int g; // get: hereNow, presence
  final int d; // delete: message action (reserved)
  final int j; // join: presence join (reserved)
  final int u; // update: objects (reserved)
  final int m; // manage: admin (reserved)

  const Perm({
    this.r = 0,
    this.w = 0,
    this.e = 0,
    this.g = 0,
    this.d = 0,
    this.j = 0,
    this.u = 0,
    this.m = 0,
  });

  Map<String, int> toJson() {
    final Map<String, int> json = <String, int>{};
    if (r != 0) json['r'] = r;
    if (w != 0) json['w'] = w;
    if (e != 0) json['e'] = e;
    if (g != 0) json['g'] = g;
    if (d != 0) json['d'] = d;
    if (j != 0) json['j'] = j;
    if (u != 0) json['u'] = u;
    if (m != 0) json['m'] = m;
    return json;
  }
}

/// PubNub-compatible status category constants.
class StatusCategory {
  static const String connected = 'PNConnectedCategory';
  static const String disconnected = 'PNDisconnectedCategory';
  static const String reconnected = 'PNReconnectedCategory';
  static const String accessDenied = 'PNAccessDeniedCategory';
  static const String unknown = 'PNUnknownCategory';
  static const String networkIssues = 'PNNetworkIssuesCategory';
  static const String catchupSkipped = 'PNCatchupSkippedCategory';
}

/// Server-pushed message envelope.
class MessageEvent {
  final String channel;
  final String timetoken;
  final String publisher;
  final Object? message;
  final Object? userMetadata;

  const MessageEvent({
    required this.channel,
    required this.timetoken,
    required this.publisher,
    required this.message,
    this.userMetadata,
  });

  factory MessageEvent.fromJson(Map<String, dynamic> j) => MessageEvent(
        channel: j['channel'] as String,
        timetoken: j['timetoken'] as String,
        publisher: j['publisher'] as String,
        message: j['message'],
        userMetadata: j['userMetadata'],
      );
}

/// Server-pushed envelope when an existing message is edited.
class MessageEditedEvent {
  final String channel;
  final String timetoken;
  final String publisher;
  final Object? message;

  const MessageEditedEvent({
    required this.channel,
    required this.timetoken,
    required this.publisher,
    required this.message,
  });

  factory MessageEditedEvent.fromJson(Map<String, dynamic> j) =>
      MessageEditedEvent(
        channel: j['channel'] as String,
        timetoken: j['timetoken'] as String,
        publisher: j['publisher'] as String? ?? '',
        message: j['message'],
      );
}

/// Server-pushed envelope when a message is deleted.
class MessageDeletedEvent {
  final String channel;
  final String timetoken;
  final String publisher;

  const MessageDeletedEvent({
    required this.channel,
    required this.timetoken,
    required this.publisher,
  });

  factory MessageDeletedEvent.fromJson(Map<String, dynamic> j) =>
      MessageDeletedEvent(
        channel: j['channel'] as String,
        timetoken: j['timetoken'] as String,
        publisher: j['publisher'] as String? ?? '',
      );
}

/// Server-pushed presence envelope.
class PresenceEvent {
  final String channel;
  final String action; // join | leave | timeout | interval | state-change
  final String uuid;
  final int occupancy;
  final String timetoken;
  final int timestamp;

  const PresenceEvent({
    required this.channel,
    required this.action,
    required this.uuid,
    required this.occupancy,
    required this.timetoken,
    required this.timestamp,
  });

  factory PresenceEvent.fromJson(Map<String, dynamic> j) => PresenceEvent(
        channel: j['channel'] as String,
        action: j['action'] as String,
        uuid: j['uuid'] as String,
        occupancy: (j['occupancy'] as num).toInt(),
        timetoken: j['timetoken'] as String,
        timestamp: (j['timestamp'] as num).toInt(),
      );
}

/// Server-pushed status / lifecycle envelope.
class StatusEvent {
  final String category;
  final int statusCode;
  final String? operation;
  final List<String>? affectedChannels;
  final String? error;

  const StatusEvent({
    required this.category,
    required this.statusCode,
    this.operation,
    this.affectedChannels,
    this.error,
  });

  factory StatusEvent.fromJson(Map<String, dynamic> j) => StatusEvent(
        category: j['category'] as String,
        statusCode: (j['statusCode'] as num).toInt(),
        operation: j['operation'] as String?,
        affectedChannels: (j['affectedChannels'] as List?)?.cast<String>(),
        error: j['error'] as String?,
      );
}

/// The result of a successful publish.
class PublishResult {
  final String timetoken;
  const PublishResult(this.timetoken);
}

/// One message row from GET /v3/history (PubNub fetchMessages parity).
class HistoryMessage {
  final String timetoken;
  final String publisher;
  final Object? message;

  const HistoryMessage({
    required this.timetoken,
    required this.publisher,
    required this.message,
  });

  factory HistoryMessage.fromJson(Map<String, dynamic> j) => HistoryMessage(
        timetoken: j['timetoken'] as String,
        publisher: j['publisher'] as String,
        message: j['message'],
      );
}

/// Pagination hint from history response.
class HistoryMore {
  final String start;
  final int count;

  const HistoryMore({required this.start, required this.count});

  factory HistoryMore.fromJson(Map<String, dynamic> j) => HistoryMore(
        start: j['start'] as String,
        count: (j['count'] as num).toInt(),
      );
}

/// Payload for [SendFileParams.file].
class SendFilePayload {
  final String name;
  final List<int> data;
  final String? mimeType;

  const SendFilePayload({
    required this.name,
    required this.data,
    this.mimeType,
  });
}

/// Parameters for sendFile (presign → S3 PUT → publish).
class SendFileParams {
  final String channel;
  final SendFilePayload file;
  /// Optional caption / structured payload attached to the file message.
  final Object? message;
  final bool? storeInHistory;
  final Object? meta;
  /// Envelope `type` published after upload — `"file"` or `"image"`.
  final String publishType;
  /// Sender user id — included in publish envelope when set.
  final int? uuid;

  const SendFileParams({
    required this.channel,
    required this.file,
    this.message,
    this.storeInHistory,
    this.meta,
    this.publishType = 'file',
    this.uuid,
  });
}

/// Result of a successful sendFile.
class SendFileResult {
  final String id;
  final String name;
  final String timetoken;

  const SendFileResult({
    required this.id,
    required this.name,
    required this.timetoken,
  });
}

/// Parameters for getFileUrl.
class GetFileUrlParams {
  final String channel;
  final String id;
  final String name;

  const GetFileUrlParams({
    required this.channel,
    required this.id,
    required this.name,
  });
}

/// Result of fetchMessages — mirrors PubNub HistoryResponse shape.
class FetchMessagesResult {
  final List<HistoryMessage> messages;
  final HistoryMore? more;

  const FetchMessagesResult({required this.messages, this.more});

  factory FetchMessagesResult.fromChannelJson(
    String channel,
    Map<String, dynamic> j,
  ) {
    final channels = j['channels'] as Map<String, dynamic>? ?? {};
    final raw = channels[channel] as List? ?? const [];
    final messages = raw
        .map((e) => HistoryMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    HistoryMore? more;
    if (j['more'] is Map<String, dynamic>) {
      more = HistoryMore.fromJson(j['more'] as Map<String, dynamic>);
    }
    return FetchMessagesResult(messages: messages, more: more);
  }
}

/// Parameters for hereNow (PubNub parity).
class HereNowParams {
  final List<String> channels;
  final bool includeUUIDs;

  const HereNowParams({
    required this.channels,
    this.includeUUIDs = true,
  });
}

/// One channel occupancy from hereNow.
class HereNowChannel {
  final String name;
  final int occupancy;
  final List<String> uuids;

  const HereNowChannel({
    required this.name,
    required this.occupancy,
    required this.uuids,
  });
}

/// Result of hereNow across one or more channels.
class HereNowResult {
  final int totalChannels;
  final int totalOccupancy;
  final Map<String, HereNowChannel> channels;

  const HereNowResult({
    required this.totalChannels,
    required this.totalOccupancy,
    required this.channels,
  });
}
