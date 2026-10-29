import 'dart:convert';

import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/chat_session_entity.dart';
import '../../domain/entities/chat_timetoken.dart';
import '../../domain/entities/conversation_entity.dart';

/// JSON của strongbody-api / chat-server → entity (key theo DTO của Multime).
class ChatMapper {
  const ChatMapper._();

  static Map<String, dynamic> _map(Object? v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    // Một số payload cũ publish message dạng chuỗi JSON.
    if (v is String && v.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        return const {};
      }
    }
    return const {};
  }

  static int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
  static double? _double(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty || s == 'null' ? null : s;
  }

  static String _name(Map<String, dynamic> user) =>
      _str(user['nickname']) ??
      _str(user['name']) ??
      [
        _str(user['first_name']),
        _str(user['last_name']),
      ].whereType<String>().join(' ');

  /// `data` của `/user/chat-server/create` hoặc `/refresh-token`.
  static ChatSession? session(
    Map<String, dynamic> data, {
    required int myUserId,
    ChatPartner? fallbackPartner,
  }) {
    final channelId = _str(data['channel_id']);
    final token = _str(data['token']);
    if (channelId == null || token == null) return null;
    final partner = _map(data['partner']);
    final partnerId = _int(partner['user_id']) ?? fallbackPartner?.id;
    if (partnerId == null) return null;
    final name = _name(partner);
    return ChatSession(
      channelId: channelId,
      token: token,
      myUserId: _int(data['user_id']) ?? myUserId,
      partner: ChatPartner(
        id: partnerId,
        name: name.isNotEmpty ? name : (fallbackPartner?.name ?? ''),
        avatar: _str(partner['avatar']) ?? fallbackPartner?.avatar,
      ),
    );
  }

  /// Một dòng `GET /user/chat-server/conversations` (`last_message.message.*` lồng nhau).
  static ConversationEntity? conversation(Map<String, dynamic> json) {
    final channelId = _str(json['channel_id']);
    if (channelId == null) return null;
    final partner = _map(json['partner']);
    final last = _map(json['last_message']);
    final info = _map(last['user_info']);
    final partnerId = _int(partner['user_id']) ?? _int(info['user_id']);
    if (partnerId == null) return null;
    final message = _map(last['message']);
    final voice = _map(message['voice']);
    final timetoken = _str(last['timetoken']) ?? '';
    final name = _name(partner);
    return ConversationEntity(
      channelId: channelId,
      partnerId: partnerId,
      partnerName: name.isNotEmpty ? name : _name(info),
      partnerAvatar: _str(partner['avatar']) ?? _str(info['avatar']),
      lastType: ChatMessageType.fromApi(_str(message['type'])),
      lastText: _str(message['content']) ?? '',
      lastSenderId: _int(last['sender_id']),
      lastVoiceDuration: _duration(voice['duration']),
      lastSourceLang: _str(voice['source_lang']),
      lastTimetoken: timetoken,
      lastAt: timetoken.isEmpty ? null : ChatTimetoken.toDateTime(timetoken),
      unreadCount: _int(json['unread_count']) ?? 0,
    );
  }

  /// `channel_list_update` trên `user_{me}_updates` (`last_message.*` phẳng).
  static ConversationEntity? conversationUpdate(Map<String, dynamic> data) {
    final channelId = _str(data['channel_id']);
    if (channelId == null) return null;
    final partner = _map(data['partner']);
    final partnerId = _int(partner['user_id']);
    if (partnerId == null) return null;
    final last = _map(data['last_message']);
    final timetoken = _str(last['timetoken']) ?? '';
    return ConversationEntity(
      channelId: channelId,
      partnerId: partnerId,
      partnerName: _name(partner),
      partnerAvatar: _str(partner['avatar']),
      lastType: ChatMessageType.fromApi(_str(last['type'])),
      lastText: _str(last['content']) ?? '',
      lastSenderId: _int(last['sender_id']),
      lastTimetoken: timetoken,
      lastAt: timetoken.isEmpty ? null : ChatTimetoken.toDateTime(timetoken),
      unreadCount: _int(data['unread_count']) ?? 0,
    );
  }

  static Duration? _duration(Object? seconds) {
    final value = _double(seconds);
    return value == null || value <= 0
        ? null
        : Duration(milliseconds: (value * 1000).round());
  }

  /// Payload tin (lịch sử hoặc WS). null = loại không hiển thị (`read`, `_action`,
  /// tin tự động của chính mình…).
  static ChatMessageEntity? message({
    required String timetoken,
    required String publisher,
    required Object? payload,
    required int myUserId,
  }) {
    final json = _map(payload);
    if (json.isEmpty) return null;
    final rawType = _str(json['type']);
    if (rawType == 'read' || rawType == '_action' || rawType == 'typing') {
      return null;
    }
    final senderId = _int(json['uuid']) ?? _int(publisher) ?? 0;
    final metadata = _map(json['metadata']);
    if (senderId == myUserId &&
        metadata['is_auto_message'] == true &&
        metadata['translation_bot'] != true) {
      return null;
    }
    final type = ChatMessageType.fromApi(rawType);
    final voiceJson = _map(json['voice']);
    final voiceUrl = _str(voiceJson['audio_url'] ?? voiceJson['audioUrl']);
    final offerJson = _map(json['offer']);
    final fileJson = _map(json['file']);
    return ChatMessageEntity(
      id: timetoken,
      senderId: senderId,
      type: type,
      createdAt: ChatTimetoken.toDateTime(timetoken),
      text: _str(json['content']) ?? '',
      voice: type == ChatMessageType.voice && voiceUrl != null
          ? ChatVoice(
              url: voiceUrl,
              gcsPath: _str(voiceJson['gcs_path'] ?? voiceJson['gcsPath']),
              sourceLang: _str(voiceJson['source_lang']),
              transcript: _str(voiceJson['text']),
              duration: _duration(voiceJson['duration']),
            )
          : null,
      offer: offerJson.isEmpty ? null : offer(offerJson),
      fileName: _str(fileJson['name']),
    );
  }

  static ChatOfferEntity? offer(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id == null) return null;
    final request = _map(json['Request'] ?? json['request']);
    DateTime? date(Object? v) => DateTime.tryParse(_str(v) ?? '')?.toLocal();
    return ChatOfferEntity(
      id: id,
      title: _str(json['title']) ?? '',
      description: _str(json['description']) ?? '',
      price: _double(json['price']),
      status: _str(json['status']) ?? 'pending',
      paymentStatus:
          _str(json['payment_status'] ?? json['paymentStatus']) ?? '',
      orderNo: _str(json['order_no'] ?? json['orderNo']),
      createdAt: date(json['created_at'] ?? json['createdAt']),
      sellerId: _int(
        json['seller_id'] ?? json['sellerId'] ?? _map(json['Seller'])['id'],
      ),
      requestId: _int(json['request_id'] ?? json['requestId'] ?? request['id']),
      scheduledAt: date(request['deadline']),
      deliveryType: _str(request['delivery_type']),
    );
  }

  /// `data.list` của `/buyer/offer/sent-offers-by-my-requests` → offer của [sellerId].
  static List<ChatOfferEntity> requestOffers(
    Map<String, dynamic> data, {
    required int sellerId,
  }) {
    final list = data['list'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => offer(_map(e)))
        .nonNulls
        .where((o) => o.sellerId == sellerId && o.requestId != null)
        .toList();
  }

  /// `data.list` của `/user/offer/conversation/{channel_id}`.
  static List<ChatOfferEntity> conversationOffers(Map<String, dynamic> data) {
    final list = data['list'];
    return list is List
        ? list.whereType<Map>().map((e) => offer(_map(e))).nonNulls.toList()
        : const [];
  }

  /// Sự kiện `{ch}_translation` / item `/messages/translated` / `/translate`.
  static ChatTranslation? textTranslation(Map<String, dynamic> json) {
    final id = _str(
      json['message_id'] ?? json['message_timetoken'] ?? json['timetoken'],
    );
    final text = _str(json['translated_text'] ?? json['translated_message']);
    if (id == null || text == null) return null;
    return ChatTranslation(
      messageId: id,
      text: text,
      sourceLang: _str(json['source_lang']),
      targetLang: _str(json['target_lang']),
    );
  }

  /// Sự kiện `{ch}_voice_translation` / item `/voice-translation/batch`.
  static ChatTranslation? voiceTranslation(Map<String, dynamic> json) {
    final id = _str(json['message_timetoken'] ?? json['message_id']);
    final url = _str(json['translated_url']);
    if (id == null || url == null) return null;
    return ChatTranslation(
      messageId: id,
      audioUrl: url,
      sourceLang: _str(json['source_lang']),
      targetLang: _str(json['target_lang']),
    );
  }

  static ChatTranslationSettings settings(
    Map<String, dynamic> json, {
    required String fallbackLanguage,
  }) => ChatTranslationSettings(
    autoTranslate: json['auto_translate'] == true,
    targetLanguage: _str(json['target_language']) ?? fallbackLanguage,
  );

  static ChatReadReceipt? readReceipt(
    Map<String, dynamic> json, {
    required int myUserId,
  }) {
    final timetoken = _str(json['timetoken']);
    if (timetoken == null) return null;
    final readBy = json['read_by'];
    return ChatReadReceipt(
      timetoken: timetoken,
      senderId: _int(json['sender_id']) ?? 0,
      readByPartner:
          readBy is List &&
          readBy.whereType<Map>().any((r) => _int(r['user_id']) != myUserId),
    );
  }

  /// `data.users[]` của `/buyer/auth/users/search`.
  static List<ChatUserEntity> users(Map<String, dynamic> data) {
    final list = data['users'];
    if (list is! List) return const [];
    return [
      for (final raw in list.whereType<Map>())
        if (_int(raw['user_id'] ?? raw['id']) case final id?)
          ChatUserEntity(
            id: id,
            name: _name(Map<String, dynamic>.from(raw)),
            avatar: _str(raw['avatar']),
          ),
    ];
  }
}
