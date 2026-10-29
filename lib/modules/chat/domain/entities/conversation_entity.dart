import 'package:equatable/equatable.dart';

import 'chat_message_entity.dart';

/// Một dòng ở tab Messages (`GET /user/chat-server/conversations`).
class ConversationEntity extends Equatable {
  final String channelId;
  final int partnerId;
  final String partnerName;
  final String? partnerAvatar;
  final ChatMessageType lastType;
  final String lastText;
  final int? lastSenderId;

  /// Chỉ có khi BE trả `last_message.message.voice` (Multime không đọc).
  final Duration? lastVoiceDuration;
  final String? lastSourceLang;
  final String lastTimetoken;
  final DateTime? lastAt;
  final int unreadCount;

  const ConversationEntity({
    required this.channelId,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatar,
    this.lastType = ChatMessageType.text,
    this.lastText = '',
    this.lastSenderId,
    this.lastVoiceDuration,
    this.lastSourceLang,
    this.lastTimetoken = '',
    this.lastAt,
    this.unreadCount = 0,
  });

  ConversationEntity copyWith({
    String? partnerAvatar,
    int? unreadCount,
    ChatMessageType? lastType,
    String? lastText,
    int? lastSenderId,
    String? lastTimetoken,
    DateTime? lastAt,
  }) {
    return ConversationEntity(
      channelId: channelId,
      partnerId: partnerId,
      partnerName: partnerName,
      partnerAvatar: partnerAvatar ?? this.partnerAvatar,
      lastType: lastType ?? this.lastType,
      lastText: lastText ?? this.lastText,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastVoiceDuration: lastVoiceDuration,
      lastSourceLang: lastSourceLang,
      lastTimetoken: lastTimetoken ?? this.lastTimetoken,
      lastAt: lastAt ?? this.lastAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  List<Object?> get props => [
    channelId,
    partnerId,
    partnerName,
    partnerAvatar,
    lastType,
    lastText,
    lastSenderId,
    lastVoiceDuration,
    lastSourceLang,
    lastTimetoken,
    lastAt,
    unreadCount,
  ];
}

/// Người dùng tìm được qua `GET /buyer/auth/users/search` (mở chat mới).
class ChatUserEntity extends Equatable {
  final int id;
  final String name;
  final String? avatar;

  const ChatUserEntity({required this.id, required this.name, this.avatar});

  @override
  List<Object?> get props => [id, name, avatar];
}
