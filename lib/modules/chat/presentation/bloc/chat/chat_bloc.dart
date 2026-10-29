import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/core/utils/app_logger.dart';

import '../../../data/services/chat_voice_recorder.dart';
import '../../../domain/entities/chat_message_entity.dart';
import '../../../domain/entities/chat_session_entity.dart';
import '../../../domain/entities/chat_timetoken.dart';
import '../../../domain/repositories/chat_connection.dart';
import '../../../domain/usecases/chat_use_cases.dart';
import '../../chat_badge_notifier.dart';
import '../../chat_page_args.dart';

part 'chat_event.dart';
part 'chat_state.dart';

/// Chat 1:1 — luồng Multime `ChatBloc`: `/user/chat-server/create` → WS + `/v3/history`,
/// gửi text (publish REST) / voice (`/user/chat-server/voice`), dịch tự động theo hội thoại,
/// đánh dấu đã đọc (`/user/mark-read-and-status`). Token hết hạn → refresh rồi thử lại 1 lần.
class ChatBloc extends BlocWithApi<ChatEvent, ChatState> {
  final ChatPageArgs args;
  final OpenChatSessionUseCase _openSession;
  final RefreshChatSessionUseCase _refreshSession;
  final ConnectChatUseCase _connect;
  final GetTranslationSettingsUseCase _getSettings;
  final SaveTranslationSettingsUseCase _saveSettings;
  final GetChatTranslationsUseCase _getTranslations;
  final TranslateChatTextUseCase _translateText;
  final SendChatVoiceUseCase _sendVoice;
  final MarkChatReadUseCase _markRead;
  final GetChatOffersUseCase _getOffers;
  final ChatVoiceRecorder _recorder;
  final ChatBadgeNotifier _badge;
  final GlobalStorage _storage;
  final UserPreferences _preferences;

  ChatConnection? _connection;
  StreamSubscription<ChatRealtimeEvent>? _connectionSub;
  Timer? _recordTimer;
  Timer? _markReadTimer;

  /// Gia hạn phiên đang chạy — history 401, WS 4401, gửi tin lỗi dùng chung một lượt.
  Future<ChatSession?>? _renewing;
  ChatSession? _latestSession;
  int _renewals = 0;

  /// Server từ chối mãi (4403, sai uuid) → dừng thay vì gia hạn + kết nối lại liên tục.
  static const _maxRenewals = 3;

  /// Bấm mic / gửi voice hai lần (events chạy song song) → chỉ một lượt.
  bool _recordStarting = false;
  bool _recordFinishing = false;

  static const _firstPage = 20;
  static const _olderPage = 50;

  ChatBloc({
    required this.args,
    required OpenChatSessionUseCase openSession,
    required RefreshChatSessionUseCase refreshSession,
    required ConnectChatUseCase connect,
    required GetTranslationSettingsUseCase getSettings,
    required SaveTranslationSettingsUseCase saveSettings,
    required GetChatTranslationsUseCase getTranslations,
    required TranslateChatTextUseCase translateText,
    required SendChatVoiceUseCase sendVoice,
    required MarkChatReadUseCase markRead,
    required GetChatOffersUseCase getOffers,
    required ChatVoiceRecorder recorder,
    required ChatBadgeNotifier badge,
    required GlobalStorage storage,
    required UserPreferences preferences,
  }) : _openSession = openSession,
       _refreshSession = refreshSession,
       _connect = connect,
       _getSettings = getSettings,
       _saveSettings = saveSettings,
       _getTranslations = getTranslations,
       _translateText = translateText,
       _sendVoice = sendVoice,
       _markRead = markRead,
       _getOffers = getOffers,
       _recorder = recorder,
       _badge = badge,
       _storage = storage,
       _preferences = preferences,
       super(const ChatState()) {
    on<ChatStarted>(_onStarted);
    on<ChatOlderRequested>(_onOlder);
    on<ChatTextSent>(_onTextSent);
    on<ChatRecordStarted>(_onRecordStarted);
    on<ChatRecordCancelled>(_onRecordCancelled);
    on<ChatRecordFinished>(_onRecordFinished);
    on<ChatTranslateToggled>(_onTranslateToggled);
    on<ChatOriginalToggled>(_onOriginalToggled);
    on<_ChatRealtimeReceived>(_onRealtime);
    on<_ChatRecordTicked>(_onRecordTicked);
    on<_ChatMarkReadDue>((event, emit) => _markNewestRead(emit));
  }

  int get _me => state.session?.myUserId ?? _storage.userId ?? 0;

  /// Ngôn ngữ mình muốn đọc = ngôn ngữ app.
  String get _myLanguage => _storage.locale;

  // ---------------------------------------------------------------- mở kênh

  Future<void> _onStarted(ChatStarted event, Emitter<ChatState> emit) async {
    if (!_storage.isLoggedIn) {
      emit(state.copyWith(status: ChatStatus.signedOut));
      return;
    }
    emit(state.copyWith(status: ChatStatus.connecting));
    final opened = await _openSession(args.partnerId);
    if (isClosed) return;
    final session = opened.toNullable();
    if (session == null) {
      emit(state.copyWith(status: ChatStatus.failure));
      return;
    }
    await _attach(session);
    emit(state.copyWith(session: session));

    // Chạy song song (tạo Future trước rồi mới await).
    final settingsFuture = _getSettings(session.channelId);
    final pageFuture = _historyPage(null, _firstPage);
    final offersFuture = _getOffers((
      channelId: session.channelId,
      partnerId: session.partner.id,
    ));
    final settings = (await settingsFuture).toNullable();
    final page = await pageFuture;
    final offers = (await offersFuture).toNullable();
    if (isClosed) return;

    _connection?.subscribe(withTranslations: settings?.autoTranslate ?? false);
    emit(
      state.copyWith(
        status: page == null && state.messages.isEmpty
            ? ChatStatus.failure
            : ChatStatus.ready,
        settings:
            settings ??
            ChatTranslationSettings(
              autoTranslate: false,
              targetLanguage: _myLanguage,
            ),
        messages: page == null
            ? null
            : _withOfferCards(page.messages, offers ?? const [], session),
        historyCursor: page?.nextCursor,
        clearCursor: page != null && page.nextCursor == null,
        offer: _stripOffer(offers ?? const []),
      ),
    );
    await _markNewestRead(emit);
    if (state.autoTranslate) {
      await _loadTranslations(emit, state.messages);
    } else if (settings == null && _preferences.autoTranslateChats) {
      // Hội thoại chưa có cài đặt + Account bật "Auto-translate messages" (đã đồng ý).
      add(const ChatTranslateToggled());
    }
  }

  /// Offer ở dải đầu chat: offer được "Reply" tới (nếu có), không thì mới nhất.
  ChatOfferEntity? _stripOffer(List<ChatOfferEntity> offers) {
    final focus = args.focusOfferId;
    return offers.where((o) => o.id == focus).firstOrNull ?? offers.firstOrNull;
  }

  /// Offer provider gửi cho request của mình không có trên chat-server → chèn thẻ offer
  /// vào đúng thời điểm gửi (bỏ qua offer đã có tin `type: offer` trong kênh).
  static List<ChatMessageEntity> _withOfferCards(
    List<ChatMessageEntity> messages,
    List<ChatOfferEntity> offers,
    ChatSession session,
  ) {
    final inChat = {
      for (final m in messages)
        if (m.offer != null) m.offer!.id,
    };
    final cards = [
      for (final offer in offers)
        if (offer.requestId != null && !inChat.contains(offer.id))
          ChatMessageEntity(
            id: ChatTimetoken.fromDateTime(offer.createdAt ?? DateTime.now()),
            senderId: session.partner.id,
            type: ChatMessageType.offer,
            offer: offer,
            createdAt: offer.createdAt ?? DateTime.now(),
            isLocal: true,
          ),
    ];
    if (cards.isEmpty) return messages;
    return [...messages, ...cards]..sort((a, b) => b.id.compareTo(a.id));
  }

  Future<void> _attach(ChatSession session) async {
    await _connectionSub?.cancel();
    await _connection?.dispose();
    final connection = _connect(session);
    _connection = connection;
    _connectionSub = connection.events.listen(
      (e) => add(_ChatRealtimeReceived(e)),
    );
    connection.subscribe(withTranslations: state.autoTranslate);
  }

  /// Token chat-server hết hạn → JWT mới (refresh / tạo lại) + kết nối lại.
  Future<bool> _renewSession(Emitter<ChatState> emit) async {
    final renewed = await _renew();
    if (renewed == null) return false;
    if (!emit.isDone && !isClosed) emit(state.copyWith(session: renewed));
    return true;
  }

  Future<ChatSession?> _renew() {
    final session = _latestSession ?? state.session;
    if (session == null || isClosed) return Future.value();
    return _renewing ??= _doRenew(session).whenComplete(() => _renewing = null);
  }

  Future<ChatSession?> _doRenew(ChatSession session) async {
    if (_renewals >= _maxRenewals) return null;
    _renewals++;
    final renewed = (await _refreshSession(session)).toNullable();
    // Bloc đóng trong lúc chờ → không mở kết nối mới (sự kiện sẽ add vào bloc đã đóng).
    if (renewed == null || isClosed) return null;
    _latestSession = renewed;
    await _attach(renewed);
    return renewed;
  }

  static bool _isAuthError(Object e) {
    final text = e.toString().toLowerCase();
    return const [
      'token is expired',
      'invalid_token',
      'missing_token',
      'forbidden',
      '403',
      '401',
      'token_revoked',
      'uuid does not match',
      'permission denied',
    ].any(text.contains);
  }

  Future<ChatHistoryPage?> _historyPage(String? cursor, int count) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final connection = _connection;
      if (connection == null) return null;
      try {
        return await connection.history(cursor: cursor, count: count);
      } catch (e) {
        AppLogger.w('Chat history failed', e);
        if (attempt == 0 && _isAuthError(e) && await _renew() != null) {
          continue;
        }
        return null;
      }
    }
    return null;
  }

  Future<void> _onOlder(
    ChatOlderRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (!state.hasOlder || state.loadingOlder) return;
    emit(state.copyWith(loadingOlder: true));
    final page = await _historyPage(state.historyCursor, _olderPage);
    if (page == null) {
      emit(state.copyWith(loadingOlder: false));
      return;
    }
    final known = state.messages.map((m) => m.id).toSet();
    final older = page.messages.where((m) => !known.contains(m.id)).toList();
    // Thẻ offer chèn trên máy (offer không có ở trang đầu) → bỏ khi tin offer thật tới.
    final realOffers = {
      for (final m in older)
        if (m.type == ChatMessageType.offer && m.offer != null) m.offer!.id,
    };
    final current = state.messages.where(
      (m) => !(m.isLocal && realOffers.contains(m.offer?.id)),
    );
    emit(
      state.copyWith(
        loadingOlder: false,
        messages: [...current, ...older]..sort((a, b) => b.id.compareTo(a.id)),
        historyCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
      ),
    );
    if (state.autoTranslate) await _loadTranslations(emit, older);
  }

  // ------------------------------------------------------------------ gửi

  void _trackSend(
    String event,
    String type, [
    Map<String, Object?> extra = const {},
  ]) => AppAnalytics.capture(event, {
    'type': type,
    'partner_id': state.session?.partner.id,
    ...extra,
  });

  Future<void> _onTextSent(ChatTextSent event, Emitter<ChatState> emit) async {
    final text = event.text.trim();
    final connection = _connection;
    if (text.isEmpty || connection == null || state.session == null) return;
    final localId = ChatTimetoken.fromDateTime(DateTime.now());
    final pending = ChatMessageEntity(
      id: localId,
      senderId: _me,
      type: ChatMessageType.text,
      text: text,
      createdAt: DateTime.now(),
      isPending: true,
    );
    emit(state.copyWith(messages: [pending, ...state.messages]));

    String? timetoken;
    for (var attempt = 0; attempt < 2 && timetoken == null; attempt++) {
      try {
        timetoken = await _connection!.sendText(
          text,
          senderName: _storage.userName,
        );
      } catch (e) {
        AppLogger.w('Chat send failed', e);
        if (attempt == 0 && _isAuthError(e) && await _renewSession(emit)) {
          continue;
        }
        break;
      }
    }
    final messages = [...state.messages];
    final index = messages.indexWhere((m) => m.id == localId);
    if (timetoken == null) {
      _trackSend(AnalyticsEvents.chatMessageFailed, 'text');
      if (index >= 0) messages.removeAt(index);
      emit(state.copyWith(messages: messages, notice: ChatNotice.sendFailed));
      return;
    }
    _trackSend(AnalyticsEvents.chatMessageSent, 'text', {
      'length': text.length,
    });
    // Giữ timetoken server để khớp echo theo id (Multime khớp theo nội dung).
    final echoed = messages.any((m) => m.id == timetoken && !m.isPending);
    if (index >= 0) {
      if (echoed) {
        messages.removeAt(index);
      } else {
        messages[index] = messages[index].copyWith(
          id: timetoken,
          isPending: false,
        );
      }
    }
    emit(state.copyWith(messages: messages));
  }

  Future<void> _onRecordStarted(
    ChatRecordStarted event,
    Emitter<ChatState> emit,
  ) async {
    if (state.recording || _recordStarting || state.session == null) return;
    _recordStarting = true;
    try {
      if (!await _recorder.start()) {
        emit(state.copyWith(notice: ChatNotice.micDenied));
        return;
      }
    } finally {
      _recordStarting = false;
    }
    emit(state.copyWith(recording: true, recordElapsed: Duration.zero));
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const _ChatRecordTicked()),
    );
  }

  void _onRecordTicked(_ChatRecordTicked event, Emitter<ChatState> emit) {
    if (!state.recording) return;
    final elapsed = state.recordElapsed + const Duration(seconds: 1);
    emit(state.copyWith(recordElapsed: elapsed));
    if (elapsed >= ChatVoiceRecorder.maxDuration) {
      add(const ChatRecordFinished());
    }
  }

  Future<void> _onRecordCancelled(
    ChatRecordCancelled event,
    Emitter<ChatState> emit,
  ) async {
    _recordTimer?.cancel();
    await _recorder.cancel();
    emit(state.copyWith(recording: false, recordElapsed: Duration.zero));
  }

  Future<void> _onRecordFinished(
    ChatRecordFinished event,
    Emitter<ChatState> emit,
  ) async {
    if (!state.recording || _recordFinishing) return;
    _recordFinishing = true;
    _recordTimer?.cancel();
    final note = await _recorder.stop();
    emit(state.copyWith(recording: false, recordElapsed: Duration.zero));
    _recordFinishing = false;
    final session = state.session;
    if (note == null || session == null) {
      emit(state.copyWith(notice: ChatNotice.voiceTooShort));
      return;
    }
    final localId = ChatTimetoken.fromDateTime(DateTime.now());
    final pending = ChatMessageEntity(
      id: localId,
      senderId: _me,
      type: ChatMessageType.voice,
      createdAt: DateTime.now(),
      voice: ChatVoice(url: note.path, duration: note.duration),
      isPending: true,
    );
    emit(state.copyWith(messages: [pending, ...state.messages]));

    try {
      await callApi(
        useCase: _sendVoice,
        param: (
          session: state.session ?? session,
          filePath: note.path,
          duration: note.duration,
        ),
        onSuccess: (sent) async {
          _trackSend(AnalyticsEvents.chatMessageSent, 'voice', {
            'duration_sec': note.duration.inSeconds,
          });
          final messages = [...state.messages];
          messages.removeWhere((m) => m.id == localId);
          // Server tự publish tin voice; echo có thể tới trước kết quả upload.
          if (!messages.any((m) => m.id == sent.id)) {
            messages
              ..insert(0, sent)
              // Tin đối phương tới trong lúc upload có thể mới hơn → giữ đúng thứ tự.
              ..sort((a, b) => b.id.compareTo(a.id));
          }
          emit(state.copyWith(messages: messages));
        },
        onFailure: (_) {
          _trackSend(AnalyticsEvents.chatMessageFailed, 'voice');
          emit(
            state.copyWith(
              messages: state.messages.where((m) => m.id != localId).toList(),
              notice: ChatNotice.voiceFailed,
            ),
          );
        },
      );
    } finally {
      try {
        final file = File(note.path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------------ dịch

  Future<void> _onTranslateToggled(
    ChatTranslateToggled event,
    Emitter<ChatState> emit,
  ) async {
    final session = state.session;
    if (session == null || state.savingSettings) return;
    final enable = !state.autoTranslate;
    emit(state.copyWith(savingSettings: true));
    await callApi(
      useCase: _saveSettings,
      param: (
        channelId: session.channelId,
        settings: ChatTranslationSettings(
          autoTranslate: enable,
          targetLanguage: _myLanguage,
        ),
      ),
      onSuccess: (settings) async {
        AppAnalytics.capture(AnalyticsEvents.chatAutoTranslateToggled, {
          'enabled': settings.autoTranslate,
        });
        _connection?.subscribe(withTranslations: settings.autoTranslate);
        emit(
          state.copyWith(
            settings: settings,
            savingSettings: false,
            translations: settings.autoTranslate ? null : const {},
            showOriginal: const {},
          ),
        );
        if (settings.autoTranslate) {
          await _loadTranslations(emit, state.messages);
        }
      },
      onFailure: (_) => emit(
        state.copyWith(
          savingSettings: false,
          notice: ChatNotice.translateFailed,
        ),
      ),
    );
  }

  void _onOriginalToggled(ChatOriginalToggled event, Emitter<ChatState> emit) {
    final next = {...state.showOriginal};
    if (!next.remove(event.messageId)) next.add(event.messageId);
    emit(state.copyWith(showOriginal: next));
  }

  /// Bản dịch đã có cho tin của partner chưa có bản dịch (Multime chỉ dịch tin partner).
  Future<void> _loadTranslations(
    Emitter<ChatState> emit,
    List<ChatMessageEntity> messages,
  ) async {
    final session = state.session;
    if (session == null) return;
    final partner = messages
        .where(
          (m) =>
              m.senderId != session.myUserId &&
              !state.translations.containsKey(m.id),
        )
        .toList();
    final textIds = partner
        .where(
          (m) =>
              m.type == ChatMessageType.text ||
              (m.voice?.transcript?.isNotEmpty ?? false),
        )
        .map((m) => m.id)
        .toList();
    final voiceIds = partner
        .where((m) => m.type == ChatMessageType.voice)
        .map((m) => m.id)
        .toList();
    if (textIds.isEmpty && voiceIds.isEmpty) return;
    await callApi(
      useCase: _getTranslations,
      param: (
        channelId: session.channelId,
        textIds: textIds,
        voiceIds: voiceIds,
      ),
      onSuccess: (list) async {
        if (list.isEmpty || emit.isDone) return;
        emit(state.copyWith(translations: _merged(list)));
      },
      onFailure: (_) {},
    );
  }

  Map<String, ChatTranslation> _merged(Iterable<ChatTranslation> list) {
    final map = {...state.translations};
    for (final t in list) {
      // Bản "dịch" cùng ngôn ngữ với bản gốc thì bỏ.
      if (t.sourceLang != null && t.sourceLang == t.targetLang) continue;
      map[t.messageId] = map[t.messageId]?.merge(t) ?? t;
    }
    return map;
  }

  /// Bản chép lời voice mới của partner → dịch text (server chỉ dịch audio).
  Future<void> _translateTranscript(
    Emitter<ChatState> emit,
    ChatMessageEntity message,
  ) async {
    final session = state.session;
    final transcript = message.voice?.transcript;
    final source = message.voice?.sourceLang;
    if (session == null || transcript == null || transcript.isEmpty) return;
    if (source != null && source == _myLanguage) return;
    await callApi(
      useCase: _translateText,
      param: (
        channelId: session.channelId,
        messageId: message.id,
        text: transcript,
        targetLanguage: _myLanguage,
      ),
      onSuccess: (t) async {
        if (emit.isDone) return;
        emit(
          state.copyWith(
            translations: _merged([
              ChatTranslation(
                messageId: t.messageId,
                text: t.text,
                sourceLang: t.sourceLang ?? source,
                targetLang: t.targetLang,
              ),
            ]),
          ),
        );
      },
      onFailure: (_) {},
    );
  }

  // ------------------------------------------------------------- realtime

  Future<void> _onRealtime(
    _ChatRealtimeReceived event,
    Emitter<ChatState> emit,
  ) async {
    switch (event.event) {
      case ChatMessageArrived(:final message):
        // Kết nối đang chạy tốt → cho phép gia hạn lại khi token hết hạn lần sau.
        _renewals = 0;
        _upsertArrived(emit, message);
        if (message.senderId != _me) {
          _scheduleMarkRead();
          if (state.autoTranslate && message.type == ChatMessageType.voice) {
            await _translateTranscript(emit, message);
          }
        }
      case ChatMessageEdited(:final message):
        final messages = [...state.messages];
        final index = messages.indexWhere((m) => m.id == message.id);
        if (index >= 0) {
          messages[index] = messages[index].copyWith(
            offer: message.offer,
            voice: message.voice,
          );
          emit(
            state.copyWith(
              messages: messages,
              offer: message.offer?.id == state.offer?.id
                  ? message.offer
                  : null,
            ),
          );
        }
      case ChatTranslationArrived(:final translation):
        emit(state.copyWith(translations: _merged([translation])));
      case ChatAccessDenied():
        if (await _renewSession(emit)) await _catchUp(emit);
      case ChatReconnected():
        await _catchUp(emit);
    }
  }

  /// Tin tới trong lúc mất kết nối / đổi token không qua WS → lấy trang mới nhất,
  /// chèn tin còn thiếu.
  Future<void> _catchUp(Emitter<ChatState> emit) async {
    final page = await _historyPage(null, _firstPage);
    if (page == null || emit.isDone) return;
    final known = {for (final m in state.messages) m.id};
    for (final message in page.messages) {
      if (!known.contains(message.id)) _upsertArrived(emit, message);
    }
  }

  void _upsertArrived(Emitter<ChatState> emit, ChatMessageEntity message) {
    final messages = [...state.messages];
    var index = messages.indexWhere((m) => m.id == message.id);
    if (index < 0 && message.senderId == _me) {
      // Echo của tin mình đang gửi (text cùng nội dung / voice đang tải lên).
      index = messages.indexWhere(
        (m) =>
            m.isPending &&
            m.type == message.type &&
            (message.type == ChatMessageType.voice || m.text == message.text),
      );
    }
    if (index >= 0) {
      messages[index] = message;
    } else {
      messages.insert(0, message);
      messages.sort((a, b) => b.id.compareTo(a.id));
    }
    emit(state.copyWith(messages: messages));
  }

  // ------------------------------------------------------------- đã đọc

  /// Gom nhiều tin tới liên tiếp (Multime debounce 10 s; app ngắn hơn vì màn đang mở).
  void _scheduleMarkRead() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(
      const Duration(seconds: 3),
      () => add(const _ChatMarkReadDue()),
    );
  }

  Future<void> _markNewestRead(Emitter<ChatState> emit) async {
    final session = state.session;
    final newest = state.messages
        .where((m) => !m.isPending && !m.isLocal)
        .firstOrNull;
    if (session == null || newest == null) return;
    await callApi(
      useCase: _markRead,
      param: (channelId: session.channelId, timetoken: newest.id),
      onSuccess: (receipt) async {
        if (!emit.isDone) emit(state.copyWith(readReceipt: receipt));
        _badge.refresh();
      },
      onFailure: (_) {},
    );
  }

  @override
  Future<void> close() async {
    _recordTimer?.cancel();
    _markReadTimer?.cancel();
    await _recorder.cancel();
    await _connectionSub?.cancel();
    await _connection?.dispose();
    return super.close();
  }
}
