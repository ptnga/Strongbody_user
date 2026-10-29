part of 'chat_bloc.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// Mở kênh với partner, tải lịch sử, cài đặt dịch, offer, rồi nghe WS.
final class ChatStarted extends ChatEvent {
  const ChatStarted();
}

/// Kéo lên đầu danh sách → tải tin cũ hơn.
final class ChatOlderRequested extends ChatEvent {
  const ChatOlderRequested();
}

final class ChatTextSent extends ChatEvent {
  final String text;

  const ChatTextSent(this.text);

  @override
  List<Object?> get props => [text];
}

final class ChatRecordStarted extends ChatEvent {
  const ChatRecordStarted();
}

final class ChatRecordCancelled extends ChatEvent {
  const ChatRecordCancelled();
}

/// Dừng ghi và gửi voice.
final class ChatRecordFinished extends ChatEvent {
  const ChatRecordFinished();
}

/// Nút "Translate on/off" (đã xác nhận consent ở UI khi bật).
final class ChatTranslateToggled extends ChatEvent {
  const ChatTranslateToggled();
}

/// "show original" / "show translation" của một tin.
final class ChatOriginalToggled extends ChatEvent {
  final String messageId;

  const ChatOriginalToggled(this.messageId);

  @override
  List<Object?> get props => [messageId];
}

final class _ChatRealtimeReceived extends ChatEvent {
  final ChatRealtimeEvent event;

  const _ChatRealtimeReceived(this.event);

  @override
  List<Object?> get props => [event];
}

final class _ChatRecordTicked extends ChatEvent {
  const _ChatRecordTicked();
}

final class _ChatMarkReadDue extends ChatEvent {
  const _ChatMarkReadDue();
}
