import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';

import '../entities/chat_message_entity.dart';
import '../entities/chat_session_entity.dart';
import '../entities/conversation_entity.dart';
import 'chat_connection.dart';

/// Chat 1:1 như Multime: strongbody-api (`/user/chat-server/*`, dịch, đánh dấu đã đọc)
/// + chat-server (WS / lịch sử / publish) qua [ChatConnection].
abstract class ChatRepository {
  Future<Either<Failure, ({List<ConversationEntity> items, bool hasMore})>>
  getConversations({required int page, int limit = 10});

  /// Tổng tin chưa đọc (`GET /user/unread-counts` → `total_unread_count`).
  Future<Either<Failure, int>> getUnreadTotal();

  Future<Either<Failure, List<ChatUserEntity>>> searchUsers(String query);

  /// Mở (hoặc tạo) kênh với [partnerId] → JWT chat-server.
  Future<Either<Failure, ChatSession>> openSession(int partnerId);

  /// JWT mới cho kênh; hỏng thì tạo lại bằng `/create` (như Multime).
  Future<Either<Failure, ChatSession>> refreshSession(ChatSession session);

  /// Kết nối realtime của kênh (WS + lịch sử + publish).
  ChatConnection connect(ChatSession session);

  /// Kênh `user_{me}_updates` — cập nhật danh sách hội thoại.
  Future<Either<Failure, ChatUpdatesConnection>> connectUpdates();

  Future<Either<Failure, ChatTranslationSettings?>> getTranslationSettings(
    String channelId,
  );

  /// Bật/tắt dịch tự động. Bật thì đồng bộ consent AI trước (`PUT /user/ai-consents`).
  Future<Either<Failure, ChatTranslationSettings>> saveTranslationSettings(
    String channelId,
    ChatTranslationSettings settings,
  );

  /// Bản dịch text đã có cho các tin (`/user/v2/conversations/{id}/messages/translated`).
  Future<Either<Failure, List<ChatTranslation>>> getTextTranslations(
    String channelId,
    List<String> messageIds,
  );

  /// Bản dịch audio đã có (`/user/vertex-ai/v2/voice-translation/batch`).
  Future<Either<Failure, List<ChatTranslation>>> getVoiceTranslations(
    List<String> messageIds,
  );

  /// Dịch một đoạn text (bản chép lời voice) — `/messages/{id}/translate`.
  Future<Either<Failure, ChatTranslation>> translateText({
    required String channelId,
    required String messageId,
    required String text,
    required String targetLanguage,
  });

  /// Gửi file ghi âm (`POST /user/chat-server/voice`); server tự publish tin voice.
  Future<Either<Failure, ChatMessageEntity>> sendVoice({
    required ChatSession session,
    required String filePath,
    required Duration duration,
  });

  Future<Either<Failure, ChatReadReceipt>> markRead(
    String channelId,
    String timetoken,
  );

  /// Offer provider gửi mình trong hội thoại (mới nhất trước).
  Future<Either<Failure, List<ChatOfferEntity>>> getConversationOffers(
    String channelId,
  );

  /// Offer [partnerId] gửi cho các request của mình — chèn vào chat với họ.
  Future<Either<Failure, List<ChatOfferEntity>>> getPartnerRequestOffers(
    int partnerId,
  );
}
