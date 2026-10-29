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
  const ChatTranslationArrived(this.translation);
}

/// WS đóng vì token hết hạn (4401/4403) → cần JWT mới.
final class ChatAccessDenied extends ChatRealtimeEvent {
  const ChatAccessDenied();
}

/// Kết nối tới `{ch}` (+ `{ch}_translation`, `{ch}_voice_translation` khi bật dịch).
abstract class ChatConnection {
  Stream<ChatRealtimeEvent> get events;

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

/// `global_unread_update` → tải lại tổng chưa đọc.
final class UnreadChanged extends ConversationUpdate {
  const UnreadChanged();
}

abstract class ChatUpdatesConnection {
  Stream<ConversationUpdate> get updates;

  Future<void> dispose();
}
