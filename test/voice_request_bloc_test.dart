import 'package:flutter_test/flutter_test.dart';

import 'package:strongbody_buyer/core/services/microphone_permission_service.dart';
import 'package:strongbody_buyer/core/services/speech_recognition_service.dart';
import 'package:strongbody_buyer/core/services/voice_note_recorder.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/voice_language_option.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/voice_request/voice_request_bloc.dart';

class _FakeSpeech implements SpeechRecognitionService {
  _FakeSpeech({this.available = true});

  bool available;
  void Function(String error)? onError;
  static const deviceLocales = ['en_US', 'vi_VN', 'es_ES'];
  void Function(String status)? onStatus;
  void Function(String words, bool isFinal)? onResult;
  final listenLocales = <String?>[];
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    this.onStatus = onStatus;
    this.onError = onError;
    return available;
  }

  @override
  Future<List<SpeechLocale>> locales() async =>
      deviceLocales.map((id) => SpeechLocale(id, id)).toList();

  @override
  Future<void> listen({
    String? localeId,
    required void Function(String words, bool isFinal) onResult,
    required void Function(double level) onSoundLevel,
    required Duration pauseFor,
    required Duration listenFor,
  }) async {
    listenLocales.add(localeId);
    this.onResult = onResult;
  }

  @override
  Future<String?> systemLocaleId() async => 'en_US';

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> cancel() async => cancelCalls++;
}

class _FakeRecorder implements VoiceNoteRecorder {
  _FakeRecorder({this.works = true});

  final bool works;
  int starts = 0;
  int pauses = 0;
  int resumes = 0;
  int discards = 0;

  @override
  Future<bool> start() async {
    starts++;
    return works;
  }

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> resume() async => resumes++;

  @override
  Future<VoiceNote?> stop() async =>
      works ? const VoiceNote('/tmp/voice_1.m4a', Duration(seconds: 9)) : null;

  @override
  Future<void> discard() async => discards++;
}

class _FakePermission implements MicrophonePermissionService {
  _FakePermission({this.blocked = false});

  bool blocked;
  int settingsOpened = 0;

  @override
  Future<bool> isBlocked() async => blocked;

  @override
  Future<void> openSettings() async => settingsOpened++;
}

VoiceRequestBloc _bloc(
  _FakeSpeech speech, [
  _FakeRecorder? recorder,
  _FakePermission? permission,
]) => VoiceRequestBloc(
  speech: speech,
  recorder: recorder ?? _FakeRecorder(),
  permission: permission ?? _FakePermission(),
);

Future<VoiceRequestState> _until(
  VoiceRequestBloc bloc,
  bool Function(VoiceRequestState) test,
) => test(bloc.state) ? Future.value(bloc.state) : bloc.stream.firstWhere(test);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('maps device locales to app languages', () {
    final options = VoiceLanguageOption.fromDeviceLocales([
      'vi-VN',
      'en_US',
      'zh_TW',
    ]);
    expect(options.map((o) => o.code), ['en', 'vi', 'zh-TW']);
    expect(options.firstWhere((o) => o.code == 'vi').localeId, 'vi-VN');
    expect(VoiceLanguageOption.fromDeviceLocales([]).length, greaterThan(10));
  });

  test('live transcript then silence → done ("Got it")', () async {
    final speech = _FakeSpeech();
    final bloc = _bloc(speech)..add(const VoiceRequestStarted());
    await _until(bloc, (s) => s.isListening);

    speech.onResult!('I need a physio', false);
    await _until(bloc, (s) => s.transcript == 'I need a physio');
    speech.onResult!('I need a physio this weekend', true);
    await _until(
      bloc,
      (s) => s.committedText == 'I need a physio this weekend',
    );

    // Status cũ đến ngay sau khi bắt đầu nghe bị bỏ qua; sau khoảng chờ thì nhận.
    await Future<void>.delayed(const Duration(milliseconds: 650));
    speech.onStatus!('notListening');
    final done = await _until(bloc, (s) => s.status == VoiceRequestStatus.done);
    expect(done.transcript, 'I need a physio this weekend');
    await bloc.close();
  });

  test('pause keeps text, resume appends new words', () async {
    final speech = _FakeSpeech();
    final bloc = _bloc(speech)..add(const VoiceRequestStarted());
    await _until(bloc, (s) => s.isListening);
    speech.onResult!('Yoga teacher', false);
    await _until(bloc, (s) => s.transcript == 'Yoga teacher');

    bloc.add(const VoiceRequestPauseToggled());
    await _until(bloc, (s) => s.status == VoiceRequestStatus.paused);
    await _settle();
    expect(speech.stopCalls, 1);

    bloc.add(const VoiceRequestPauseToggled());
    await _until(bloc, (s) => s.isListening);
    speech.onResult!('for beginners', false);
    final resumed = await _until(bloc, (s) => s.partialText == 'for beginners');
    expect(resumed.transcript, 'Yoga teacher for beginners');
    await bloc.close();
  });

  test('start over clears transcript', () async {
    final speech = _FakeSpeech();
    final bloc = _bloc(speech)..add(const VoiceRequestStarted());
    await _until(bloc, (s) => s.isListening);
    speech.onResult!('wrong words', true);
    await _until(bloc, (s) => s.transcript == 'wrong words');

    bloc.add(const VoiceRequestRestarted());
    await _until(bloc, (s) => s.isListening && s.transcript.isEmpty);
    await _settle();
    expect(speech.listenLocales.length, 2);
    await bloc.close();
  });

  test('choosing a language restarts listening with its locale', () async {
    final speech = _FakeSpeech();
    final bloc = _bloc(speech)..add(const VoiceRequestStarted());
    await _until(bloc, (s) => s.isListening);
    expect(speech.listenLocales.single, isNull); // Auto-detect

    bloc.add(const VoiceRequestLanguageSelected('vi'));
    await _until(bloc, (s) => s.languageCode == 'vi' && s.isListening);
    await _settle();
    expect(speech.listenLocales.last, 'vi_VN');
    expect(bloc.state.selectedLanguage?.nativeName, 'Tiếng Việt');

    bloc.add(const VoiceRequestLanguageSelected(null));
    await _until(bloc, (s) => s.languageCode == null && s.isListening);
    await _settle();
    expect(speech.listenLocales.last, isNull);
    await bloc.close();
  });

  test(
    '✓ with nothing heard and no recording → "didn\'t catch that"',
    () async {
      final speech = _FakeSpeech();
      final bloc = _bloc(speech, _FakeRecorder(works: false))
        ..add(const VoiceRequestStarted());
      await _until(bloc, (s) => s.isListening);
      bloc.add(const VoiceRequestSubmitted());
      await _until(bloc, (s) => s.problem == VoiceRequestProblem.noSpeech);
      await bloc.close();
    },
  );

  test(
    'silence with nothing heard → noSpeech; Try again listens afresh',
    () async {
      final speech = _FakeSpeech();
      final recorder = _FakeRecorder();
      final bloc = _bloc(speech, recorder)..add(const VoiceRequestStarted());
      await _until(bloc, (s) => s.isListening);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      speech.onStatus!('done');
      await _until(bloc, (s) => s.problem == VoiceRequestProblem.noSpeech);

      bloc.add(const VoiceRequestRetried());
      final again = await _until(
        bloc,
        (s) => s.isListening && s.problem == null,
      );
      expect(again.transcript, isEmpty);
      expect(recorder.discards, 1);
      expect(speech.listenLocales, hasLength(2));
      await bloc.close();
    },
  );

  test(
    'microphone blocked → micOff; granted in Settings → listening',
    () async {
      final speech = _FakeSpeech(available: false);
      final permission = _FakePermission(blocked: true);
      final bloc = _bloc(speech, null, permission)
        ..add(const VoiceRequestStarted());
      await _until(bloc, (s) => s.problem == VoiceRequestProblem.micOff);

      speech.available = true;
      permission.blocked = false;
      bloc.add(const VoiceRequestRetried());
      await _until(bloc, (s) => s.isListening && s.problem == null);
      await bloc.close();
    },
  );

  test('permission error while listening → micOff', () async {
    final speech = _FakeSpeech();
    final bloc = _bloc(speech)..add(const VoiceRequestStarted());
    await _until(bloc, (s) => s.isListening);
    speech.onError!('error_permission');
    await _until(bloc, (s) => s.problem == VoiceRequestProblem.micOff);
    await bloc.close();
  });

  test('✓ returns transcript + voice note + detected language', () async {
    final speech = _FakeSpeech();
    final recorder = _FakeRecorder();
    final bloc = _bloc(speech, recorder)..add(const VoiceRequestStarted());
    await _until(bloc, (s) => s.isListening);
    await _settle();
    expect(recorder.starts, 1);

    speech.onResult!('Nutrition plan to lose 5 kg', false);
    await _until(bloc, (s) => s.transcript.isNotEmpty);
    bloc.add(const VoiceRequestSubmitted());
    final submitted = await _until(bloc, (s) => s.result != null);
    expect(submitted.result!.text, 'Nutrition plan to lose 5 kg');
    expect(submitted.result!.voicePath, '/tmp/voice_1.m4a');
    expect(submitted.result!.voiceDuration, const Duration(seconds: 9));
    expect(submitted.result!.languageCode, 'en'); // Auto-detect → system en_US
    await bloc.close();
    expect(recorder.discards, 0); // voice note đã giao cho màn sau → không xoá
  });

  test('recording follows pause / resume / start over', () async {
    final speech = _FakeSpeech();
    final recorder = _FakeRecorder();
    final bloc = _bloc(speech, recorder)..add(const VoiceRequestStarted());
    await _until(bloc, (s) => s.isListening);
    await _settle();

    bloc.add(const VoiceRequestPauseToggled());
    await _until(bloc, (s) => s.status == VoiceRequestStatus.paused);
    await _settle();
    expect(recorder.pauses, 1);

    bloc.add(const VoiceRequestPauseToggled());
    await _until(bloc, (s) => s.isListening);
    await _settle();
    expect(recorder.resumes, 1);

    bloc.add(const VoiceRequestRestarted());
    await _until(bloc, (s) => s.isListening && s.transcript.isEmpty);
    await _settle();
    expect(recorder.discards, 1);
    expect(recorder.starts, 2);
    await bloc.close();
    expect(recorder.discards, 2); // đóng khi chưa gửi → xoá file
  });

  test('speech unavailable (permission fine) → unavailable', () async {
    final bloc = _bloc(_FakeSpeech(available: false))
      ..add(const VoiceRequestStarted());
    final state = await _until(
      bloc,
      (s) => s.status == VoiceRequestStatus.unavailable,
    );
    expect(state.problem, VoiceRequestProblem.unavailable);
    await bloc.close();
  });
}
