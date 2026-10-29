import 'dart:async';
import 'dart:collection';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import 'package:strongbody_buyer/core/utils/app_logger.dart';

/// Phát lần lượt tin mới của provider khi đang mở chat (Account › Read replies aloud):
/// voice → phát file (bản dịch nếu có), text → đọc bằng TTS.
class ChatReadAloud {
  final _player = AudioPlayer();
  final _tts = FlutterTts();
  final _queue = Queue<({String? audioUrl, String? text, String? language})>();
  bool _busy = false;
  bool _disposed = false;

  void enqueue({String? audioUrl, String? text, String? language}) {
    if (_disposed) return;
    if ((audioUrl == null || audioUrl.isEmpty) &&
        (text == null || text.trim().isEmpty)) {
      return;
    }
    _queue.add((audioUrl: audioUrl, text: text, language: language));
    if (!_busy) unawaited(_drain());
  }

  Future<void> _drain() async {
    _busy = true;
    while (_queue.isNotEmpty && !_disposed) {
      final item = _queue.removeFirst();
      try {
        final url = item.audioUrl;
        if (url != null && url.isNotEmpty) {
          await _player.setUrl(url);
          await _player.play();
          await _player.processingStateStream.firstWhere(
            (s) => s == ProcessingState.completed,
          );
          await _player.stop();
        } else {
          if (item.language != null) await _tts.setLanguage(item.language!);
          await _tts.awaitSpeakCompletion(true);
          await _tts.speak(item.text!);
        }
      } catch (e) {
        AppLogger.w('Read aloud failed', e);
      }
    }
    _busy = false;
  }

  Future<void> dispose() async {
    _disposed = true;
    _queue.clear();
    try {
      await _tts.stop();
      await _player.dispose();
    } catch (_) {}
  }
}
