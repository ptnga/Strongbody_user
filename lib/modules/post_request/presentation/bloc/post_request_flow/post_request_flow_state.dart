part of 'post_request_flow_bloc.dart';

/// working: AI đang xử lý (form khoá); ready: form mở cho người dùng sửa & đăng.
enum PostRequestAnalysisStatus { working, ready }

/// Bước của AI (web `DraftStep`) — chọn câu trạng thái trên thanh tiến trình.
enum PostRequestDraftStep { transcribing, drafting }

/// filled: AI đã điền; empty: AI coi nội dung rỗng; failed: lỗi giữa chừng (form giữ
/// phần còn lại); none: không có input (form trống).
enum PostRequestDraftOutcome { filled, empty, failed, none }

enum PostRequestSubmitStatus { idle, submitting, success, pendingAuth, failure }

enum PostRequestNotice {
  transcribeFailed,
  rateLimited,
  emptyVoice,
  draftFailed,
  descriptionRequired,
  descriptionTooShort,
  descriptionTooLong,
  requestFailed,
}

class PostRequestFlowState extends Equatable {
  final PostRequestAnalysisStatus analysisStatus;
  final PostRequestDraftStep? step;

  /// 0–100. Ước lượng: chạy chậm dần về mốc của bước hiện tại, xong thì nhảy tới mốc.
  final double progress;
  final RequestFormValues values;
  final PostRequestDraftOutcome? outcome;

  /// Category / điểm chất lượng / gợi ý của AI — gửi kèm khi đăng, không hiển thị.
  final RequestAssistantMeta? assistant;
  final List<CurrencyOption> currencies;
  final PostRequestSubmitStatus submitStatus;

  /// Request vừa đăng (id → trang "Providers for your request").
  final CreatedRequest? created;
  final PostRequestNotice? notice;
  final String? noticeMessage;

  /// Voice note vừa bấm xoá — giữ lại để "Undo remove" (không gửi kèm request).
  final String? removedVoicePath;
  final Duration? removedVoiceDuration;

  const PostRequestFlowState({
    this.analysisStatus = PostRequestAnalysisStatus.working,
    this.step,
    this.progress = 0,
    this.values = const RequestFormValues(),
    this.outcome,
    this.assistant,
    this.currencies = const [],
    this.submitStatus = PostRequestSubmitStatus.idle,
    this.created,
    this.notice,
    this.noticeMessage,
    this.removedVoicePath,
    this.removedVoiceDuration,
  });

  bool get isWorking => analysisStatus == PostRequestAnalysisStatus.working;
  bool get isSubmitting => submitStatus == PostRequestSubmitStatus.submitting;
  bool get hasRemovedVoice => removedVoicePath != null;

  PostRequestFlowState copyWith({
    PostRequestAnalysisStatus? analysisStatus,
    PostRequestDraftStep? step,
    bool clearStep = false,
    double? progress,
    RequestFormValues? values,
    PostRequestDraftOutcome? outcome,
    RequestAssistantMeta? assistant,
    List<CurrencyOption>? currencies,
    PostRequestSubmitStatus? submitStatus,
    CreatedRequest? created,
    PostRequestNotice? notice,
    String? noticeMessage,
    bool clearNotice = false,
    String? removedVoicePath,
    Duration? removedVoiceDuration,
    bool clearRemovedVoice = false,
  }) {
    return PostRequestFlowState(
      analysisStatus: analysisStatus ?? this.analysisStatus,
      step: clearStep ? null : (step ?? this.step),
      progress: progress ?? this.progress,
      values: values ?? this.values,
      outcome: outcome ?? this.outcome,
      assistant: assistant ?? this.assistant,
      currencies: currencies ?? this.currencies,
      submitStatus: submitStatus ?? this.submitStatus,
      created: created ?? this.created,
      notice: clearNotice ? null : (notice ?? this.notice),
      noticeMessage: clearNotice ? null : (noticeMessage ?? this.noticeMessage),
      removedVoicePath: clearRemovedVoice
          ? null
          : (removedVoicePath ?? this.removedVoicePath),
      removedVoiceDuration: clearRemovedVoice
          ? null
          : (removedVoiceDuration ?? this.removedVoiceDuration),
    );
  }

  @override
  List<Object?> get props => [
    analysisStatus,
    step,
    progress,
    values,
    outcome,
    assistant,
    currencies,
    submitStatus,
    created,
    notice,
    noticeMessage,
    removedVoicePath,
    removedVoiceDuration,
  ];
}
