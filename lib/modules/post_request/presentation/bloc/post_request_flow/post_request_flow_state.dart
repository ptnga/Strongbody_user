part of 'post_request_flow_bloc.dart';

/// analyzing: đang chuyển chữ / AI phân tích; ready: có kết quả (kể cả khi AI lỗi → giữ câu gốc).
enum PostRequestAnalysisStatus { analyzing, ready }

/// filled: AI đã hiểu; empty: AI coi nội dung rỗng; failed: lỗi AI (form giữ câu gốc).
enum PostRequestDraftOutcome { filled, empty, failed }

/// Ai thấy request: mọi provider phù hợp (`/buyer/request`) hoặc chỉ người đã chọn (`/to-seller`).
enum RequestVisibility { allMatching, chosenProviders }

enum PostRequestSubmitStatus { idle, submitting, success, pendingAuth, failure }

enum PostRequestNotice {
  transcribeFailed,
  rateLimited,
  emptyVoice,
  draftFailed,
  descriptionRequired,
  deliveryRequired,
  chooseProviders,
  requestFailed;

  /// Lỗi ở bước phân tích (màn Heard báo); còn lại là lỗi khi đăng (màn Review báo).
  bool get isAnalysisNotice =>
      this == transcribeFailed ||
      this == rateLimited ||
      this == emptyVoice ||
      this == draftFailed;
}

class PostRequestFlowState extends Equatable {
  final PostRequestAnalysisStatus analysisStatus;

  /// Câu người dùng đã nói / gõ (hiện trong ngoặc kép ở "Here's what I heard").
  final String transcript;
  final String? languageCode;
  final RequestFormValues values;
  final PostRequestDraftOutcome? outcome;
  final RequestAssistantMeta? assistant;

  /// Tổng provider khớp từ khoá nghề; null = chưa biết / không tìm được.
  final int? matchCount;
  final String? providerKeyword;
  final RequestVisibility visibility;
  final List<ProviderEntity> selectedProviders;
  final PostRequestSubmitStatus submitStatus;
  final PostRequestNotice? notice;
  final String? noticeMessage;

  /// Voice note vừa bấm xoá ở Review — giữ lại để "Undo remove" (không gửi kèm request).
  final String? removedVoicePath;
  final Duration? removedVoiceDuration;

  const PostRequestFlowState({
    this.analysisStatus = PostRequestAnalysisStatus.analyzing,
    this.transcript = '',
    this.languageCode,
    this.values = const RequestFormValues(),
    this.outcome,
    this.assistant,
    this.matchCount,
    this.providerKeyword,
    this.visibility = RequestVisibility.allMatching,
    this.selectedProviders = const [],
    this.submitStatus = PostRequestSubmitStatus.idle,
    this.notice,
    this.noticeMessage,
    this.removedVoicePath,
    this.removedVoiceDuration,
  });

  bool get isAnalyzing => analysisStatus == PostRequestAnalysisStatus.analyzing;
  bool get isSubmitting => submitStatus == PostRequestSubmitStatus.submitting;
  bool get hasRemovedVoice => removedVoicePath != null;

  /// Số provider sẽ nhận request (để hiện ở màn "Request posted").
  int? get recipientCount => visibility == RequestVisibility.chosenProviders
      ? selectedProviders.length
      : matchCount;

  PostRequestFlowState copyWith({
    PostRequestAnalysisStatus? analysisStatus,
    String? transcript,
    String? languageCode,
    RequestFormValues? values,
    PostRequestDraftOutcome? outcome,
    RequestAssistantMeta? assistant,
    int? matchCount,
    String? providerKeyword,
    RequestVisibility? visibility,
    List<ProviderEntity>? selectedProviders,
    PostRequestSubmitStatus? submitStatus,
    PostRequestNotice? notice,
    String? noticeMessage,
    bool clearNotice = false,
    String? removedVoicePath,
    Duration? removedVoiceDuration,
    bool clearRemovedVoice = false,
  }) {
    return PostRequestFlowState(
      analysisStatus: analysisStatus ?? this.analysisStatus,
      transcript: transcript ?? this.transcript,
      languageCode: languageCode ?? this.languageCode,
      values: values ?? this.values,
      outcome: outcome ?? this.outcome,
      assistant: assistant ?? this.assistant,
      matchCount: matchCount ?? this.matchCount,
      providerKeyword: providerKeyword ?? this.providerKeyword,
      visibility: visibility ?? this.visibility,
      selectedProviders: selectedProviders ?? this.selectedProviders,
      submitStatus: submitStatus ?? this.submitStatus,
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
    transcript,
    languageCode,
    values,
    outcome,
    assistant,
    matchCount,
    providerKeyword,
    visibility,
    selectedProviders,
    submitStatus,
    notice,
    noticeMessage,
    removedVoicePath,
    removedVoiceDuration,
  ];
}
