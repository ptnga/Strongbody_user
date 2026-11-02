import 'package:strongbody_chat_client/strongbody_chat_client.dart';

import 'package:strongbody_buyer/core/config/environment.dart';
import 'package:strongbody_buyer/core/utils/app_logger.dart';
import 'package:strongbody_buyer/modules/chat/domain/entities/chat_session_entity.dart';

/// Gửi card item + lời nhắn vào kênh DM — web `useSendInquiry` dựng client
/// chat-server tạm cho đúng lần publish này (card trước, text sau).
class MarketChatPublisher {
  Future<void> publishInquiry({
    required ChatSession session,
    required String kind,
    required Map<String, dynamic> cardData,
    required String content,
    Future<void> Function()? afterCard,
  }) async {
    final pubnub = ChatPubNub(
      endpoint: AppConfig.chatServerUrl,
      tenant: AppConfig.chatServerTenant,
      uuid: '${session.myUserId}',
      token: session.token,
    );
    try {
      await pubnub.publish(
        channel: session.channelId,
        message: {'type': kind, kind: cardData, 'uuid': session.myUserId},
      );
      await afterCard?.call();
      await pubnub.publish(
        channel: session.channelId,
        message: {'type': 'text', 'content': content, 'uuid': session.myUserId},
      );
    } finally {
      try {
        await pubnub.disconnect();
      } catch (e) {
        AppLogger.w('Inquiry chat disconnect failed', e);
      }
    }
  }
}
