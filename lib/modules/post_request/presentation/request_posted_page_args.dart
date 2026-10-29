/// Dữ liệu cho màn "Request posted" (route ngoài ShellRoute nên nhận qua `extra`).
class RequestPostedPageArgs {
  /// Câu đầu của mô tả.
  final String headline;

  /// "At my home · Sat 24 – Sun 25 Oct · $60–80".
  final String summary;

  /// Gửi riêng cho N provider đã chọn; null = đăng cho mọi provider phù hợp.
  final int? chosenCount;

  /// Số provider phù hợp (khi đăng công khai); null = không rõ.
  final int? matchCount;

  const RequestPostedPageArgs({
    this.headline = '',
    this.summary = '',
    this.chosenCount,
    this.matchCount,
  });

  static RequestPostedPageArgs fromExtra(Object? extra) =>
      extra is RequestPostedPageArgs ? extra : const RequestPostedPageArgs();
}
