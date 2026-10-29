import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';

import '../../../domain/entities/provider_keyword.dart';
import '../../../domain/entities/post_request_failure.dart';
import '../../../domain/entities/provider_entity.dart';
import '../../../domain/entities/request_draft_entity.dart';
import '../../../domain/entities/request_form_values.dart';
import '../../../domain/usecases/create_buyer_request_use_case.dart';
import '../../../domain/usecases/draft_request_use_case.dart';
import '../../../domain/usecases/search_providers_use_case.dart';
import '../../../domain/usecases/transcribe_audio_use_case.dart';
import '../../post_request_flow_args.dart';

part 'post_request_flow_event.dart';
part 'post_request_flow_state.dart';

/// Luồng Post Request sau khi nói / gõ yêu cầu — dùng chung cho các màn
/// "Here's what I heard" → "Review your request" → "Request posted" (ShellRoute).
///
/// API giống web (`useRequestDraft` + `useCreateRequest`) và Multime (`voice` file):
/// (giọng nói → text) → `/api/ai/request-draft` → `/public/profiles?keyword=`
/// → `POST /buyer/request` hoặc `/buyer/request/to-seller`.
class PostRequestFlowBloc
    extends BlocWithApi<PostRequestFlowEvent, PostRequestFlowState> {
  final TranscribeAudioUseCase _transcribeAudio;
  final DraftRequestUseCase _draftRequest;
  final SearchProvidersUseCase _searchProviders;
  final CreateBuyerRequestUseCase _createBuyerRequest;
  final GlobalStorage _storage;

  PostRequestFlowBloc({
    required TranscribeAudioUseCase transcribeAudio,
    required DraftRequestUseCase draftRequest,
    required SearchProvidersUseCase searchProviders,
    required CreateBuyerRequestUseCase createBuyerRequest,
    required GlobalStorage storage,
  }) : _transcribeAudio = transcribeAudio,
       _draftRequest = draftRequest,
       _searchProviders = searchProviders,
       _createBuyerRequest = createBuyerRequest,
       _storage = storage,
       super(const PostRequestFlowState()) {
    on<PostRequestFlowStarted>(_onStarted);
    on<PostRequestFlowValuesChanged>(
      (event, emit) => emit(state.copyWith(values: event.values)),
    );
    on<PostRequestFlowVisibilityChanged>(
      (event, emit) => emit(state.copyWith(visibility: event.visibility)),
    );
    on<PostRequestFlowProvidersSelected>(
      (event, emit) => emit(
        state.copyWith(
          selectedProviders: event.providers,
          visibility: event.providers.isEmpty
              ? state.visibility
              : RequestVisibility.chosenProviders,
        ),
      ),
    );
    on<PostRequestFlowCategoryChanged>((event, emit) {
      final meta = state.assistant;
      emit(
        state.copyWith(
          assistant: RequestAssistantMeta(
            categoryIds: [event.categoryId],
            qualityScore: meta?.qualityScore,
            suggestion: meta?.suggestion ?? '',
          ),
        ),
      );
    });
    on<PostRequestFlowVoiceRemoved>((event, emit) {
      final values = state.values;
      if (!values.hasVoice) return;
      emit(
        state.copyWith(
          values: values.copyWith(clearVoice: true),
          removedVoicePath: values.voicePath,
          removedVoiceDuration: values.voiceDuration,
        ),
      );
    });
    on<PostRequestFlowVoiceRestored>((event, emit) {
      final path = state.removedVoicePath;
      if (path == null) return;
      emit(
        state.copyWith(
          values: state.values.copyWith(
            voicePath: path,
            voiceDuration: state.removedVoiceDuration,
          ),
          clearRemovedVoice: true,
        ),
      );
    });
    on<PostRequestFlowSubmitted>(_onSubmitted);
    on<PostRequestFlowNoticeConsumed>(
      (event, emit) => emit(state.copyWith(clearNotice: true)),
    );
  }

  Future<void> _onStarted(
    PostRequestFlowStarted event,
    Emitter<PostRequestFlowState> emit,
  ) async {
    final args = event.args;
    var text = args.text.trim();
    emit(
      state.copyWith(
        analysisStatus: PostRequestAnalysisStatus.analyzing,
        transcript: text,
        languageCode: args.languageCode,
        values: RequestFormValues(
          description: text,
          attachmentPaths: args.attachmentPaths,
          voicePath: args.voicePath,
          voiceDuration: args.voiceDuration,
        ),
      ),
    );

    // Chỉ duyệt provider: không có gì để phân tích.
    if (args.browseOnly) {
      emit(
        state.copyWith(
          analysisStatus: PostRequestAnalysisStatus.ready,
          outcome: PostRequestDraftOutcome.empty,
        ),
      );
      return;
    }

    // Máy chưa nhận ra chữ nhưng có voice note → chuyển chữ qua BE (BE tự nhận diện ngôn ngữ).
    final voicePath = args.voicePath;
    if (text.isEmpty && voicePath != null) {
      PostRequestNotice? notice;
      await callApi(
        useCase: _transcribeAudio,
        param: TranscribeAudioParams(voicePath),
        onSuccess: (transcript) async => text = transcript.trim(),
        onFailure: (_) => notice ??= PostRequestNotice.transcribeFailed,
        onFailureTyped: (failure) {
          if (failure is SpeechRateLimitFailure) {
            notice = PostRequestNotice.rateLimited;
          }
        },
      );
      if (notice == null && text.isEmpty) notice = PostRequestNotice.emptyVoice;
      if (notice != null) {
        emit(
          state.copyWith(
            analysisStatus: PostRequestAnalysisStatus.ready,
            outcome: PostRequestDraftOutcome.failed,
            notice: notice,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          transcript: text,
          values: state.values.copyWith(description: text),
        ),
      );
    }

    RequestDraftEntity? draft;
    await callApi(
      useCase: _draftRequest,
      param: DraftRequestParams(text: text, locale: event.locale),
      onSuccess: (result) async => draft = result,
      onFailure: (_) {},
    );

    final result = draft;
    if (result == null) {
      emit(
        state.copyWith(
          analysisStatus: PostRequestAnalysisStatus.ready,
          outcome: PostRequestDraftOutcome.failed,
          notice: PostRequestNotice.draftFailed,
        ),
      );
    } else {
      emit(
        state.copyWith(
          analysisStatus: PostRequestAnalysisStatus.ready,
          values: result.values.copyWith(
            attachmentPaths: state.values.attachmentPaths,
            voicePath: state.values.voicePath,
            voiceDuration: state.values.voiceDuration,
          ),
          outcome: result.isEmpty
              ? PostRequestDraftOutcome.empty
              : PostRequestDraftOutcome.filled,
          assistant: result.assistant,
        ),
      );
    }

    await _countMatchingProviders(emit, text);
  }

  /// "12 providers match" — tổng kết quả của `/public/profiles?keyword=<tên nghề>`.
  Future<void> _countMatchingProviders(
    Emitter<PostRequestFlowState> emit,
    String text,
  ) async {
    final keyword = ProviderKeyword.fromText(
      '$text ${state.values.description}',
      state.assistant?.categoryIds ?? const [],
    );
    if (keyword == null) return;
    emit(state.copyWith(providerKeyword: keyword));
    await callApi(
      useCase: _searchProviders,
      param: SearchProvidersParams(keyword: keyword, limit: 1),
      onSuccess: (page) async => emit(state.copyWith(matchCount: page.total)),
      onFailure: (_) {},
    );
  }

  Future<void> _onSubmitted(
    PostRequestFlowSubmitted event,
    Emitter<PostRequestFlowState> emit,
  ) async {
    if (state.isAnalyzing || state.isSubmitting) return;
    final values = state.values.copyWith(
      description: state.values.description.trim(),
    );

    final notice = values.description.isEmpty
        ? PostRequestNotice.descriptionRequired
        : values.deliveryTypes.isEmpty
        ? PostRequestNotice.deliveryRequired
        : state.visibility == RequestVisibility.chosenProviders &&
              state.selectedProviders.isEmpty
        ? PostRequestNotice.chooseProviders
        : null;
    if (notice != null) {
      emit(state.copyWith(notice: notice));
      return;
    }

    final userId = _storage.userId;
    if (!_storage.isLoggedIn || userId == null) {
      // Chưa đăng nhập: giữ nội dung (trừ file) — đăng nhập xong sẽ đăng tiếp.
      await _storage.savePendingRequest({
        ...values.toStorageJson(),
        'visibility': state.visibility.name,
        'sellerUserIds': state.selectedProviders.map((p) => p.userId).toList(),
        if (state.assistant != null)
          'assistant': {
            'categoryIds': state.assistant!.categoryIds,
            'qualityScore': state.assistant!.qualityScore,
            'suggestion': state.assistant!.suggestion,
          },
      });
      emit(
        state.copyWith(
          values: values,
          submitStatus: PostRequestSubmitStatus.pendingAuth,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        values: values,
        submitStatus: PostRequestSubmitStatus.submitting,
      ),
    );
    await callApi(
      useCase: _createBuyerRequest,
      param: CreateBuyerRequestParams(
        userId: userId,
        values: values,
        assistant: state.assistant,
        sellerUserIds: state.visibility == RequestVisibility.chosenProviders
            ? state.selectedProviders.map((p) => p.userId).toList()
            : const [],
      ),
      onSuccess: (_) async {
        await _storage.clearPendingRequest();
        emit(state.copyWith(submitStatus: PostRequestSubmitStatus.success));
      },
      onFailure: (message) => emit(
        state.copyWith(
          submitStatus: PostRequestSubmitStatus.failure,
          notice: PostRequestNotice.requestFailed,
          noticeMessage: message,
        ),
      ),
    );
  }
}
