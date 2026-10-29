part of 'voice_request_bloc.dart';

/// initializing: đang bật micro; listening: đang nghe; paused: người dùng tạm dừng;
/// done: tự dừng sau khoảng im lặng ("Got it"); unavailable: máy không hỗ trợ / bị chặn quyền.
enum VoiceRequestStatus { initializing, listening, paused, done, unavailable }

/// Lỗi hiện thành màn riêng (không snackbar): không nghe được gì / micro bị tắt quyền /
/// máy không nhận giọng nói được.
enum VoiceRequestProblem { noSpeech, micOff, unavailable }

/// Kết quả khi bấm ✓: transcript + voice note (nếu ghi được) + ngôn ngữ đã nói.
class VoiceRequestResult extends Equatable {
  final String text;
  final String? voicePath;
  final Duration? voiceDuration;

  /// Mã ngôn ngữ của app (vd `en`, `vi`); null = không xác định.
  final String? languageCode;

  const VoiceRequestResult({
    required this.text,
    this.voicePath,
    this.voiceDuration,
    this.languageCode,
  });

  @override
  List<Object?> get props => [text, voicePath, voiceDuration, languageCode];
}

class VoiceRequestState extends Equatable {
  final VoiceRequestStatus status;

  /// Phần đã chốt (các lượt nghe trước / người dùng sửa tay).
  final String committedText;

  /// Phần đang nghe ở lượt hiện tại (kết quả từng phần).
  final String partialText;

  /// null = Auto-detect.
  final String? languageCode;
  final List<VoiceLanguageOption> languages;

  /// Âm lượng đã chuẩn hoá 0–1 cho waveform.
  final double level;

  /// Kết quả khi bấm ✓ (một lần) → UI chuyển sang "Here's what I heard".
  final VoiceRequestResult? result;
  final VoiceRequestProblem? problem;

  const VoiceRequestState({
    this.status = VoiceRequestStatus.initializing,
    this.committedText = '',
    this.partialText = '',
    this.languageCode,
    this.languages = const [],
    this.level = 0,
    this.result,
    this.problem,
  });

  String get transcript => _join(committedText, partialText);

  bool get isListening => status == VoiceRequestStatus.listening;

  VoiceLanguageOption? get selectedLanguage {
    for (final option in languages) {
      if (option.code == languageCode) return option;
    }
    return null;
  }

  static String _join(String a, String b) {
    final left = a.trim();
    final right = b.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    return '$left $right';
  }

  VoiceRequestState copyWith({
    VoiceRequestStatus? status,
    String? committedText,
    String? partialText,
    String? languageCode,
    bool clearLanguage = false,
    List<VoiceLanguageOption>? languages,
    double? level,
    VoiceRequestResult? result,
    VoiceRequestProblem? problem,
    bool clearProblem = false,
    bool clearOneShot = false,
  }) {
    return VoiceRequestState(
      status: status ?? this.status,
      committedText: committedText ?? this.committedText,
      partialText: partialText ?? this.partialText,
      languageCode: clearLanguage ? null : (languageCode ?? this.languageCode),
      languages: languages ?? this.languages,
      level: level ?? this.level,
      result: clearOneShot ? null : (result ?? this.result),
      problem: clearProblem ? null : (problem ?? this.problem),
    );
  }

  @override
  List<Object?> get props => [
    status,
    committedText,
    partialText,
    languageCode,
    languages,
    level,
    result,
    problem,
  ];
}
