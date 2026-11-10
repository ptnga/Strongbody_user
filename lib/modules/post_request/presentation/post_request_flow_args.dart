import '../domain/entities/request_draft_entity.dart';
import '../domain/entities/request_form_values.dart';

/// Args vào màn "Post a request" (web `/request-assistant`) — truyền qua `extra`.
///
/// - Có [text] hoặc [audioPath] → AI soạn form (giọng nói → text → LLM), form khoá kèm
///   thanh tiến trình trong lúc chờ.
/// - Có [draft] (chat trợ lý đã điền) hoặc [prefill] ("Me too") → mở form ngay, không gọi AI.
/// - Không có gì → form trống để tự nhập.
class PostRequestFlowArgs {
  /// Câu đã gõ.
  final String text;

  /// Bản ghi âm từ nút "Get help" — BE chuyển chữ (`/speech-to-text`).
  final String? audioPath;

  /// Giữ bản ghi làm voice note của request (Account › Attach my voice to requests).
  final bool attachVoice;
  final Duration? voiceDuration;

  /// File đính kèm có sẵn (vd chọn ở ô hỏi trợ lý).
  final List<String> attachmentPaths;

  /// Bản nháp chat trợ lý AI đã điền.
  final RequestDraftEntity? draft;

  /// Request mới điền sẵn vài trường ("Me too": mô tả + hình thức + id request gốc).
  final RequestFormValues? prefill;

  /// Gửi riêng cho các provider này (`/buyer/request/to-seller`) — web form `variant="send"`:
  /// không có Working language / Post anonymously.
  final List<int> sellerUserIds;
  final String? sellerName;

  /// Gọi sau khi request đăng xong (vd Social Market › Health Solution: báo provider
  /// phù hợp qua API matching, như web `SolutionComposer`).
  final Future<void> Function(String description)? onPosted;

  const PostRequestFlowArgs({
    this.text = '',
    this.audioPath,
    this.attachVoice = false,
    this.voiceDuration,
    this.attachmentPaths = const [],
    this.draft,
    this.prefill,
    this.sellerUserIds = const [],
    this.sellerName,
    this.onPosted,
  });

  bool get isSend => sellerUserIds.isNotEmpty;

  static PostRequestFlowArgs fromExtra(Object? extra) =>
      extra is PostRequestFlowArgs ? extra : const PostRequestFlowArgs();
}
