import 'post_request_flow_args.dart';

/// browse: xem provider phù hợp, chạm một người → gửi request riêng cho họ.
/// choose: chọn nhiều provider cho "Only providers I choose".
enum MatchingProvidersMode { browse, choose }

class MatchingProvidersPageArgs {
  final MatchingProvidersMode mode;

  /// Mở thẳng từ Home (gõ / gợi ý / menu): bắt đầu luồng mới với các args này.
  /// Có chữ → AI phân tích nền, back về "Here's what I heard"; `browseOnly` → chỉ duyệt.
  final PostRequestFlowArgs? start;

  const MatchingProvidersPageArgs({
    this.mode = MatchingProvidersMode.browse,
    this.start,
  });

  /// Back của trang provider → "Here's what I heard" (như prototype "Voice search results").
  bool get backToHeard => start != null && !start!.browseOnly;

  static MatchingProvidersPageArgs fromExtra(Object? extra) =>
      extra is MatchingProvidersPageArgs
      ? extra
      : const MatchingProvidersPageArgs();
}
