import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:strongbody_buyer/core/services/voice_note_recorder.dart';
import 'package:strongbody_buyer/core/utils/app_logger.dart';

/// Ghi voice chat: WAV PCM 16 kHz mono (đúng định dạng Multime gửi `/user/chat-server/voice`).
abstract class ChatVoiceRecorder {
  /// Tối đa như Multime.
  static const maxDuration = Duration(seconds: 90);

  Future<bool> start();

  /// null = chưa ghi / quá ngắn.
  Future<VoiceNote?> stop();

  Future<void> cancel();
}

class ChatVoiceRecorderImpl implements ChatVoiceRecorder {
  AudioRecorder? _recorder;
  String? _path;
  final _stopwatch = Stopwatch();

  @override
  Future<bool> start() async {
    await cancel();
    try {
      final recorder = AudioRecorder();
      if (!await recorder.hasPermission()) {
        await recorder.dispose();
        return false;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      _recorder = recorder;
      _path = path;
      _stopwatch
        ..reset()
        ..start();
      return true;
    } catch (e) {
      AppLogger.w('Chat voice recording failed', e);
      await cancel();
      return false;
    }
  }

  @override
  Future<VoiceNote?> stop() async {
    final path = _path;
    if (path == null) return null;
    _stopwatch.stop();
    try {
      final saved = await _recorder?.stop() ?? path;
      await _dispose();
      _path = null;
      final file = File(saved);
      // < 1 s hoặc file rỗng → bỏ.
      if (_stopwatch.elapsed < const Duration(seconds: 1) ||
          !await file.exists() ||
          await file.length() < 1000) {
        await _delete(saved);
        return null;
      }
      return VoiceNote(saved, _stopwatch.elapsed);
    } catch (e) {
      AppLogger.w('Chat voice stop failed', e);
      await _dispose();
      _path = null;
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    final path = _path;
    _path = null;
    _stopwatch
      ..stop()
      ..reset();
    try {
      await _recorder?.cancel();
    } catch (_) {}
    await _dispose();
    if (path != null) await _delete(path);
  }

  Future<void> _dispose() async {
    final recorder = _recorder;
    _recorder = null;
    try {
      await recorder?.dispose();
    } catch (_) {}
  }

  static Future<void> _delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
