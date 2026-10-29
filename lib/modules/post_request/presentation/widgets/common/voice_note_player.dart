import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:just_audio/just_audio.dart';

import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/utils/app_logger.dart';

import '../../request_formatters.dart';

/// Phát voice note (file trên máy hoặc URL): nút tròn play/pause, sóng âm tô dần theo tiến độ, thời lượng.
class VoiceNotePlayer extends StatefulWidget {
  /// Đường dẫn file hoặc URL `http(s)`.
  final String path;
  final Duration? duration;

  /// Trên nền tối (bong bóng chat của mình): nút trắng, sóng trắng.
  final bool onDark;

  const VoiceNotePlayer({
    super.key,
    required this.path,
    this.duration,
    this.onDark = false,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  static const _bars = 34;
  static final List<double> _heights = List.generate(_bars, (i) {
    final random = math.Random(i * 104729).nextDouble();
    return 0.3 + 0.7 * random;
  });

  final _player = AudioPlayer();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _ready = false;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _total;

  @override
  void initState() {
    super.initState();
    _total = widget.duration;
    _init();
  }

  Future<void> _init() async {
    try {
      final path = widget.path;
      final loaded = path.startsWith('http')
          ? await _player.setUrl(path)
          : await _player.setFilePath(path);
      if (!mounted) return;
      setState(() {
        _ready = true;
        _total = loaded ?? _total;
      });
      _subscriptions
        ..add(
          _player.positionStream.listen((p) => setState(() => _position = p)),
        )
        ..add(
          _player.playerStateStream.listen((s) {
            if (s.processingState == ProcessingState.completed) {
              _player
                ..pause()
                ..seek(Duration.zero);
            }
            setState(
              () => _playing =
                  s.playing && s.processingState != ProcessingState.completed,
            );
          }),
        );
    } catch (e) {
      AppLogger.w('Voice note load failed', e);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_ready) return;
    _playing ? _player.pause() : _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _total ?? Duration.zero;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final remaining = _playing ? total - _position : total;
    final accent = widget.onDark ? Colors.white : theme.secondary(context);
    final idle = widget.onDark
        ? Colors.white.withValues(alpha: 0.4)
        : theme.textTertiary(context).withValues(alpha: 0.55);

    return Row(
      children: [
        Material(
          color: accent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: _toggle,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: 40.r,
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 24.r,
                color: widget.onDark ? theme.secondary(context) : Colors.white,
              ),
            ),
          ),
        ),
        Gap(12.w),
        Expanded(
          child: SizedBox(
            height: 28.h,
            child: CustomPaint(
              painter: _BarsPainter(
                heights: _heights,
                progress: progress,
                played: accent,
                idle: idle,
              ),
            ),
          ),
        ),
        Gap(10.w),
        Text(
          RequestFormatters.duration(
            remaining.isNegative ? Duration.zero : remaining,
          ),
          style: TextStyle(
            fontSize: 13.sp,
            color: widget.onDark
                ? Colors.white.withValues(alpha: 0.8)
                : theme.textSecondary(context),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> heights;
  final double progress;
  final Color played;
  final Color idle;

  _BarsPainter({
    required this.heights,
    required this.progress,
    required this.played,
    required this.idle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / heights.length;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = step * 0.45;
    for (var i = 0; i < heights.length; i++) {
      paint.color = (i + 0.5) / heights.length <= progress ? played : idle;
      final h = size.height * heights[i];
      final x = step * i + step / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.progress != progress || old.played != played;
}
