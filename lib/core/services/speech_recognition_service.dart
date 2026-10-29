import 'package:speech_to_text/speech_to_text.dart';

import '../utils/app_logger.dart';

/// Locale nhận dạng mà máy hỗ trợ (vd `vi_VN`, `en-US`).
class SpeechLocale {
  final String localeId;
  final String name;

  const SpeechLocale(this.localeId, this.name);
}

/// Bọc `speech_to_text` (nhận dạng giọng nói trên máy, có kết quả từng phần)
/// để bloc không phụ thuộc trực tiếp plugin và test được bằng fake.
abstract class SpeechRecognitionService {
  /// Xin quyền micro + nhận dạng. `false` = máy không hỗ trợ / bị từ chối.
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  });

  Future<List<SpeechLocale>> locales();

  /// Locale nhận dạng mặc định của máy (dùng khi "Auto-detect").
  Future<String?> systemLocaleId();

  /// `localeId` null = ngôn ngữ nhận dạng mặc định của máy.
  Future<void> listen({
    String? localeId,
    required void Function(String words, bool isFinal) onResult,
    required void Function(double level) onSoundLevel,
    required Duration pauseFor,
    required Duration listenFor,
  });

  Future<void> stop();

  Future<void> cancel();
}

class SpeechRecognitionServiceImpl implements SpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  void Function(String status)? _onStatus;
  void Function(String error)? _onError;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    // Plugin chỉ nhận listener ở lần initialize đầu → giữ listener hiện tại để
    // màn mở lại lần sau vẫn nhận được sự kiện.
    _onStatus = onStatus;
    _onError = onError;
    if (_initialized) return _speech.isAvailable;
    try {
      _initialized = await _speech.initialize(
        onStatus: (status) => _onStatus?.call(status),
        onError: (error) => _onError?.call(error.errorMsg),
      );
      return _initialized;
    } catch (e) {
      AppLogger.e('Speech initialize failed', e);
      return false;
    }
  }

  @override
  Future<List<SpeechLocale>> locales() async {
    try {
      final locales = await _speech.locales();
      return locales.map((l) => SpeechLocale(l.localeId, l.name)).toList();
    } catch (e) {
      AppLogger.e('Speech locales failed', e);
      return const [];
    }
  }

  @override
  Future<String?> systemLocaleId() async {
    try {
      return (await _speech.systemLocale())?.localeId;
    } catch (e) {
      AppLogger.e('Speech system locale failed', e);
      return null;
    }
  }

  @override
  Future<void> listen({
    String? localeId,
    required void Function(String words, bool isFinal) onResult,
    required void Function(double level) onSoundLevel,
    required Duration pauseFor,
    required Duration listenFor,
  }) {
    return _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        pauseFor: pauseFor,
        listenFor: listenFor,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        autoPunctuation: true,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}
