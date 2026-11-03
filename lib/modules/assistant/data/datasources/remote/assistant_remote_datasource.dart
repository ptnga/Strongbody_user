import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';

import '../../api_config/assistant_api_config.dart';

/// Vượt giới hạn số tin (HTTP 429 / BE code 42915).
class AssistantRateLimitException implements Exception {
  const AssistantRateLimitException();
}

/// Tách luồng server-sent events thành các payload `data:` (mỗi event cách nhau 1 dòng trống).
class SseDataParser {
  String _buffer = '';

  List<String> add(String chunk) {
    _buffer += chunk.replaceAll('\r\n', '\n');
    final out = <String>[];
    int i;
    while ((i = _buffer.indexOf('\n\n')) >= 0) {
      final block = _buffer.substring(0, i);
      _buffer = _buffer.substring(i + 2);
      for (final line in block.split('\n')) {
        if (line.startsWith('data:')) out.add(line.substring(5).trim());
      }
    }
    return out;
  }
}

abstract class AssistantRemoteDataSource {
  /// Một lượt chat; mỗi event SSE (JSON) phát ra một phần tử.
  Stream<Map<String, dynamic>> streamChat(
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  });
}

class AssistantRemoteDataSourceImpl implements AssistantRemoteDataSource {
  final ApiClient _apiClient;

  AssistantRemoteDataSourceImpl(this._apiClient);

  /// Như proxy web (`UPSTREAM_TIMEOUT_MS`): nhánh tài liệu stream khá lâu.
  static const _timeout = Duration(seconds: 180);

  @override
  Stream<Map<String, dynamic>> streamChat(
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async* {
    final ResponseBody response;
    try {
      response =
          await _apiClient.request(
                path: AssistantApiConfig.chat,
                method: ApiType.post,
                data: body,
                // Trình duyệt gửi kèm Accept-Language và proxy web chuyển tiếp sang BE.
                headers: {
                  'Accept': 'text/event-stream',
                  if (body['language'] case final String lang)
                    'Accept-Language': lang,
                },
                responseType: ResponseType.stream,
                cancelToken: cancelToken,
                timeout: _timeout,
                skipAuth: true,
              )
              as ResponseBody;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw const AssistantRateLimitException();
      }
      rethrow;
    }

    final type = response.headers['content-type']?.join(',') ?? '';
    if (!type.contains('text/event-stream')) {
      // Lỗi trước khi stream: proxy trả JSON `{ error, code }`.
      if (response.statusCode == 429) throw const AssistantRateLimitException();
      throw Exception('Assistant unavailable (${response.statusCode})');
    }

    final parser = SseDataParser();
    await for (final chunk in utf8.decoder.bind(response.stream)) {
      for (final data in parser.add(chunk)) {
        try {
          final json = jsonDecode(data);
          if (json is Map) yield Map<String, dynamic>.from(json);
        } catch (_) {
          // Dòng hỏng: bỏ qua (như web).
        }
      }
    }
  }
}
