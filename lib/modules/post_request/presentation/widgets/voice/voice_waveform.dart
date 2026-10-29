import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:strongbody_buyer/core/themes/theme.dart';

import '../../bloc/voice_request/voice_request_bloc.dart';

/// Sóng âm: các vạch đỏ dao động theo âm lượng thật khi đang nghe,
/// đứng yên (biên độ vừa) khi tạm dừng / đã xong.
class VoiceWaveform extends StatefulWidget {
  const VoiceWaveform({super.key});

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  static const _bars = 32;

  /// Chiều cao gốc mỗi vạch (giả ngẫu nhiên, cố định) — cao ở giữa, thấp ở hai đầu.
  static final List<double> _base = List.generate(_bars, (i) {
    final random = math.Random(i * 7919).nextDouble();
    final center = 1 - (i - (_bars - 1) / 2).abs() / (_bars / 2);
    // Vạch hai đầu thấp, giữa cao, xen kẽ cao thấp như mockup.
    return (0.12 + 0.5 * random * random + 0.38 * center).clamp(0.1, 1.0);
  });

  late final AnimationController _ticker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Âm lượng hiển thị — nội suy dần tới mức thật cho mượt.
  double _shown = 0;
  double _target = 0;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _ticker.addListener(() {
      _shown += (_target - _shown) * 0.18;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _sync(VoiceRequestState state) {
    _target = state.level;
    if (state.isListening != _listening) {
      _listening = state.isListening;
      _listening ? _ticker.repeat() : _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primary(context);
    return BlocListener<VoiceRequestBloc, VoiceRequestState>(
      listener: (context, state) => setState(() => _sync(state)),
      child: SizedBox(
        width: 220.w,
        height: 56.h,
        child: AnimatedBuilder(
          animation: _ticker,
          builder: (context, _) => CustomPaint(
            painter: _WavePainter(
              base: _base,
              phase: _ticker.value * 2 * math.pi,
              level: _shown,
              listening: _listening,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> base;
  final double phase;
  final double level;
  final bool listening;
  final Color color;

  _WavePainter({
    required this.base,
    required this.phase,
    required this.level,
    required this.listening,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;
    final step = size.width / base.length;
    paint.strokeWidth = step * 0.42;
    final midY = size.height / 2;

    for (var i = 0; i < base.length; i++) {
      double factor;
      if (listening) {
        // Luôn "thở" nhẹ khi đang nghe; nói to thì vạch cao hẳn lên.
        final wobble = 0.7 + 0.3 * math.sin(phase * 2 + i * 0.75);
        factor = (0.3 + 0.7 * level) * wobble;
      } else {
        factor = 0.7;
      }
      final height = math.max(
        paint.strokeWidth,
        size.height * base[i] * factor,
      );
      final x = step * i + step / 2;
      canvas.drawLine(
        Offset(x, midY - height / 2),
        Offset(x, midY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.phase != phase || old.level != level || old.listening != listening;
}
