import 'matching_providers_page_args.dart';

/// Args vào luồng Post Request (màn "Here's what I heard") — truyền qua `extra`.
class PostRequestFlowArgs {
  /// Câu đã nói (transcript trên máy) hoặc đã gõ ở Home. Rỗng + có voice → BE chuyển chữ.
  final String text;
  final String? voicePath;
  final Duration? voiceDuration;

  /// Mã ngôn ngữ đã nói (app code, vd `en`).
  final String? languageCode;

  /// File đính kèm chọn ở ô "Ask StrongBody".
  final List<String> attachmentPaths;

  /// "Browse providers" (menu / Account): chỉ duyệt, không có request để AI phân tích.
  final bool browseOnly;

  /// Gọi sau khi request đăng xong (vd Social Market › Health Solution: báo provider
  /// phù hợp qua API matching, như web `SolutionComposer`).
  final Future<void> Function(String description)? onPosted;

  const PostRequestFlowArgs({
    this.text = '',
    this.voicePath,
    this.voiceDuration,
    this.languageCode,
    this.attachmentPaths = const [],
    this.browseOnly = false,
    this.onPosted,
  });

  /// `extra` của route trong ShellRoute: args trực tiếp, hoặc `start` của trang provider.
  static PostRequestFlowArgs fromExtra(Object? extra) => switch (extra) {
    PostRequestFlowArgs args => args,
    MatchingProvidersPageArgs(:final start?) => start,
    _ => const PostRequestFlowArgs(),
  };
}
