/// Args của route `RouteName.assistant` (truyền qua `extra`).
class AssistantPageArgs {
  /// Câu vừa nhập / nói ở Home hoặc hero Social Market — gửi ngay khi mở chat.
  final String text;

  /// File đính kèm ở ô "Ask StrongBody" — đi kèm khi khách đăng request từ chat.
  final List<String> attachmentPaths;

  /// Nơi gửi (analytics `assistant_message_sent.source`).
  final String source;

  const AssistantPageArgs({
    this.text = '',
    this.attachmentPaths = const [],
    this.source = 'unknown',
  });

  static AssistantPageArgs fromExtra(Object? extra) =>
      extra is AssistantPageArgs ? extra : const AssistantPageArgs();
}
