import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../../../domain/entities/post_request_failure.dart';
import '../../../domain/entities/posted_request_entity.dart';
import '../../../domain/entities/request_draft_entity.dart';
import '../../../domain/entities/request_form_values.dart';
import '../../../domain/usecases/create_buyer_request_use_case.dart';
import '../../../domain/usecases/draft_request_use_case.dart';
import '../../../domain/usecases/get_currencies_use_case.dart';
import '../../../domain/usecases/transcribe_audio_use_case.dart';
import '../../post_request_flow_args.dart';

part 'post_request_flow_event.dart';
part 'post_request_flow_state.dart';

/// Màn "Post a request" (web `/request-assistant`): form hiện ngay (đang khoá) kèm
/// thanh tiến trình trong lúc AI xử lý (giọng nói → text → LLM), AI xong thì form mở
/// với nội dung đã điền để người dùng kiểm tra rồi đăng.
///
/// Giống web `useRequestDraft` + `useCreateRequest`: `/speech-to-text` →
/// `/api/ai/request-draft` → `POST /buyer/request` (hoặc `/to-seller`); chưa đăng nhập
/// thì giữ request, đăng ký / đăng nhập xong đăng tiếp.
class PostRequestFlowBloc
    extends BlocWithApi<PostRequestFlowEvent, PostRequestFlowState> {
  final TranscribeAudioUseCase _transcribeAudio;
  final DraftRequestUseCase _draftRequest;
  final CreateBuyerRequestUseCase _createBuyerRequest;
  final GetCurrenciesUseCase _getCurrencies;
  final GlobalStorage _storage;

  /// Mốc % của từng bước: giọng nói → text 3–40%, AI soạn form 40–95%.
  static const _stepRange = {
    PostRequestDraftStep.transcribing: (3.0, 40.0),
    PostRequestDraftStep.drafting: (40.0, 95.0),
  };
  static const _tick = Duration(milliseconds: 120);

  /// Giữ thanh 100% thêm một nhịp trước khi mở form để mắt kịp thấy "xong".
  static const finishHold = Duration(milliseconds: 450);

  Timer? _ticker;
  List<int> _sellerUserIds = const [];

  /// Bản ghi chỉ để chuyển chữ (không kèm request) — xoá khi đóng màn.
  String? _tempAudio;

  /// Seller đã nhận request (gửi lần lượt) → bấm gửi lại sau lỗi không gửi trùng.
  final _postedSellerIds = <int>{};

  Future<void> Function(String description)? _onPosted;

  PostRequestFlowBloc({
    required TranscribeAudioUseCase transcribeAudio,
    required DraftRequestUseCase draftRequest,
    required CreateBuyerRequestUseCase createBuyerRequest,
    required GetCurrenciesUseCase getCurrencies,
    required GlobalStorage storage,
  }) : _transcribeAudio = transcribeAudio,
       _draftRequest = draftRequest,
       _createBuyerRequest = createBuyerRequest,
       _getCurrencies = getCurrencies,
       _storage = storage,
       super(const PostRequestFlowState()) {
    on<PostRequestFlowStarted>(_onStarted);
    on<PostRequestFlowValuesChanged>((event, emit) {
      if (!state.isWorking) emit(state.copyWith(values: event.values));
    });
    on<_PostRequestFlowTicked>((event, emit) {
      final step = state.step;
      if (!state.isWorking || step == null) return;
      final cap = _stepRange[step]!.$2;
      if (state.progress >= cap - 0.5) return;
      emit(
        state.copyWith(
          progress: state.progress + (cap - state.progress) * 0.06,
        ),
      );
    });
    on<_PostRequestFlowCurrenciesLoaded>((event, emit) {
      // Tiền chọn sẵn chưa có id → điền id khi danh sách tải xong (web `CurrencySelect`).
      final values = state.values;
      final match = event.currencies
          .where((c) => c.code == values.currency)
          .firstOrNull;
      emit(
        state.copyWith(
          currencies: event.currencies,
          values: values.currencyId == null && match != null
              ? values.copyWith(currencyId: match.id)
              : values,
        ),
      );
    });
    on<PostRequestFlowVoiceRemoved>((event, emit) {
      final values = state.values;
      if (!values.hasVoice) return;
      AppAnalytics.capture(AnalyticsEvents.requestVoiceNoteRemoved);
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
      AppAnalytics.capture(AnalyticsEvents.requestVoiceNoteRestored);
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
    _onPosted = args.onPosted;
    _sellerUserIds = args.sellerUserIds;
    if (!args.attachVoice) _tempAudio = args.audioPath;
    unawaited(_loadCurrencies());

    // Request mới: Working language mặc định = ngôn ngữ giao diện (gửi riêng 1 provider
    // thì không có ô này); voice note chỉ kèm khi bật "Attach my voice to requests".
    final base = RequestFormValues(
      description: args.text.trim(),
      sellerLanguages: args.isSend ? const [] : [event.locale.split('-').first],
      attachmentPaths: args.attachmentPaths,
      voicePath: args.attachVoice ? args.audioPath : null,
      voiceDuration: args.attachVoice ? args.voiceDuration : null,
    );

    final draft = args.draft;
    final prefill = args.prefill;
    if (draft != null || prefill != null) {
      emit(
        state.copyWith(
          analysisStatus: PostRequestAnalysisStatus.ready,
          progress: 100,
          values: draft != null
              ? draft.values.copyWith(attachmentPaths: args.attachmentPaths)
              : prefill!.copyWith(sellerLanguages: base.sellerLanguages),
          outcome: draft == null || draft.isEmpty
              ? PostRequestDraftOutcome.empty
              : PostRequestDraftOutcome.filled,
          assistant: draft?.assistant,
        ),
      );
      return;
    }

    var text = base.description;
    final audio = args.audioPath;
    if (text.isEmpty && audio == null) {
      emit(
        state.copyWith(
          analysisStatus: PostRequestAnalysisStatus.ready,
          progress: 100,
          values: base,
          outcome: PostRequestDraftOutcome.none,
        ),
      );
      return;
    }

    _startTicker();
    if (text.isNotEmpty) {
      // Hiện sẵn câu đã gõ trong form (đang khoá) trong lúc chờ AI.
      emit(
        state.copyWith(
          step: PostRequestDraftStep.drafting,
          progress: _stepRange[PostRequestDraftStep.drafting]!.$1 / 4,
          values: base,
        ),
      );
    } else {
      emit(
        state.copyWith(
          step: PostRequestDraftStep.transcribing,
          progress: _stepRange[PostRequestDraftStep.transcribing]!.$1,
          values: base,
        ),
      );
      PostRequestNotice? notice;
      await callApi(
        useCase: _transcribeAudio,
        param: TranscribeAudioParams(audio!),
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
        await _finish(
          emit,
          values: base,
          outcome: PostRequestDraftOutcome.failed,
          notice: notice,
        );
        _trackAnalysis(transcribed: false);
        return;
      }
      emit(
        state.copyWith(
          step: PostRequestDraftStep.drafting,
          progress: _stepRange[PostRequestDraftStep.drafting]!.$1,
        ),
      );
    }

    RequestDraftEntity? result;
    await callApi(
      useCase: _draftRequest,
      param: DraftRequestParams(text: text, locale: event.locale),
      onSuccess: (draft) async => result = draft,
      onFailure: (_) {},
    );
    final drafted = result;
    if (drafted == null) {
      await _finish(
        emit,
        values: base.copyWith(description: text),
        outcome: PostRequestDraftOutcome.failed,
        notice: PostRequestNotice.draftFailed,
      );
    } else {
      await _finish(
        emit,
        values: drafted.values.copyWith(
          attachmentPaths: base.attachmentPaths,
          voicePath: base.voicePath,
          voiceDuration: base.voiceDuration,
        ),
        outcome: drafted.isEmpty
            ? PostRequestDraftOutcome.empty
            : PostRequestDraftOutcome.filled,
        assistant: drafted.assistant,
      );
    }
    _trackAnalysis(transcribed: audio != null && args.text.trim().isEmpty);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) {
      if (!isClosed) add(const _PostRequestFlowTicked());
    });
  }

  /// Thanh lên 100%, giữ một nhịp rồi mở form với kết quả.
  Future<void> _finish(
    Emitter<PostRequestFlowState> emit, {
    required RequestFormValues values,
    required PostRequestDraftOutcome outcome,
    RequestAssistantMeta? assistant,
    PostRequestNotice? notice,
  }) async {
    _ticker?.cancel();
    emit(state.copyWith(progress: 100));
    await Future<void>.delayed(finishHold);
    if (isClosed) return;
    emit(
      state.copyWith(
        analysisStatus: PostRequestAnalysisStatus.ready,
        clearStep: true,
        values: values,
        outcome: outcome,
        assistant: assistant,
        notice: notice,
      ),
    );
  }

  /// Danh sách tiền + id của tiền đang chọn (gửi kèm `currency_id`).
  Future<void> _loadCurrencies() async {
    final result = await _getCurrencies(const NoParams());
    if (isClosed) return;
    result.match((_) {}, (list) {
      if (list.isNotEmpty) add(_PostRequestFlowCurrenciesLoaded(list));
    });
  }

  void _trackAnalysis({required bool transcribed}) {
    AppAnalytics.capture(AnalyticsEvents.requestAnalysisCompleted, {
      'outcome': state.outcome?.name,
      'notice': state.notice?.name,
      'has_voice': state.values.hasVoice,
      'transcribed': transcribed,
      'category_id': state.assistant?.categoryIds.firstOrNull,
      'quality_score': state.assistant?.qualityScore,
    });
  }

  Map<String, Object?> _requestProperties(RequestFormValues values) => {
    'send_to_providers': _sellerUserIds.length,
    'has_voice': values.hasVoice,
    'attachments_count': values.attachmentPaths.length,
    'delivery_types': values.deliveryTypes.map((t) => t.apiValue).join(','),
    'has_budget': values.budget.trim().isNotEmpty,
    'anonymous': values.anonymous,
    'languages': values.sellerLanguages.join(','),
    'similar_to': values.similarToRequestId,
    'category_id': state.assistant?.categoryIds.firstOrNull,
  };

  Future<void> _onSubmitted(
    PostRequestFlowSubmitted event,
    Emitter<PostRequestFlowState> emit,
  ) async {
    if (state.isWorking || state.isSubmitting) return;
    final values = state.values.copyWith(
      description: state.values.description.trim(),
    );

    final notice = switch (RequestFormValues.descriptionError(
      values.description,
    )) {
      DescriptionError.required => PostRequestNotice.descriptionRequired,
      DescriptionError.tooShort => PostRequestNotice.descriptionTooShort,
      DescriptionError.tooLong => PostRequestNotice.descriptionTooLong,
      null => null,
    };
    if (notice != null || !RequestFormValues.isValidBudgetText(values.budget)) {
      if (notice != null) emit(state.copyWith(notice: notice));
      return;
    }

    final userId = _storage.userId;
    if (!_storage.isLoggedIn || userId == null) {
      // Chưa đăng nhập: giữ nội dung (trừ file) — đăng nhập xong sẽ đăng tiếp.
      await _storage.savePendingRequest({
        ...values.toStorageJson(),
        'sellerUserIds': _sellerUserIds,
        if (state.assistant != null)
          'assistant': {
            'categoryIds': state.assistant!.categoryIds,
            'qualityScore': state.assistant!.qualityScore,
            'suggestion': state.assistant!.suggestion,
          },
      });
      // Lần trước đã đóng popup đăng ký → về idle trước để màn mở lại popup.
      if (state.submitStatus == PostRequestSubmitStatus.pendingAuth) {
        emit(state.copyWith(submitStatus: PostRequestSubmitStatus.idle));
      }
      emit(
        state.copyWith(
          values: values,
          submitStatus: PostRequestSubmitStatus.pendingAuth,
        ),
      );
      return;
    }

    final sellerIds = [
      for (final id in _sellerUserIds)
        if (!_postedSellerIds.contains(id)) id,
    ];
    // Mọi provider đã nhận ở lần trước → xong; KHÔNG gửi danh sách rỗng
    // (rỗng = đăng công khai cho mọi provider).
    if (_sellerUserIds.isNotEmpty && sellerIds.isEmpty) {
      await _storage.clearPendingRequest();
      emit(
        state.copyWith(
          values: values,
          submitStatus: PostRequestSubmitStatus.success,
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
        sellerUserIds: sellerIds,
        onSellerPosted: _postedSellerIds.add,
      ),
      onSuccess: (created) async {
        AppAnalytics.capture(AnalyticsEvents.requestPosted, {
          'status': created.status,
          ..._requestProperties(values),
        });
        await _storage.clearPendingRequest();
        emit(
          state.copyWith(
            submitStatus: PostRequestSubmitStatus.success,
            created: created,
          ),
        );
        final onPosted = _onPosted;
        _onPosted = null;
        if (onPosted != null) unawaited(onPosted(values.description));
      },
      onFailure: (message) {
        AppAnalytics.capture(AnalyticsEvents.requestPostFailed, {
          'error': message,
          ..._requestProperties(values),
        });
        emit(
          state.copyWith(
            submitStatus: PostRequestSubmitStatus.failure,
            notice: PostRequestNotice.requestFailed,
            noticeMessage: message,
          ),
        );
      },
    );
  }

  /// Bỏ file ghi âm của luồng (đã gửi lên BE hoặc người dùng bỏ dở).
  @override
  Future<void> close() async {
    _ticker?.cancel();
    for (final path in {
      state.values.voicePath,
      state.removedVoicePath,
      _tempAudio,
    }) {
      if (path == null) continue;
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    return super.close();
  }
}
