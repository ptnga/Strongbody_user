import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../utils/app_logger.dart';

/// File voice note đã ghi + thời lượng thật (không tính lúc tạm dừng).
class VoiceNote {
  final String path;
  final Duration duration;

  const VoiceNote(this.path, this.duration);
}

/// Ghi voice note (m4a) song song với nhận dạng giọng nói trên máy.
///
/// Hai thứ cùng dùng micro: iOS chạy được khi `record` KHÔNG tự quản lý audio
/// session (để `speech_to_text` giữ session); Android có thể chỉ một bên nhận
/// tiếng → mọi lỗi ở đây đều bỏ qua, request vẫn đi tiếp chỉ là không có voice note.
abstract class VoiceNoteRecorder {
  /// `false` = không ghi được (bị chặn / máy không cho ghi song song).
  Future<bool> start();

  Future<void> pause();

  Future<void> resume();

  /// Dừng và trả file; null nếu chưa ghi hoặc file quá nhỏ (không có tiếng).
  Future<VoiceNote?> stop();

  /// Huỷ và xoá file đang ghi.
  Future<void> discard();
}

class VoiceNoteRecorderImpl implements VoiceNoteRecorder {
  /// Nhỏ hơn mức này coi như file rỗng (giống rule `voice` của Multime: ≥ 100 bytes).
  static const _minBytes = 100;

  AudioRecorder? _recorder;
  final Stopwatch _stopwatch = Stopwatch();
  String? _path;

  @override
  Future<bool> start() async {
    await discard();
    try {
      final recorder = AudioRecorder();
      _recorder = recorder;
      if (Platform.isIOS) await recorder.ios?.manageAudioSession(false);
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      _path = path;
      _stopwatch
        ..reset()
        ..start();
      return true;
    } catch (e) {
      AppLogger.w('Voice note recording unavailable', e);
      await _disposeRecorder();
      return false;
    }
  }

  @override
  Future<void> pause() async {
    if (_path == null) return;
    _stopwatch.stop();
    try {
      await _recorder?.pause();
    } catch (e) {
      AppLogger.w('Voice note pause failed', e);
    }
  }

  @override
  Future<void> resume() async {
    if (_path == null) return;
    try {
      await _recorder?.resume();
      _stopwatch.start();
    } catch (e) {
      AppLogger.w('Voice note resume failed', e);
    }
  }

  @override
  Future<VoiceNote?> stop() async {
    final path = _path;
    if (path == null) return null;
    _stopwatch.stop();
    try {
      final saved = await _recorder?.stop() ?? path;
      await _disposeRecorder();
      _path = null;
      final file = File(saved);
      if (!await file.exists() || await file.length() < _minBytes) return null;
      return VoiceNote(saved, _stopwatch.elapsed);
    } catch (e) {
      AppLogger.w('Voice note stop failed', e);
      await _disposeRecorder();
      _path = null;
      return null;
    }
  }

  @override
  Future<void> discard() async {
    final path = _path;
    _path = null;
    _stopwatch
      ..stop()
      ..reset();
    try {
      await _recorder?.cancel();
    } catch (_) {}
    await _disposeRecorder();
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<void> _disposeRecorder() async {
    final recorder = _recorder;
    _recorder = null;
    try {
      await recorder?.dispose();
    } catch (_) {}
  }
}
