import 'package:equatable/equatable.dart';

import 'chat_message_entity.dart';

/// Người còn lại trong hội thoại 1:1.
class ChatPartner extends Equatable {
  final int id;
  final String name;
  final String? avatar;

  const ChatPartner({required this.id, required this.name, this.avatar});

  @override
  List<Object?> get props => [id, name, avatar];
}

/// Kênh chat + JWT của chat-server (`POST /user/chat-server/create` / `refresh-token`).
class ChatSession extends Equatable {
  /// Id kênh do server trả — coi là chuỗi mờ, không tự ghép.
  final String channelId;
  final String token;
  final int myUserId;
  final ChatPartner partner;

  const ChatSession({
    required this.channelId,
    required this.token,
    required this.myUserId,
    required this.partner,
  });

  ChatSession withToken(String token) => ChatSession(
    channelId: channelId,
    token: token,
    myUserId: myUserId,
    partner: partner,
  );

  @override
  List<Object?> get props => [channelId, token, myUserId, partner];
}

/// Cài đặt dịch của hội thoại (`/user/conversations/{id}/translation/settings`).
/// [targetLanguage] = ngôn ngữ MÌNH muốn đọc.
class ChatTranslationSettings extends Equatable {
  final bool autoTranslate;
  final String targetLanguage;

  const ChatTranslationSettings({
    required this.autoTranslate,
    required this.targetLanguage,
  });

  @override
  List<Object?> get props => [autoTranslate, targetLanguage];
}

/// Kết quả `POST /user/mark-read-and-status`.
class ChatReadReceipt extends Equatable {
  final String timetoken;
  final int senderId;

  /// Có người khác mình đã đọc tới [timetoken].
  final bool readByPartner;

  const ChatReadReceipt({
    required this.timetoken,
    required this.senderId,
    required this.readByPartner,
  });

  @override
  List<Object?> get props => [timetoken, senderId, readByPartner];
}

/// Một trang lịch sử (mới nhất trước). [nextCursor] null = hết.
class ChatHistoryPage extends Equatable {
  final List<ChatMessageEntity> messages;
  final String? nextCursor;

  const ChatHistoryPage({required this.messages, this.nextCursor});

  @override
  List<Object?> get props => [messages, nextCursor];
}
