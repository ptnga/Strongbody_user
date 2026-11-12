import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Hiện dần câu trả lời (web `useTypewriter`), dù BE stream từng mẩu (RAG, AI viết câu
/// trả lời) hay gửi cả câu một lúc (câu viết sẵn khi không có kết quả, câu chào). Lượt nạp
/// lại từ lịch sử ([live] = false) hiện ngay cả câu; máy tắt hiệu ứng chuyển động cũng vậy.
class AssistantTypewriter extends StatefulWidget {
  final String text;
  final bool live;
  final Widget Function(String shown, bool typing) builder;

  const AssistantTypewriter({
    super.key,
    required this.text,
    required this.live,
    required this.builder,
  });

  /// Mỗi nhịp hiện thêm 1 phần chữ còn lại (ít nhất 2 ký tự), dồn nhiều thì chạy nhanh hơn.
  static const tick = Duration(milliseconds: 30);
  static const minStep = 2;
  static const catchUp = 25;

  /// Số ký tự hiện ở nhịp sau.
  static int nextCount(int count, int length) => math.min(
    length,
    count + math.max(minStep, ((length - count) / catchUp).ceil()),
  );

  /// Không cắt đôi một ký tự 2 code unit (emoji).
  static String visible(String text, int count) {
    var end = math.min(count, text.length);
    if (end > 0 && end < text.length) {
      final code = text.codeUnitAt(end - 1);
      if (code >= 0xd800 && code <= 0xdbff) end -= 1;
    }
    return text.substring(0, end);
  }

  @override
  State<AssistantTypewriter> createState() => _AssistantTypewriterState();
}

class _AssistantTypewriterState extends State<AssistantTypewriter>
    with AutomaticKeepAliveClientMixin {
  late int _count = widget.live ? 0 : 1 << 31;
  Timer? _timer;

  /// Giữ lượt đang/đã chạy chữ khi cuộn khỏi màn, kẻo dựng lại thì chạy chữ lại từ đầu.
  @override
  bool get wantKeepAlive => widget.live;

  bool get _animate => widget.live && _count < widget.text.length;

  @override
  void didUpdateWidget(covariant AssistantTypewriter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live != widget.live) updateKeepAlive();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    if (!_animate || (_timer?.isActive ?? false)) return;
    _timer = Timer(AssistantTypewriter.tick, () {
      if (!mounted) return;
      setState(
        () =>
            _count = AssistantTypewriter.nextCount(_count, widget.text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_animate && MediaQuery.maybeDisableAnimationsOf(context) == true) {
      _count = 1 << 31;
    }
    if (!_animate) return widget.builder(widget.text, false);
    _schedule();
    return widget.builder(
      AssistantTypewriter.visible(widget.text, _count),
      true,
    );
  }
}
