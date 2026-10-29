import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors.dart';
import '../types.dart';

/// Convert an absolute wss:// or ws:// URL prefix to https:// or http://.
String toHttpBase(String endpoint) {
  String s = endpoint;
  if (s.startsWith('wss://')) {
    s = 'https://${s.substring(6)}';
  } else if (s.startsWith('ws://')) {
    s = 'http://${s.substring(5)}';
  }
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// REST publish — POST /v3/publish/{tenant}/{channel}.
class RestTransport {
  final String endpoint;
  final String tenant;
  final String token;
  final http.Client httpClient;

  RestTransport({
    required this.endpoint,
    required this.tenant,
    required this.token,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  Future<PublishResult> publish({
    required String channel,
    required Object message,
    Object? meta,
    bool? storeInHistory,
  }) async {
    final String base = toHttpBase(endpoint);
    final Uri url = Uri.parse(
        '$base/v3/publish/${Uri.encodeComponent(tenant)}/${Uri.encodeComponent(channel)}');

    final Map<String, dynamic> body = <String, dynamic>{'message': message};
    if (meta != null) body['meta'] = meta;
    if (storeInHistory != null) body['storeInHistory'] = storeInHistory;

    final http.Response res = await httpClient.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw parseErrorBody(res.statusCode, res.body);
    }

    final Object? decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic> || decoded['timetoken'] is! String) {
      throw ChatError(
        httpStatus: res.statusCode,
        code: ErrorCode.transportError,
        message: 'malformed publish response: ${res.body}',
      );
    }
    return PublishResult(decoded['timetoken'] as String);
  }

  /// GET /v3/history/{tenant}/{channel} — PubNub fetchMessages parity.
  Future<FetchMessagesResult> fetchMessages({
    required String channel,
    int count = 25,
    String? start,
    String? end,
    bool reverse = false,
  }) async {
    final String base = toHttpBase(endpoint);
    final Map<String, String> query = <String, String>{
      'count': count.toString(),
      if (start != null && start.isNotEmpty) 'start': start,
      if (end != null && end.isNotEmpty) 'end': end,
      if (reverse) 'reverse': 'true',
    };
    final Uri url = Uri.parse(
      '$base/v3/history/${Uri.encodeComponent(tenant)}/${Uri.encodeComponent(channel)}',
    ).replace(queryParameters: query);

    final http.Response res = await httpClient.get(
      url,
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw parseErrorBody(res.statusCode, res.body);
    }

    final Object? decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw ChatError(
        httpStatus: res.statusCode,
        code: ErrorCode.transportError,
        message: 'malformed history response: ${res.body}',
      );
    }
    return FetchMessagesResult.fromChannelJson(channel, decoded);
  }

  /// GET /v3/presence/{tenant}/{channel}/hereNow — PubNub hereNow parity.
  Future<HereNowResult> hereNow(HereNowParams params) async {
    if (params.channels.isEmpty) {
      throw ArgumentError('hereNow: channels must be non-empty');
    }

    final String base = toHttpBase(endpoint);
    final Map<String, HereNowChannel> channels = <String, HereNowChannel>{};
    var totalOccupancy = 0;

    for (final String ch in params.channels) {
      final Map<String, String> query = <String, String>{};
      if (!params.includeUUIDs) {
        query['includeUUIDs'] = 'false';
      }
      final Uri url = Uri.parse(
        '$base/v3/presence/${Uri.encodeComponent(tenant)}/${Uri.encodeComponent(ch)}/hereNow',
      ).replace(queryParameters: query.isEmpty ? null : query);

      final http.Response res = await httpClient.get(
        url,
        headers: <String, String>{
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw parseErrorBody(res.statusCode, res.body);
      }

      final Object? decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        throw ChatError(
          httpStatus: res.statusCode,
          code: ErrorCode.transportError,
          message: 'malformed hereNow response: ${res.body}',
        );
      }

      final int occupancy = (decoded['occupancy'] as num?)?.toInt() ?? 0;
      final List<String> uuids = params.includeUUIDs
          ? (decoded['uuids'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              <String>[]
          : <String>[];
      channels[ch] = HereNowChannel(
        name: ch,
        occupancy: occupancy,
        uuids: uuids,
      );
      totalOccupancy += occupancy;
    }

    return HereNowResult(
      totalChannels: channels.length,
      totalOccupancy: totalOccupancy,
      channels: channels,
    );
  }

  void close() => httpClient.close();
}
