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

  /// Partner của kênh 1:1 `{id1}_{id2}_one_to_one` = id khác mình (web
  /// `getPartnerIdFromChannel`); `last_message.user_info` là NGƯỜI GỬI cuối — có thể là mình.
  static int? partnerIdFromChannel(String channelId, int myUserId) {
    final match = RegExp(r'^(\d+)_(\d+)_').firstMatch(channelId);
    if (match == null) return null;
    final a = int.parse(match.group(1)!);
    final b = int.parse(match.group(2)!);
    return a != myUserId ? a : b;
  }

  static bool _isGroup(Map<String, dynamic> json) =>
      _str(json['channel_type']) == 'group';

  /// Một dòng `GET /user/chat-server/conversations` (`last_message.message.*` lồng nhau).
  /// Partner: `partner` → id trong channel id → người gửi cuối (khi không phải mình) —
  /// web `resolvePartnerId` / `getPartnerDisplayName(partner) || user_info.name`.
  static ConversationEntity? conversation(
    Map<String, dynamic> json, {
    int? myUserId,
  }) {
    final channelId = _str(json['channel_id']);
    if (channelId == null || _isGroup(json)) return null;
    final partner = _map(json['partner']);
    final last = _map(json['last_message']);
    final info = _map(last['user_info']);
    final infoId = _int(info['user_id']);
    final infoIsPartner = infoId != null && infoId != myUserId;
    final partnerId =
        _int(partner['user_id']) ??
        (myUserId == null ? null : partnerIdFromChannel(channelId, myUserId)) ??
        (infoIsPartner ? infoId : null);
    if (partnerId == null) return null;
    final message = _map(last['message']);
    final voice = _map(message['voice']);
    final timetoken = _str(last['timetoken']) ?? '';
    final name = _name(partner);
    return ConversationEntity(
      channelId: channelId,
      partnerId: partnerId,
      partnerName: name.isNotEmpty
          ? name
          : (infoId == partnerId ? _name(info) : ''),
      partnerAvatar:
          _str(partner['avatar']) ??
          (infoId == partnerId ? _str(info['avatar']) : null),
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

  /// `data` của `GET /user/chat-server/conversations` (web `PubnubContext`): còn trang
  /// sau khi `current_page < last_page | total_page | ceil(total / limit)`.
  static bool conversationsHasMore(
    Map<String, dynamic> data, {
    required int page,
    required int limit,
    required int received,
  }) {
    final current = _int(data['current_page']) ?? page;
    final totalPages =
        _int(data['last_page']) ??
        _int(data['total_page']) ??
        switch (_int(data['total'])) {
          final total? => (total / limit).ceil(),
          null => null,
        };
    if (totalPages == null) return received >= limit;
    return current < totalPages;
  }

  /// `channel_list_update` trên `user_{me}_updates` (`last_message.*` phẳng). Sự kiện
  /// thường không kèm `partner` → id lấy từ channel id / người gửi cuối, tên từ
  /// `sender_name` khi người gửi là partner (web `PubnubContext`). Bỏ sự kiện có
  /// `source` và kênh nhóm (web chỉ xử lý `!data.source`; app chưa có nhóm).
  static ConversationEntity? conversationUpdate(
    Map<String, dynamic> data, {
    int? myUserId,
  }) {
    final channelId = _str(data['channel_id']);
    if (channelId == null || _isGroup(data)) return null;
    if (_str(data['source']) != null) return null;
    final partner = _map(data['partner']);
    final last = _map(data['last_message']);
    final senderId = _int(last['sender_id']);
    final senderIsPartner = senderId != null && senderId != myUserId;
    final partnerId =
        _int(partner['user_id']) ??
        (myUserId == null ? null : partnerIdFromChannel(channelId, myUserId)) ??
        (senderIsPartner ? senderId : null);
    if (partnerId == null) return null;
    final timetoken = _str(last['timetoken']) ?? '';
    final name = _name(partner);
    return ConversationEntity(
      channelId: channelId,
      partnerId: partnerId,
      partnerName: name.isNotEmpty
          ? name
          : (senderId == partnerId ? _str(last['sender_name']) ?? '' : ''),
      partnerAvatar: _str(partner['avatar']),
      lastType: ChatMessageType.fromApi(_str(last['type'])),
      lastText: _str(last['content']) ?? '',
      lastSenderId: senderId,
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
  /// `system_event` (nhóm), tin tự động của chính mình…).
  static ChatMessageEntity? message({
    required String timetoken,
    required String publisher,
    required Object? payload,
    required int myUserId,
  }) {
    final json = _map(payload);
    if (json.isEmpty) return null;
    final rawType = _str(json['type']);
    if (rawType == 'read' ||
        rawType == '_action' ||
        rawType == 'typing' ||
        rawType == 'system_event') {
      return null;
    }
    final senderId = _int(json['uuid']) ?? _int(publisher) ?? 0;
    final metadata = _map(json['metadata']);
    // Web `shouldIncludeMessage`: bỏ tin tự động (`is_auto_message`) của chính mình.
    final isAuto =
        json['is_auto_message'] == true || metadata['is_auto_message'] == true;
    if (senderId == myUserId && isAuto && metadata['translation_bot'] != true) {
      return null;
    }
    var type = ChatMessageType.fromApi(rawType);
    final voiceJson = _map(json['voice']);
    final voiceUrl = _str(voiceJson['audio_url'] ?? voiceJson['audioUrl']);
    final translatedUrl = _str(
      voiceJson['translation_audio_url'] ?? voiceJson['translated_url'],
    );
    final offerJson = _map(json['offer']);
    final fileJson = _map(json['file']);
    // Tin file của chat-server lồng loại thật trong `message.message.type`.
    final nested = _str(_map(json['message'])['type']);
    if (fileJson.isNotEmpty && (nested == 'image' || nested == 'file')) {
      type = ChatMessageType.fromApi(nested);
    }
    // Web `isPublicOfferMessage`: `offer.type == 'offer'` = bài đăng public offer (chỉ
    // trích dẫn, không có thanh toán); offer riêng tạo trong chat là `service`.
    final isPublicOffer =
        type == ChatMessageType.offer && _str(offerJson['type']) == 'offer';
    final card = switch (type) {
      ChatMessageType.request => _card(ChatCardKind.request, json['request']),
      ChatMessageType.service => _card(ChatCardKind.service, json['service']),
      ChatMessageType.product => _card(ChatCardKind.product, json['product']),
      ChatMessageType.offer when isPublicOffer => _card(
        ChatCardKind.publicOffer,
        offerJson,
      ),
      _ => null,
    };
    return ChatMessageEntity(
      id: timetoken,
      senderId: senderId,
      type: type,
      createdAt: ChatTimetoken.toDateTime(timetoken),
      text: _str(json['content']) ?? '',
      voice:
          type == ChatMessageType.voice && (voiceUrl ?? translatedUrl) != null
          ? ChatVoice(
              url: voiceUrl ?? translatedUrl!,
              gcsPath: _str(voiceJson['gcs_path'] ?? voiceJson['gcsPath']),
              sourceLang: _str(
                voiceJson['source_lang'] ?? voiceJson['detected_lang'],
              ),
              transcript: _str(voiceJson['text']),
              duration: _duration(voiceJson['duration']),
              translatedUrl: voiceUrl == null ? null : translatedUrl,
              translatedText: _str(voiceJson['translated_text']),
              translatedLang: _str(voiceJson['target_lang']),
            )
          : null,
      offer: offerJson.isEmpty || isPublicOffer ? null : offer(offerJson),
      card: card,
      fileName: _str(fileJson['name']),
    );
  }

  static String? _firstImage(Object? v) {
    if (v is List) {
      for (final item in v) {
        final s = item is Map ? _str(item['url']) : _str(item);
        if (s != null) return s;
      }
      return null;
    }
    return _str(v);
  }

  /// `message.request` / `.service` / `.product` / `.offer` (public offer) — web
  /// `RequestMessageData` / `ServiceMessageData` / `ProductMessageData` / `OfferMessageData`.
  static ChatCardEntity? _card(ChatCardKind kind, Object? raw) {
    final json = _map(raw);
    if (json.isEmpty) return null;
    return ChatCardEntity(
      kind: kind,
      id: _int(json['id']),
      title: _str(json['title']) ?? '',
      description: _str(json['description']) ?? '',
      image: _firstImage(json['image']) ?? _firstImage(json['cover_image']),
      price: _double(json['price']),
      priceMax: _str(json['pricing_mode']) == 'consultation'
          ? _double(json['price_max'])
          : null,
      currency: _str(json['currency']),
      priceText: _str(json['price_text']),
      priceUnit: _str(json['price_unit']),
      budgetMin: _double(json['budget_min']),
      budgetMax: _double(json['budget_max']),
      budgetCurrency: _str(json['budget_currency']),
      budgetText: _str(json['budget']),
      categoryName: _str(json['categoryName'] ?? json['category_name']),
      country: _str(json['country']),
      slug: _str(json['slug']),
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

  /// Sự kiện `{ch}_voice_translation` / item `/v3/voice-translation/batch-for-user`.
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
