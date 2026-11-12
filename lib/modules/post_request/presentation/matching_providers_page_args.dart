/// Trang "Matching providers" (duyệt provider theo nghề) — mở từ menu / Account.
class MatchingProvidersPageArgs {
  /// Chữ tìm sẵn (tên nghề); rỗng = mọi provider.
  final String text;

  const MatchingProvidersPageArgs({this.text = ''});

  static MatchingProvidersPageArgs fromExtra(Object? extra) =>
      extra is MatchingProvidersPageArgs
      ? extra
      : const MatchingProvidersPageArgs();
}
