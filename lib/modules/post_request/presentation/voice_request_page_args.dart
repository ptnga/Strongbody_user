/// Args của route `RouteName.voiceRequest` (truyền qua `extra`).
class VoiceRequestPageArgs {
  /// File đính kèm đã chọn ở ô "Ask StrongBody" — đi tiếp sang form Post Request.
  final List<String> attachmentPaths;

  /// true = "Refine by voice" ở màn Matching providers: ✓ trả câu nói về
  /// (`context.pop(text)`) thay vì sang "Here's what I heard"; không ghi voice note.
  final bool refine;

  /// Nơi mở màn nói (analytics `voice_request_opened.source`).
  final String source;

  const VoiceRequestPageArgs({
    this.attachmentPaths = const [],
    this.refine = false,
    this.source = 'unknown',
  });

  static VoiceRequestPageArgs fromExtra(Object? extra) =>
      extra is VoiceRequestPageArgs ? extra : const VoiceRequestPageArgs();
}
