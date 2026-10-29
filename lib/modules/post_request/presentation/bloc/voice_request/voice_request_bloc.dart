import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/services/microphone_permission_service.dart';
import 'package:strongbody_buyer/core/services/speech_recognition_service.dart';
import 'package:strongbody_buyer/core/services/voice_note_recorder.dart';
import 'package:strongbody_buyer/core/utils/app_logger.dart';

import '../../../domain/entities/voice_language_option.dart';

part 'voice_request_event.dart';
part 'voice_request_state.dart';

/// Màn "nói yêu cầu": nhận dạng trên máy, hiện transcript trực tiếp, tự dừng sau
/// [silence] im lặng; đồng thời ghi voice note (m4a) để gửi kèm request.
/// Bấm ✓ → [VoiceRequestResult] sang màn "Here's what I heard".
class VoiceRequestBloc extends Bloc<VoiceRequestEvent, VoiceRequestState> {
  final SpeechRecognitionService _speech;
  final VoiceNoteRecorder _recorder;
  final MicrophonePermissionService _permission;

  bool _recordVoiceNote = true;
  bool _recordingStarted = false;
  bool _recorderPaused = false;

  /// Voice note đã giao cho màn sau → không xoá khi đóng bloc.
  bool _handedOff = false;

  /// Mã ngôn ngữ (app) của locale nhận dạng mặc định — hiển thị "Detected: …" khi Auto-detect.
  String? _systemLanguageCode;

  static const silence = Duration(seconds: 4);

  /// Giới hạn một lượt nghe (giống giới hạn ghi âm 120s của web).
  static const maxListen = Duration(minutes: 2);

  // Biên âm lượng tự thích nghi: thang đo khác nhau giữa iOS / Android.
  double _minLevel = double.infinity;
  double _maxLevel = double.negativeInfinity;

  /// Status `notListening`/`done` của lượt trước có thể đến muộn sau khi đã nghe
  /// lại (pause → resume) → bỏ qua status ngay sau lúc bắt đầu nghe.
  DateTime _listenStartedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _staleStatusWindow = Duration(milliseconds: 600);

  VoiceRequestBloc({
    required SpeechRecognitionService speech,
    required VoiceNoteRecorder recorder,
    required MicrophonePermissionService permission,
  }) : _speech = speech,
       _recorder = recorder,
       _permission = permission,
       super(const VoiceRequestState()) {
    on<VoiceRequestStarted>(_onStarted);
    on<VoiceRequestRetried>(_onRetried);
    on<VoiceRequestPauseToggled>(_onPauseToggled);
    on<VoiceRequestRestarted>(_onRestarted);
    on<VoiceRequestLanguageSelected>(_onLanguageSelected);
    on<VoiceRequestTextEdited>(
      (event, emit) =>
          emit(state.copyWith(committedText: event.text, partialText: '')),
    );
    on<VoiceRequestSubmitted>(_onSubmitted);
    on<VoiceRequestOneShotConsumed>(
      (event, emit) => emit(state.copyWith(clearOneShot: true)),
    );
    on<_VoiceRequestResultReceived>(_onResult);
    on<_VoiceRequestStatusChanged>(_onStatus);
    on<_VoiceRequestErrorReceived>(_onError);
    on<_VoiceRequestSoundLevelChanged>(_onSoundLevel);
  }

  Future<void> _onStarted(
    VoiceRequestStarted event,
    Emitter<VoiceRequestState> emit,
  ) async {
    _recordVoiceNote = event.recordVoiceNote;
    await _initialize(emit, initialLanguage: event.initialLanguage);
  }

  /// Bật nhận dạng; không được thì phân biệt micro bị tắt quyền với máy không hỗ trợ.
  Future<void> _initialize(
    Emitter<VoiceRequestState> emit, {
    String? initialLanguage,
  }) async {
    final ok = await _speech.initialize(
      onStatus: (status) {
        if (!isClosed) add(_VoiceRequestStatusChanged(status));
      },
      onError: (error) {
        if (!isClosed) add(_VoiceRequestErrorReceived(error));
      },
    );
    if (!ok) {
      final blocked = await _permission.isBlocked();
      emit(
        state.copyWith(
          status: VoiceRequestStatus.unavailable,
          problem: blocked
              ? VoiceRequestProblem.micOff
              : VoiceRequestProblem.unavailable,
        ),
      );
      return;
    }
    if (state.languages.isEmpty) {
      final locales = await _speech.locales();
      final systemLocale = await _speech.systemLocaleId();
      _systemLanguageCode = systemLocale == null
          ? null
          : VoiceLanguageOption.appCodeForLocale(systemLocale);
      final languages = VoiceLanguageOption.fromDeviceLocales(
        locales.map((l) => l.localeId).toList(),
      );
      emit(
        state.copyWith(
          languages: languages,
          languageCode: languages.any((l) => l.code == initialLanguage)
              ? initialLanguage
              : null,
        ),
      );
    }
    emit(state.copyWith(clearProblem: true));
    await _listen(emit);
  }

  Future<void> _onRetried(
    VoiceRequestRetried event,
    Emitter<VoiceRequestState> emit,
  ) async {
    if (state.problem == null) return;
    // Bắt đầu lại sạch: bỏ chữ và voice note dở.
    await _speech.cancel();
    await _recorder.discard();
    _recordingStarted = false;
    _recorderPaused = false;
    emit(
      state.copyWith(
        status: VoiceRequestStatus.initializing,
        committedText: '',
        partialText: '',
        clearProblem: true,
      ),
    );
    await _initialize(emit);
  }

  /// Lượt nghe tự dừng: có chữ → "Got it"; không nghe được gì → màn "didn't catch that".
  void _stopListening(Emitter<VoiceRequestState> emit) {
    final next = _committed().copyWith(
      status: VoiceRequestStatus.done,
      level: 0,
    );
    emit(
      next.transcript.trim().isEmpty
          ? next.copyWith(problem: VoiceRequestProblem.noSpeech)
          : next,
    );
    _pauseRecorder();
  }

  Future<void> _listen(Emitter<VoiceRequestState> emit) async {
    emit(
      state.copyWith(
        status: VoiceRequestStatus.listening,
        partialText: '',
        level: 0,
      ),
    );
    _listenStartedAt = DateTime.now();
    try {
      await _speech.listen(
        localeId: state.selectedLanguage?.localeId,
        pauseFor: silence,
        listenFor: maxListen,
        onResult: (words, isFinal) {
          if (!isClosed) add(_VoiceRequestResultReceived(words, isFinal));
        },
        onSoundLevel: (level) {
          if (!isClosed) add(_VoiceRequestSoundLevelChanged(level));
        },
      );
      await _startOrResumeRecorder();
    } catch (e) {
      AppLogger.e('Speech listen failed', e);
      emit(_committed().copyWith(status: VoiceRequestStatus.done));
    }
  }

  // Bật ghi sau khi nhận dạng đã chiếm micro (iOS: speech_to_text cấu hình audio session).
  Future<void> _startOrResumeRecorder() async {
    if (!_recordVoiceNote) return;
    if (!_recordingStarted) {
      _recordingStarted = await _recorder.start();
      _recorderPaused = false;
    } else if (_recorderPaused) {
      await _recorder.resume();
      _recorderPaused = false;
    }
  }

  Future<void> _pauseRecorder() async {
    if (!_recordingStarted || _recorderPaused) return;
    _recorderPaused = true;
    await _recorder.pause();
  }

  /// Chốt phần đang nghe vào phần đã có.
  VoiceRequestState _committed() =>
      state.copyWith(committedText: state.transcript, partialText: '');

  void _onResult(
    _VoiceRequestResultReceived event,
    Emitter<VoiceRequestState> emit,
  ) {
    // Kết quả đến muộn sau khi người dùng đã dừng / nói lại thì bỏ qua.
    if (!state.isListening) return;
    final next = state.copyWith(partialText: event.words);
    emit(
      event.isFinal
          ? next.copyWith(committedText: next.transcript, partialText: '')
          : next,
    );
  }

  void _onStatus(
    _VoiceRequestStatusChanged event,
    Emitter<VoiceRequestState> emit,
  ) {
    if (event.status == _SpeechStatus.listening) return;
    if (DateTime.now().difference(_listenStartedAt) < _staleStatusWindow) {
      return;
    }
    // Plugin tự dừng (im lặng / hết giờ) trong lúc đang nghe.
    if (state.isListening) _stopListening(emit);
  }

  void _onError(
    _VoiceRequestErrorReceived event,
    Emitter<VoiceRequestState> emit,
  ) {
    AppLogger.w('Speech error: ${event.error}');
    final error = event.error.toLowerCase();
    // Quyền micro / nhận giọng nói bị tắt (Android `error_permission`, iOS `…_disabled`).
    if (error.contains('permission') || error.contains('disabled')) {
      emit(
        _committed().copyWith(
          status: VoiceRequestStatus.unavailable,
          level: 0,
          problem: VoiceRequestProblem.micOff,
        ),
      );
      _pauseRecorder();
      return;
    }
    if (state.isListening) _stopListening(emit);
  }

  void _onSoundLevel(
    _VoiceRequestSoundLevelChanged event,
    Emitter<VoiceRequestState> emit,
  ) {
    if (!state.isListening) return;
    _minLevel = math.min(_minLevel, event.level);
    _maxLevel = math.max(_maxLevel, event.level);
    final range = _maxLevel - _minLevel;
    final normalized = range <= 0 ? 0.0 : (event.level - _minLevel) / range;
    emit(state.copyWith(level: normalized.clamp(0.0, 1.0)));
  }

  Future<void> _onPauseToggled(
    VoiceRequestPauseToggled event,
    Emitter<VoiceRequestState> emit,
  ) async {
    switch (state.status) {
      case VoiceRequestStatus.listening:
        emit(
          _committed().copyWith(status: VoiceRequestStatus.paused, level: 0),
        );
        await _speech.stop();
        await _pauseRecorder();
      case VoiceRequestStatus.paused:
      case VoiceRequestStatus.done:
        await _listen(emit);
      case VoiceRequestStatus.initializing:
      case VoiceRequestStatus.unavailable:
        break;
    }
  }

  Future<void> _onRestarted(
    VoiceRequestRestarted event,
    Emitter<VoiceRequestState> emit,
  ) async {
    if (state.status == VoiceRequestStatus.unavailable ||
        state.status == VoiceRequestStatus.initializing) {
      return;
    }
    emit(
      state.copyWith(
        status: VoiceRequestStatus.paused,
        committedText: '',
        partialText: '',
      ),
    );
    await _speech.cancel();
    // Nói lại từ đầu → voice note cũ cũng bỏ, ghi file mới.
    await _recorder.discard();
    _recordingStarted = false;
    await _listen(emit);
  }

  Future<void> _onLanguageSelected(
    VoiceRequestLanguageSelected event,
    Emitter<VoiceRequestState> emit,
  ) async {
    if (event.code == state.languageCode) return;
    // Đang ở màn "didn't catch that" → nghe lại bằng ngôn ngữ mới.
    final retry = state.problem == VoiceRequestProblem.noSpeech;
    final wasListening = state.isListening || retry;
    final next = _committed().copyWith(clearProblem: retry);
    emit(
      event.code == null
          ? next.copyWith(
              clearLanguage: true,
              status: VoiceRequestStatus.paused,
            )
          : next.copyWith(
              languageCode: event.code,
              status: VoiceRequestStatus.paused,
            ),
    );
    // Đổi ngôn ngữ giữa chừng: giữ chữ đã nghe, nghe tiếp bằng ngôn ngữ mới.
    if (wasListening) {
      await _speech.cancel();
      await _listen(emit);
    }
  }

  Future<void> _onSubmitted(
    VoiceRequestSubmitted event,
    Emitter<VoiceRequestState> emit,
  ) async {
    final next = _committed().copyWith(
      status: VoiceRequestStatus.paused,
      level: 0,
    );
    emit(next);
    await _speech.stop();
    final text = next.transcript.trim();
    final note = _recordingStarted ? await _recorder.stop() : null;
    _recordingStarted = false;
    // Chưa nhận ra chữ nhưng có ghi âm → vẫn đi tiếp, màn sau chuyển giọng nói qua BE.
    if (text.isEmpty && note == null) {
      emit(state.copyWith(problem: VoiceRequestProblem.noSpeech));
      return;
    }
    _handedOff = note != null;
    emit(
      state.copyWith(
        result: VoiceRequestResult(
          text: text,
          voicePath: note?.path,
          voiceDuration: note?.duration,
          languageCode: state.languageCode ?? _systemLanguageCode,
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _speech.cancel();
    if (!_handedOff) await _recorder.discard();
    return super.close();
  }
}

/// Status chuỗi của plugin `speech_to_text`.
abstract final class _SpeechStatus {
  static const listening = 'listening';
}
