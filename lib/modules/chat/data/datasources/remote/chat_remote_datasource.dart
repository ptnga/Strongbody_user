import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';

import '../../api_config/chat_api_config.dart';

/// strongbody-api cho chat. Trả `data` của envelope; `code != 0` → [ChatApiException]
/// (BE trả HTTP 200 kèm mã lỗi).
class ChatApiException implements Exception {
  final String message;
  final int? code;

  ChatApiException(this.message, {this.code});

  @override
  String toString() => message;
}

abstract class ChatRemoteDataSource {
  Future<List<Map<String, dynamic>>> getConversations(int page, int limit);
  Future<Map<String, dynamic>> getUnreadCounts();
  Future<Map<String, dynamic>> searchUsers(String query);
  Future<Map<String, dynamic>> createChannel(int partnerId);
  Future<Map<String, dynamic>> refreshToken(String channelId);
  Future<Map<String, dynamic>> personalUpdateToken(int userId);

  /// null = chưa có cài đặt ("settings not found").
  Future<Map<String, dynamic>?> getTranslationSettings(String channelId);
  Future<Map<String, dynamic>> saveTranslationSettings(
    String channelId,
    Map<String, dynamic> body,
  );
  Future<void> grantTranslationConsent();
  Future<Map<String, dynamic>> getTextTranslations(
    String channelId,
    List<String> messageIds,
  );
  Future<Map<String, dynamic>> getVoiceTranslations(List<String> messageIds);
  Future<Map<String, dynamic>> translateText(
    String channelId,
    String messageId,
    Map<String, dynamic> body,
  );
  Future<Map<String, dynamic>> sendVoice({
    required String channelId,
    required int senderId,
    required String filePath,
    required int durationSeconds,
  });
  Future<Map<String, dynamic>> markRead(String channelId, String timetoken);
  Future<Map<String, dynamic>> getConversationOffers(String channelId);
  Future<Map<String, dynamic>> getRequestOffers();
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final ApiClient _api;

  ChatRemoteDataSourceImpl(this._api);

  Future<dynamic> _call(
    String path,
    ApiType method, {
    Map<String, dynamic>? query,
    dynamic data,
    Duration? timeout,
  }) async {
    final body = await _api.request(
      path: path,
      method: method,
      queryParameters: query,
      data: data,
      timeout: timeout,
    );
    if (body is Map) {
      final code = body['code'];
      if (code is num && code != 0 && code != 200) {
        throw ChatApiException(
          body['message']?.toString() ?? 'Request failed',
          code: code.toInt(),
        );
      }
      return body['data'];
    }
    return body;
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  @override
  Future<List<Map<String, dynamic>>> getConversations(
    int page,
    int limit,
  ) async {
    final data = await _call(
      ChatApiConfig.conversations,
      ApiType.get,
      query: {'page': page, 'limit': limit},
      timeout: const Duration(seconds: 60),
    );
    final list = data is Map ? data['data'] : data;
    return list is List
        ? list.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const [];
  }

  @override
  Future<Map<String, dynamic>> getUnreadCounts() async =>
      _map(await _call(ChatApiConfig.unreadCounts, ApiType.get));

  @override
  Future<Map<String, dynamic>> searchUsers(String query) async => _map(
    await _call(
      ChatApiConfig.searchUsers,
      ApiType.get,
      query: {'query': query, 'limit': 20, 'page': 1, 'search_by': 'auto'},
    ),
  );

  @override
  Future<Map<String, dynamic>> createChannel(int partnerId) async => _map(
    await _call(
      ChatApiConfig.createChannel,
      ApiType.post,
      data: {'user_id': partnerId},
    ),
  );

  @override
  Future<Map<String, dynamic>> refreshToken(String channelId) async => _map(
    await _call(
      ChatApiConfig.refreshToken,
      ApiType.post,
      data: {'channel_id': channelId},
    ),
  );

  @override
  Future<Map<String, dynamic>> personalUpdateToken(int userId) async => _map(
    await _call(
      ChatApiConfig.personalUpdateToken,
      ApiType.get,
      query: {'user_id': userId},
    ),
  );

  @override
  Future<Map<String, dynamic>?> getTranslationSettings(String channelId) async {
    try {
      return _map(
        await _call(ChatApiConfig.translationSettings(channelId), ApiType.get),
      );
    } on ChatApiException catch (e) {
      if (e.message.toLowerCase().contains('not found')) return null;
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> saveTranslationSettings(
    String channelId,
    Map<String, dynamic> body,
  ) async => _map(
    await _call(
      ChatApiConfig.translationSettings(channelId),
      ApiType.post,
      data: body,
    ),
  );

  /// BE chặn dịch nếu chưa có consent (fail closed) — Multime `AiDataSharingConsentService`.
  @override
  Future<void> grantTranslationConsent() async {
    await _call(
      ChatApiConfig.aiConsents,
      ApiType.put,
      data: {
        'consents': [
          {'feature': 'message_translation', 'granted': true},
          {'feature': 'voice_translation', 'granted': true},
        ],
      },
    );
  }

  @override
  Future<Map<String, dynamic>> getTextTranslations(
    String channelId,
    List<String> messageIds,
  ) async => _map(
    await _call(
      ChatApiConfig.translatedMessages(channelId),
      ApiType.get,
      query: {'message_ids': messageIds.join(',')},
    ),
  );

  @override
  Future<Map<String, dynamic>> getVoiceTranslations(
    List<String> messageIds,
  ) async => _map(
    await _call(
      ChatApiConfig.voiceTranslationBatch,
      ApiType.post,
      data: {'message_ids': messageIds},
    ),
  );

  @override
  Future<Map<String, dynamic>> translateText(
    String channelId,
    String messageId,
    Map<String, dynamic> body,
  ) async => _map(
    await _call(
      ChatApiConfig.translateMessage(channelId, messageId),
      ApiType.post,
      data: body,
    ),
  );

  @override
  Future<Map<String, dynamic>> sendVoice({
    required String channelId,
    required int senderId,
    required String filePath,
    required int durationSeconds,
  }) async {
    final form = FormData.fromMap({
      'channel_id': channelId,
      'sender_id': '$senderId',
      'duration': '$durationSeconds',
      'audio_file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
        contentType: MediaType('audio', 'wav'),
      ),
    });
    return _map(
      await _call(
        ChatApiConfig.sendVoice,
        ApiType.post,
        data: form,
        timeout: const Duration(seconds: 120),
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> markRead(
    String channelId,
    String timetoken,
  ) async => _map(
    await _call(
      ChatApiConfig.markRead,
      ApiType.post,
      data: {'channel_id': channelId, 'message_timetoken': timetoken},
    ),
  );

  @override
  Future<Map<String, dynamic>> getConversationOffers(String channelId) async =>
      _map(
        await _call(
          ChatApiConfig.conversationOffers(channelId),
          ApiType.get,
          query: {
            'direction': 'received',
            'page': 1,
            'limit': 20,
            'order_by': 'created_at',
            'order_dir': 'DESC',
          },
        ),
      );

  @override
  Future<Map<String, dynamic>> getRequestOffers() async => _map(
    await _call(
      ChatApiConfig.requestOffers,
      ApiType.get,
      query: {
        'include_pending': true,
        'source': 'request,chat',
        'order_by': 'created_at',
        'order_dir': 'desc',
        'limit': 100,
      },
    ),
  );
}
