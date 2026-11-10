import '../entities/chat_message_entity.dart';
import '../entities/chat_session_entity.dart';
import '../entities/conversation_entity.dart';

/// Sự kiện realtime của một kênh.
sealed class ChatRealtimeEvent {
  const ChatRealtimeEvent();
}

final class ChatMessageArrived extends ChatRealtimeEvent {
  final ChatMessageEntity message;
  const ChatMessageArrived(this.message);
}

/// `message_edited` (vd offer đổi trạng thái).
final class ChatMessageEdited extends ChatRealtimeEvent {
  final ChatMessageEntity message;
  const ChatMessageEdited(this.message);
}

final class ChatTranslationArrived extends ChatRealtimeEvent {
  final ChatTranslation translation;

  /// Sự kiện cũ không có `recipient_user_id` — bản dịch chữ chỉ áp khi `target_lang`
  /// khớp ngôn ngữ mình chọn (web `shouldApplyTextTranslation`).
  final bool legacy;
  const ChatTranslationArrived(this.translation, {this.legacy = false});
}

/// WS đóng vì token hết hạn (4401/4403) → cần JWT mới.
/// Mất kết nối rồi nối lại → có thể đã lỡ tin, cần tải lại trang history mới nhất.
final class ChatReconnected extends ChatRealtimeEvent {
  const ChatReconnected();
}

final class ChatAccessDenied extends ChatRealtimeEvent {
  const ChatAccessDenied();
}

/// Kết nối tới `{ch}` + `{ch}_voice_translation` (luôn nghe, như web) + `{ch}_translation`
/// (chỉ khi bật dịch tự động).
abstract class ChatConnection {
  Stream<ChatRealtimeEvent> get events;

  /// [withTranslations] = nghe kênh bản dịch chữ `{ch}_translation`.
  void subscribe({required bool withTranslations});

  /// Lịch sử, mới nhất trước. [cursor] = `nextCursor` của trang trước.
  Future<ChatHistoryPage> history({String? cursor, int count = 20});

  /// Publish text → timetoken server.
  Future<String> sendText(String text, {String? senderName});

  Future<void> dispose();
}

/// Cập nhật từ `user_{me}_updates`.
sealed class ConversationUpdate {
  const ConversationUpdate();
}

final class ConversationChanged extends ConversationUpdate {
  final ConversationEntity conversation;
  const ConversationChanged(this.conversation);
}

/// `global_unread_update` — [total] = `data.total_unread_count` (null → tải lại).
final class UnreadChanged extends ConversationUpdate {
  final int? total;
  const UnreadChanged([this.total]);
}

/// Server từ chối (JWT `personal-update-token` hết hạn) → socket ngừng, cần kết nối lại.
final class UpdatesAccessDenied extends ConversationUpdate {
  const UpdatesAccessDenied();
}

abstract class ChatUpdatesConnection {
  Stream<ConversationUpdate> get updates;

  Future<void> dispose();
}
