part of 'voice_request_bloc.dart';

sealed class VoiceRequestEvent extends Equatable {
  const VoiceRequestEvent();

  @override
  List<Object?> get props => [];
}

/// Mở màn: xin quyền, tải ngôn ngữ, bắt đầu nghe.
final class VoiceRequestStarted extends VoiceRequestEvent {
  /// false = chỉ cần chữ ("refine by voice"), không ghi voice note.
  final bool recordVoiceNote;

  /// Ngôn ngữ nói chọn sẵn ở Account (null = Auto-detect).
  final String? initialLanguage;

  const VoiceRequestStarted({
    this.recordVoiceNote = true,
    this.initialLanguage,
  });

  @override
  List<Object?> get props => [recordVoiceNote, initialLanguage];
}

/// Nút pause: đang nghe → tạm dừng; đang dừng / đã xong → nghe tiếp (nối chữ).
final class VoiceRequestPauseToggled extends VoiceRequestEvent {
  const VoiceRequestPauseToggled();
}

/// Nút ↶: xoá transcript, nói lại từ đầu.
final class VoiceRequestRestarted extends VoiceRequestEvent {
  const VoiceRequestRestarted();
}

/// Chọn ngôn ngữ nói; `code` null = Auto-detect (ngôn ngữ mặc định của máy).
final class VoiceRequestLanguageSelected extends VoiceRequestEvent {
  final String? code;

  const VoiceRequestLanguageSelected(this.code);

  @override
  List<Object?> get props => [code];
}

/// Người dùng sửa tay transcript (khi không nghe).
final class VoiceRequestTextEdited extends VoiceRequestEvent {
  final String text;

  const VoiceRequestTextEdited(this.text);

  @override
  List<Object?> get props => [text];
}

/// Nút ✓: dừng nghe, chốt transcript.
final class VoiceRequestSubmitted extends VoiceRequestEvent {
  const VoiceRequestSubmitted();
}

/// "Try again" ở màn lỗi: nghe lại từ đầu (khởi tạo lại nếu trước đó không bật được micro).
/// Cũng gửi khi quay lại app từ Cài đặt.
final class VoiceRequestRetried extends VoiceRequestEvent {
  const VoiceRequestRetried();
}

/// UI đã xử lý kết quả một lần.
final class VoiceRequestOneShotConsumed extends VoiceRequestEvent {
  const VoiceRequestOneShotConsumed();
}

final class _VoiceRequestResultReceived extends VoiceRequestEvent {
  final String words;
  final bool isFinal;

  const _VoiceRequestResultReceived(this.words, this.isFinal);

  @override
  List<Object?> get props => [words, isFinal];
}

final class _VoiceRequestStatusChanged extends VoiceRequestEvent {
  final String status;

  const _VoiceRequestStatusChanged(this.status);

  @override
  List<Object?> get props => [status];
}

final class _VoiceRequestErrorReceived extends VoiceRequestEvent {
  final String error;

  const _VoiceRequestErrorReceived(this.error);

  @override
  List<Object?> get props => [error];
}

final class _VoiceRequestSoundLevelChanged extends VoiceRequestEvent {
  final double level;

  const _VoiceRequestSoundLevelChanged(this.level);

  @override
  List<Object?> get props => [level];
}
