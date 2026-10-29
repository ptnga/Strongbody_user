import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/streams/auth_event_bus.dart';
import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/core/services/voice_note_recorder.dart';
import 'package:strongbody_buyer/modules/chat/data/mappers/chat_mapper.dart';
import 'package:strongbody_buyer/modules/chat/data/services/chat_voice_recorder.dart';
import 'package:strongbody_buyer/modules/chat/domain/entities/chat_message_entity.dart';
import 'package:strongbody_buyer/modules/chat/domain/entities/chat_session_entity.dart';
import 'package:strongbody_buyer/modules/chat/domain/entities/chat_timetoken.dart';
import 'package:strongbody_buyer/modules/chat/domain/entities/conversation_entity.dart';
import 'package:strongbody_buyer/modules/chat/domain/repositories/chat_connection.dart';
import 'package:strongbody_buyer/modules/chat/domain/repositories/chat_repository.dart';
import 'package:strongbody_buyer/modules/chat/domain/usecases/chat_use_cases.dart';
import 'package:strongbody_buyer/modules/chat/presentation/bloc/chat/chat_bloc.dart';
import 'package:strongbody_buyer/modules/chat/presentation/bloc/conversations/conversations_bloc.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_badge_notifier.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_page_args.dart';

const _me = 7;
const _partner = 42;

class _Storage implements GlobalStorage {
  bool loggedIn = true;

  @override
  bool get isLoggedIn => loggedIn;
  @override
  int? get userId => loggedIn ? _me : null;
  @override
  String get locale => 'en';
  @override
  String? get userName => 'Sarah';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Prefs implements UserPreferences {
  @override
  bool get autoTranslateChats => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Connection implements ChatConnection {
  final events$ = StreamController<ChatRealtimeEvent>.broadcast();
  final sent = <String>[];
  bool? translations;
  List<ChatMessageEntity> history$ = const [];

  @override
  Stream<ChatRealtimeEvent> get events => events$.stream;

  @override
  void subscribe({required bool withTranslations}) =>
      translations = withTranslations;

  @override
  Future<ChatHistoryPage> history({String? cursor, int count = 20}) async =>
      ChatHistoryPage(messages: history$);

  @override
  Future<String> sendText(String text, {String? senderName}) async {
    if (failSend) throw Exception('network');
    sent.add(text);
    return '17300000000000099';
  }

  bool failSend = false;

  @override
  Future<void> dispose() async => events$.close();
}

class _Updates implements ChatUpdatesConnection {
  _Updates() {
    latest = this;
  }

  static _Updates? latest;
  bool disposed = false;
  final controller = StreamController<ConversationUpdate>.broadcast();

  @override
  Stream<ConversationUpdate> get updates => controller.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }
}

class _Repo implements ChatRepository {
  final connection = _Connection();
  ChatTranslationSettings? saved;
  final readCalls = <String>[];

  static const session = ChatSession(
    channelId: 'ch1',
    token: 'jwt',
    myUserId: _me,
    partner: ChatPartner(id: _partner, name: 'Minh Pham'),
  );

  @override
  Future<Either<Failure, ChatSession>> openSession(int partnerId) async =>
      const Right(session);

  @override
  ChatConnection connect(ChatSession session) => connection;

  @override
  Future<Either<Failure, ChatTranslationSettings?>> getTranslationSettings(
    String channelId,
  ) async => const Right(null);

  @override
  Future<Either<Failure, ChatTranslationSettings>> saveTranslationSettings(
    String channelId,
    ChatTranslationSettings settings,
  ) async {
    saved = settings;
    return Right(settings);
  }

  @override
  Future<Either<Failure, List<ChatTranslation>>> getTextTranslations(
    String channelId,
    List<String> messageIds,
  ) async => Right([
    for (final id in messageIds)
      ChatTranslation(
        messageId: id,
        text: 'Yes, 9 am is fine.',
        sourceLang: 'vi',
        targetLang: 'en',
      ),
  ]);

  @override
  Future<Either<Failure, List<ChatTranslation>>> getVoiceTranslations(
    List<String> messageIds,
  ) async => const Right([]);

  @override
  Future<Either<Failure, ChatReadReceipt>> markRead(
    String channelId,
    String timetoken,
  ) async {
    readCalls.add(timetoken);
    return Right(
      ChatReadReceipt(timetoken: timetoken, senderId: _me, readByPartner: true),
    );
  }

  @override
  Future<Either<Failure, List<ChatOfferEntity>>> getConversationOffers(
    String channelId,
  ) async => const Right([
    ChatOfferEntity(
      id: 1,
      title: 'Home physio',
      price: 70,
      status: 'accepted',
      paymentStatus: 'paid',
    ),
  ]);

  List<ChatOfferEntity> requestOffers = const [];

  @override
  Future<Either<Failure, List<ChatOfferEntity>>> getPartnerRequestOffers(
    int partnerId,
  ) async => Right(requestOffers);

  @override
  Future<Either<Failure, ({List<ConversationEntity> items, bool hasMore})>>
  getConversations({required int page, int limit = 10}) async => const Right((
    items: [
      ConversationEntity(
        channelId: 'a',
        partnerId: 1,
        partnerName: 'Grace Wong',
        lastTimetoken: '17300000000000001',
      ),
      ConversationEntity(
        channelId: 'b',
        partnerId: 2,
        partnerName: 'Minh Pham',
        lastTimetoken: '17300000000000000',
      ),
    ],
    hasMore: false,
  ));

  @override
  Future<Either<Failure, ChatUpdatesConnection>> connectUpdates() async {
    connectCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return Right(_Updates());
  }

  int connectCalls = 0;

  @override
  Future<Either<Failure, int>> getUnreadTotal() async => const Right(2);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recorder implements ChatVoiceRecorder {
  @override
  Future<bool> start() async => true;
  @override
  Future<VoiceNote?> stop() async => null;
  @override
  Future<void> cancel() async {}
}

ChatBloc _chatBloc(_Repo repo, ChatBadgeNotifier badge) => ChatBloc(
  args: const ChatPageArgs(partnerId: _partner),
  openSession: OpenChatSessionUseCase(repo),
  refreshSession: RefreshChatSessionUseCase(repo),
  connect: ConnectChatUseCase(repo),
  getSettings: GetTranslationSettingsUseCase(repo),
  saveSettings: SaveTranslationSettingsUseCase(repo),
  getTranslations: GetChatTranslationsUseCase(repo),
  translateText: TranslateChatTextUseCase(repo),
  sendVoice: SendChatVoiceUseCase(repo),
  markRead: MarkChatReadUseCase(repo),
  getOffers: GetChatOffersUseCase(repo),
  recorder: _Recorder(),
  badge: badge,
  storage: _Storage(),
  preferences: _Prefs(),
);

ChatMessageEntity _partnerText(String id, String text) => ChatMessageEntity(
  id: id,
  senderId: _partner,
  type: ChatMessageType.text,
  text: text,
  createdAt: ChatTimetoken.toDateTime(id),
);

void main() {
  group('ChatMapper', () {
    test('REST conversation reads nested last_message.message', () {
      final c = ChatMapper.conversation({
        'channel_id': 'ch1',
        'unread_count': 2,
        'partner': {'user_id': 42, 'name': 'Minh Pham', 'avatar': ''},
        'last_message': {
          'timetoken': '17300000000000000',
          'sender_id': 42,
          'message': {
            'type': 'voice',
            'content': '',
            'voice': {'duration': 14, 'source_lang': 'vi'},
          },
        },
      })!;
      expect(c.partnerId, 42);
      expect(c.partnerAvatar, isNull);
      expect(c.lastType, ChatMessageType.voice);
      expect(c.lastVoiceDuration, const Duration(seconds: 14));
      expect(c.lastSourceLang, 'vi');
      expect(c.unreadCount, 2);
      expect(c.lastAt!.year, greaterThan(2020));
    });

    test('channel_list_update reads flat last_message; no partner → null', () {
      final c = ChatMapper.conversationUpdate({
        'channel_id': 'ch1',
        'unread_count': 1,
        'partner': {'user_id': 42, 'name': 'Minh', 'nickname': 'Dr Minh'},
        'last_message': {
          'content': 'Hi',
          'type': 'text',
          'timetoken': '17300000000000005',
          'sender_id': 42,
        },
      })!;
      expect(c.partnerName, 'Dr Minh');
      expect(c.lastText, 'Hi');
      expect(ChatMapper.conversationUpdate({'channel_id': 'x'}), isNull);
    });

    test(
      'message payloads: text, voice, read receipts and own auto messages',
      () {
        final voice = ChatMapper.message(
          timetoken: '17300000000000010',
          publisher: '42',
          payload: {
            'type': 'voice',
            'uuid': 42,
            'voice': {
              'audio_url': 'https://cdn/v.wav',
              'gcs_path': 'gs://v',
              'source_lang': 'vi',
              'text': 'Vâng 9 giờ được',
              'duration': 7,
            },
          },
          myUserId: _me,
        )!;
        expect(voice.voice!.url, 'https://cdn/v.wav');
        expect(voice.voice!.transcript, 'Vâng 9 giờ được');
        expect(voice.voice!.duration, const Duration(seconds: 7));

        final text = ChatMapper.message(
          timetoken: '17300000000000011',
          publisher: '7',
          payload: '{"type":"text","content":"hi","uuid":7}',
          myUserId: _me,
        )!;
        expect(text.senderId, _me);
        expect(text.text, 'hi');

        expect(
          ChatMapper.message(
            timetoken: '1',
            publisher: '7',
            payload: {'type': 'read'},
            myUserId: _me,
          ),
          isNull,
        );
        expect(
          ChatMapper.message(
            timetoken: '1',
            publisher: '7',
            payload: {
              'type': 'text',
              'uuid': 7,
              'content': 'auto',
              'metadata': {'is_auto_message': true},
            },
            myUserId: _me,
          ),
          isNull,
        );
      },
    );

    test(
      'request offers keep only this provider and read Request schedule',
      () {
        final offers = ChatMapper.requestOffers({
          'list': [
            {
              'id': 1,
              'seller_id': 42,
              'request_id': 5,
              'status': 'pending',
              'Request': {
                'id': 5,
                'deadline': '2030-01-05T02:00:00Z',
                'delivery_type': 'at_home',
              },
            },
            {'id': 2, 'seller_id': 99, 'request_id': 5},
            {'id': 3, 'seller_id': 42},
          ],
        }, sellerId: 42);
        expect(offers.map((o) => o.id), [1]);
        expect(offers.single.deliveryType, 'at_home');
        expect(offers.single.scheduledAt, isNotNull);
      },
    );

    test('session, translations, receipt, offers', () {
      final session = ChatMapper.session({
        'channel_id': 'ch1',
        'token': 'jwt',
        'user_id': 7,
        'partner': {'user_id': 42, 'first_name': 'Minh', 'last_name': 'Pham'},
      }, myUserId: 7)!;
      expect(session.partner.name, 'Minh Pham');
      expect(ChatMapper.session({'channel_id': 'x'}, myUserId: 7), isNull);

      expect(
        ChatMapper.textTranslation({
          'message_timetoken': '1',
          'translated_message': 'Hello',
          'source_lang': 'vi',
        })!.text,
        'Hello',
      );
      expect(
        ChatMapper.voiceTranslation({
          'type': 'voice_translation',
          'message_timetoken': '1',
          'translated_url': 'https://t.wav',
        })!.audioUrl,
        'https://t.wav',
      );
      expect(
        ChatMapper.readReceipt({
          'timetoken': '5',
          'sender_id': 7,
          'read_by': [
            {'user_id': 7},
            {'user_id': 42},
          ],
        }, myUserId: 7)!.readByPartner,
        isTrue,
      );
      final offer = ChatMapper.conversationOffers({
        'list': [
          {
            'id': 3,
            'title': 'Physio',
            'price': 70,
            'status': 'accepted',
            'payment_status': 'paid',
          },
        ],
      }).single;
      expect(offer.isPaid, isTrue);
    });

    test('timetoken round trip keeps 17 digits', () {
      final tt = ChatTimetoken.fromDateTime(DateTime(2026, 10, 27, 9, 30));
      expect(tt.length, 17);
      expect(ChatTimetoken.toDateTime(tt), DateTime(2026, 10, 27, 9, 30));
    });
  });

  group('ChatBloc', () {
    test('provider offers for my requests become offer cards + strip', () async {
      final repo = _Repo();
      repo.connection.history$ = [_partnerText('17300000000000002', 'Hi')];
      repo.requestOffers = [
        ChatOfferEntity(
          id: 9,
          title: 'Physio',
          price: 70,
          status: 'accepted',
          paymentStatus: 'paid',
          sellerId: _partner,
          requestId: 5,
          createdAt: DateTime(2030, 1, 1),
          scheduledAt: DateTime(2030, 1, 5, 9),
          deliveryType: 'at_home',
        ),
      ];
      final badge = ChatBadgeNotifier(
        getUnreadTotal: GetChatUnreadTotalUseCase(repo),
        storage: _Storage(),
      );
      final bloc = _chatBloc(repo, badge)..add(const ChatStarted());
      final ready = await bloc.stream.firstWhere(
        (s) => s.status == ChatStatus.ready && s.readReceipt != null,
      );
      final card = ready.messages.first;
      expect(card.isLocal, isTrue);
      expect(card.type, ChatMessageType.offer);
      expect(card.senderId, _partner);
      expect(card.offer!.requestId, 5);
      expect(ready.offer!.id, 9);
      // Đánh dấu đã đọc tin thật mới nhất, không phải thẻ offer chèn trên máy.
      expect(repo.readCalls, ['17300000000000002']);
      await bloc.close();
      badge.dispose();
    });

    test('opens, loads history + offer, marks newest read', () async {
      final repo = _Repo();
      repo.connection.history$ = [_partnerText('17300000000000002', 'Vâng')];
      final badge = ChatBadgeNotifier(
        getUnreadTotal: GetChatUnreadTotalUseCase(repo),
        storage: _Storage(),
      );
      final bloc = _chatBloc(repo, badge)..add(const ChatStarted());
      final ready = await bloc.stream.firstWhere(
        (s) => s.status == ChatStatus.ready && s.readReceipt != null,
      );
      expect(ready.messages, hasLength(1));
      expect(ready.offer!.isPaid, isTrue);
      expect(repo.connection.translations, isFalse);
      expect(repo.readCalls, ['17300000000000002']);
      await bloc.close();
      badge.dispose();
    });

    test('send failure: pending bubble removed + sendFailed notice', () async {
      final repo = _Repo();
      repo.connection.failSend = true;
      final badge = ChatBadgeNotifier(
        getUnreadTotal: GetChatUnreadTotalUseCase(repo),
        storage: _Storage(),
      );
      final bloc = _chatBloc(repo, badge)..add(const ChatStarted());
      await bloc.stream.firstWhere((s) => s.status == ChatStatus.ready);
      bloc.add(const ChatTextSent('Hello?'));
      final failed = await bloc.stream.firstWhere(
        (s) => s.notice == ChatNotice.sendFailed,
      );
      expect(failed.messages.where((m) => m.isPending), isEmpty);
      expect(failed.messages.where((m) => m.text == 'Hello?'), isEmpty);

      // Tin rỗng / chỉ khoảng trắng không gửi.
      repo.connection.failSend = false;
      bloc.add(const ChatTextSent('   '));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repo.connection.sent, isEmpty);
      await bloc.close();
      badge.dispose();
    });

    test(
      'text send is optimistic, takes server timetoken, echo deduped',
      () async {
        final repo = _Repo();
        final badge = ChatBadgeNotifier(
          getUnreadTotal: GetChatUnreadTotalUseCase(repo),
          storage: _Storage(),
        );
        final bloc = _chatBloc(repo, badge)..add(const ChatStarted());
        await bloc.stream.firstWhere((s) => s.status == ChatStatus.ready);

        bloc.add(const ChatTextSent('Hi Minh'));
        final sent = await bloc.stream.firstWhere(
          (s) => s.messages.isNotEmpty && !s.messages.first.isPending,
        );
        expect(sent.messages.single.id, '17300000000000099');
        expect(repo.connection.sent, ['Hi Minh']);

        repo.connection.events$.add(
          ChatMessageArrived(
            ChatMessageEntity(
              id: '17300000000000099',
              senderId: _me,
              type: ChatMessageType.text,
              text: 'Hi Minh',
              createdAt: DateTime.now(),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(bloc.state.messages, hasLength(1));
        await bloc.close();
        badge.dispose();
      },
    );

    test(
      'turning translation on subscribes side channels and loads translations',
      () async {
        final repo = _Repo();
        repo.connection.history$ = [_partnerText('17300000000000003', 'Vâng')];
        final badge = ChatBadgeNotifier(
          getUnreadTotal: GetChatUnreadTotalUseCase(repo),
          storage: _Storage(),
        );
        final bloc = _chatBloc(repo, badge)..add(const ChatStarted());
        await bloc.stream.firstWhere((s) => s.status == ChatStatus.ready);

        bloc.add(const ChatTranslateToggled());
        final on = await bloc.stream.firstWhere(
          (s) => s.translations.isNotEmpty,
        );
        expect(on.autoTranslate, isTrue);
        expect(repo.saved!.targetLanguage, 'en');
        expect(repo.connection.translations, isTrue);
        expect(on.translations['17300000000000003']!.sourceLang, 'vi');
        expect(on.partnerLanguage, 'vi');

        bloc.add(const ChatOriginalToggled('17300000000000003'));
        final original = await bloc.stream.firstWhere(
          (s) => s.showOriginal.isNotEmpty,
        );
        expect(original.showOriginal, {'17300000000000003'});
        await bloc.close();
        badge.dispose();
      },
    );
  });

  test('ConversationsBloc upserts realtime update to the top', () async {
    final repo = _Repo();
    final badge = ChatBadgeNotifier(
      getUnreadTotal: GetChatUnreadTotalUseCase(repo),
      storage: _Storage(),
    );
    final bloc = ConversationsBloc(
      getConversations: GetConversationsUseCase(repo),
      searchUsers: SearchChatUsersUseCase(repo),
      connectUpdates: ConnectChatUpdatesUseCase(repo),
      badge: badge,
      storage: _Storage(),
    )..add(const ConversationsStarted());
    await bloc.stream.firstWhere((s) => s.items.length == 2);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    _Updates.latest!.controller.add(
      const ConversationChanged(
        ConversationEntity(
          channelId: 'b',
          partnerId: 2,
          partnerName: 'Minh Pham',
          lastText: 'New',
          lastTimetoken: '17300000000000009',
          unreadCount: 1,
        ),
      ),
    );
    final updated = await bloc.stream.firstWhere(
      (s) => s.items.first.channelId == 'b',
    );
    expect(updated.items.first.lastText, 'New');
    expect(updated.items, hasLength(2));

    bloc.add(const ConversationsQueryChanged('grace'));
    final filtered = await bloc.stream.firstWhere((s) => s.query == 'grace');
    expect(filtered.visibleItems.single.partnerName, 'Grace Wong');
    await bloc.close();
    badge.dispose();
  });

  test(
    'ConversationsBloc: overlapping Started opens one socket; logout wipes the list',
    () async {
      final repo = _Repo();
      final storage = _Storage();
      final badge = ChatBadgeNotifier(
        getUnreadTotal: GetChatUnreadTotalUseCase(repo),
        storage: storage,
      );
      final bloc =
          ConversationsBloc(
              getConversations: GetConversationsUseCase(repo),
              searchUsers: SearchChatUsersUseCase(repo),
              connectUpdates: ConnectChatUpdatesUseCase(repo),
              badge: badge,
              storage: storage,
            )
            ..add(const ConversationsStarted())
            ..add(const ConversationsStarted());
      await bloc.stream.firstWhere((s) => s.items.length == 2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.connectCalls, 1);
      final socket = _Updates.latest!;

      // Đăng xuất ở tab khác (tab Messages vẫn sống).
      storage.loggedIn = false;
      AuthEventBus.emit(const UserLoggedOut());
      final out = await bloc.stream.firstWhere(
        (s) => s.status == ConversationsStatus.signedOut,
      );
      expect(out.items, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(socket.disposed, isTrue);

      // Người khác đăng nhập → kênh realtime mới.
      storage.loggedIn = true;
      AuthEventBus.emit(const UserLoggedIn());
      await bloc.stream.firstWhere((s) => s.items.length == 2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.connectCalls, 2);
      await bloc.close();
      badge.dispose();
    },
  );
}
