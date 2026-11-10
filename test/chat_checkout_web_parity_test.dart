import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/core/services/stripe_payment_service.dart';
import 'package:strongbody_buyer/core/services/voice_note_recorder.dart';
import 'package:strongbody_buyer/modules/account/domain/entities/account_entities.dart';
import 'package:strongbody_buyer/modules/account/domain/repositories/account_repository.dart';
import 'package:strongbody_buyer/modules/account/domain/usecases/account_use_cases.dart';
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
import 'package:strongbody_buyer/modules/chat/presentation/chat_card_pairing.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_page_args.dart';
import 'package:strongbody_buyer/modules/chat/presentation/widgets/chat_card_view.dart';
import 'package:strongbody_buyer/modules/checkout/data/datasources/remote/checkout_remote_datasource.dart';
import 'package:strongbody_buyer/modules/checkout/data/repositories/checkout_repository_impl.dart';
import 'package:strongbody_buyer/modules/checkout/domain/entities/checkout_entities.dart';
import 'package:strongbody_buyer/modules/checkout/domain/usecases/checkout_use_cases.dart';
import 'package:strongbody_buyer/modules/checkout/presentation/bloc/offer_checkout/offer_checkout_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/my_request_entity.dart';

const _me = 7;
const _partner = 42;

// ------------------------------------------------------------------ chat fakes

class _Storage implements GlobalStorage {
  @override
  bool get isLoggedIn => true;
  @override
  int? get userId => _me;
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
  bool? textChannel;
  List<ChatMessageEntity> history$ = const [];
  int failHistory = 0;
  int historyCalls = 0;

  @override
  Stream<ChatRealtimeEvent> get events => events$.stream;

  @override
  void subscribe({required bool withTranslations}) =>
      textChannel = withTranslations;

  @override
  Future<ChatHistoryPage> history({String? cursor, int count = 20}) async {
    historyCalls++;
    if (failHistory > 0) {
      failHistory--;
      throw Exception('network down');
    }
    return ChatHistoryPage(messages: history$);
  }

  @override
  Future<String> sendText(String text, {String? senderName}) async =>
      '17300000000000099';

  @override
  Future<void> dispose() async => events$.close();
}

class _Updates implements ChatUpdatesConnection {
  final controller = StreamController<ConversationUpdate>.broadcast();
  static _Updates? latest;
  _Updates() {
    latest = this;
  }

  @override
  Stream<ConversationUpdate> get updates => controller.stream;

  @override
  Future<void> dispose() => controller.close();
}

class _Repo implements ChatRepository {
  final connection = _Connection();
  final voiceRequests = <List<String>>[];
  final textRequests = <List<String>>[];
  int openFailures = 0;
  int openCalls = 0;
  List<ConversationEntity> page1 = const [];

  static const session = ChatSession(
    channelId: '7_42_one_to_one',
    token: 'jwt',
    myUserId: _me,
    partner: ChatPartner(id: _partner, name: 'Minh Pham'),
  );

  @override
  Future<Either<Failure, ChatSession>> openSession(int partnerId) async {
    openCalls++;
    if (openFailures > 0) {
      openFailures--;
      return Left(ServerFailure('createChannel failed'));
    }
    return const Right(session);
  }

  @override
  ChatConnection connect(ChatSession session) => connection;

  ChatTranslationSettings? settings;

  @override
  Future<Either<Failure, ChatTranslationSettings?>> getTranslationSettings(
    String channelId,
  ) async => Right(settings);

  @override
  Future<Either<Failure, List<ChatTranslation>>> getTextTranslations(
    String channelId,
    List<String> messageIds,
  ) async {
    textRequests.add(messageIds);
    return const Right([]);
  }

  @override
  Future<Either<Failure, List<ChatTranslation>>> getVoiceTranslations(
    List<String> messageIds,
  ) async {
    voiceRequests.add(messageIds);
    return Right([
      for (final id in messageIds)
        ChatTranslation(
          messageId: id,
          audioUrl: 'https://cdn/translated-$id.mp3',
          sourceLang: 'vi',
          targetLang: 'en',
        ),
    ]);
  }

  @override
  Future<Either<Failure, ChatReadReceipt>> markRead(
    String channelId,
    String timetoken,
  ) async => Right(
    ChatReadReceipt(timetoken: timetoken, senderId: _me, readByPartner: false),
  );

  @override
  Future<Either<Failure, List<ChatOfferEntity>>> getConversationOffers(
    String channelId,
  ) async => const Right([]);

  @override
  Future<Either<Failure, List<ChatOfferEntity>>> getPartnerRequestOffers(
    int partnerId,
  ) async => const Right([]);

  @override
  Future<Either<Failure, ({List<ConversationEntity> items, bool hasMore})>>
  getConversations({required int page, int limit = 10}) async =>
      Right((items: page1, hasMore: false));

  @override
  Future<Either<Failure, ChatUpdatesConnection>> connectUpdates() async =>
      Right(_Updates());

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
  loadRetryDelay: const Duration(milliseconds: 5),
  loadTimeout: const Duration(seconds: 2),
);

ChatMessageEntity _msg(
  String id,
  ChatMessageType type, {
  int sender = _partner,
  String text = '',
  ChatVoice? voice,
  ChatCardEntity? card,
}) => ChatMessageEntity(
  id: id,
  senderId: sender,
  type: type,
  text: text,
  voice: voice,
  card: card,
  createdAt: ChatTimetoken.toDateTime(id),
);

// -------------------------------------------------------------- checkout fakes

class _CheckoutRemote implements CheckoutRemoteDataSource {
  Map<String, dynamic> offer = {'status': 'pending', 'payment_status': ''};
  Map<String, dynamic> retry = {'client_secret': 'pi_secret'};
  Map<String, dynamic>? sentBody;

  @override
  Future<List<Map<String, dynamic>>> getPaymentMethods() async => [
    {'id': 'pm_1', 'brand': 'visa', 'last4': '4242'},
  ];

  @override
  Future<String> createSetupIntent() async => 'seti';

  @override
  Future<Map<String, dynamic>> retryPayment(
    int offerId,
    Map<String, dynamic> body,
  ) async {
    sentBody = body;
    return retry;
  }

  @override
  Future<Map<String, dynamic>> getOffer(int offerId) async => offer;

  @override
  Future<String?> publicIp() async => '1.2.3.4';
}

class _Stripe implements StripePaymentService {
  @override
  Future<StripeResult> confirmWithCard({
    required String clientSecret,
    required String paymentMethodId,
  }) async => StripeResult.success;

  @override
  Future<StripeResult> addCard(String setupIntentClientSecret) async =>
      StripeResult.success;
}

class _AccountRepo implements AccountRepository {
  @override
  Future<Either<Failure, LionWallet>> getWallet() async =>
      const Right(LionWallet(id: 1, points: 0));

  @override
  Future<Either<Failure, double?>> getPointValue() async => const Right(0.01);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _offer = RequestOfferEntity(
  id: 9,
  status: 'pending',
  sellerName: 'Minh Pham',
  sellerId: _partner,
  price: 70,
);

OfferCheckoutBloc _checkoutBloc(_CheckoutRemote remote) {
  final repo = CheckoutRepositoryImpl(
    remote,
    _Stripe(),
    pollInterval: Duration.zero,
    pollAttempts: 2,
  );
  return OfferCheckoutBloc(
    offer: _offer,
    getCards: GetPaymentCardsUseCase(repo),
    addCard: AddPaymentCardUseCase(repo),
    payOffer: PayOfferUseCase(repo),
    getLionPoints: GetLionPointsUseCase(_AccountRepo()),
    getOffer: GetCheckoutOfferUseCase(repo),
  )..add(const OfferCheckoutStarted());
}

void main() {
  group('ChatMapper (web parity)', () {
    test('REST row without partner: id from channel, never my own name', () {
      final c = ChatMapper.conversation({
        'channel_id': '7_42_one_to_one',
        'last_message': {
          'timetoken': '17300000000000000',
          'sender_id': '7',
          'user_info': {'user_id': '7', 'name': 'Sarah (me)'},
          'message': {'type': 'text', 'content': 'Hi'},
        },
      }, myUserId: _me)!;
      expect(c.partnerId, _partner);
      expect(c.partnerName, isEmpty);
      expect(
        ChatMapper.conversation({
          'channel_id': 'grp_1',
          'channel_type': 'group',
          'partner': {'user_id': 1},
        }, myUserId: _me),
        isNull,
      );
    });

    test('conversations pagination like web PubnubContext', () {
      bool more(Map<String, dynamic> d, {int page = 1, int received = 10}) =>
          ChatMapper.conversationsHasMore(
            d,
            page: page,
            limit: 10,
            received: received,
          );
      expect(more({'current_page': 1, 'total_page': 3}), isTrue);
      expect(more({'current_page': 3, 'total_page': 3}), isFalse);
      expect(more({'current_page': 1, 'last_page': 1}), isFalse);
      expect(more({'total': 25}, page: 2), isTrue);
      expect(more({'total': 20}, page: 2), isFalse);
      // BE không trả phân trang → theo số dòng.
      expect(more({}, received: 10), isTrue);
      expect(more({}, received: 4), isFalse);
    });

    test('channel_list_update without partner; source/group ignored', () {
      final update = ChatMapper.conversationUpdate({
        'channel_id': '7_42_one_to_one',
        'unread_count': 3,
        'last_message': {
          'content': 'Xin chào',
          'type': 'text',
          'timetoken': '17300000000000005',
          'sender_id': 42,
          'sender_name': 'Minh Pham',
        },
      }, myUserId: _me)!;
      expect(update.partnerId, _partner);
      expect(update.partnerName, 'Minh Pham');
      expect(update.unreadCount, 3);

      final mine = ChatMapper.conversationUpdate({
        'channel_id': '7_42_one_to_one',
        'last_message': {'sender_id': 7, 'sender_name': 'Sarah'},
      }, myUserId: _me)!;
      expect(mine.partnerName, isEmpty, reason: 'sender_name là tên mình');

      expect(
        ChatMapper.conversationUpdate({
          'channel_id': '7_42_one_to_one',
          'source': 'translation',
          'last_message': {'sender_id': 42},
        }, myUserId: _me),
        isNull,
      );
      expect(
        ChatMapper.conversationUpdate({
          'channel_id': 'grp_1',
          'channel_type': 'group',
        }, myUserId: _me),
        isNull,
      );
    });

    test('card messages: request / service / public offer vs paid offer', () {
      ChatMessageEntity? map(Map<String, dynamic> payload) =>
          ChatMapper.message(
            timetoken: '17300000000000010',
            publisher: '42',
            payload: payload,
            myUserId: _me,
          );

      final request = map({
        'type': 'request',
        'uuid': 42,
        'request': {
          'id': 5,
          'description': 'Physio at home',
          'categoryName': 'Physiotherapy',
          'budget_min': 50,
          'budget_max': 80,
          'budget_currency': 'USD',
        },
      })!;
      expect(request.type, ChatMessageType.request);
      expect(request.card!.kind, ChatCardKind.request);
      expect(request.card!.categoryName, 'Physiotherapy');
      expect(ChatCardView.budget(request.card!), r'$50–$80');

      final service = map({
        'type': 'service',
        'uuid': 42,
        'service': {
          'id': 3,
          'title': 'Massage',
          'description': '<p>Deep&nbsp;tissue</p>',
          'price': 45,
          'image': ['https://cdn/a.jpg'],
        },
      })!;
      expect(service.card!.kind, ChatCardKind.service);
      expect(service.card!.image, 'https://cdn/a.jpg');
      expect(ChatCardView.plain(service.card!.description), 'Deep tissue');
      expect(ChatCardView.price(service.card!), r'$45');

      final publicOffer = map({
        'type': 'offer',
        'uuid': 7,
        'offer': {
          'id': 11,
          'type': 'offer',
          'description': 'Yoga class',
          'price': 20,
        },
      })!;
      expect(publicOffer.offer, isNull, reason: 'không có thanh toán');
      expect(publicOffer.card!.kind, ChatCardKind.publicOffer);

      final paid = map({
        'type': 'offer',
        'uuid': 42,
        'offer': {'id': 12, 'type': 'service', 'title': 'Physio', 'price': 70},
      })!;
      expect(paid.offer!.id, 12);
      expect(paid.card, isNull);
    });

    test('voice_translation type, inline translation, own auto message', () {
      final voice = ChatMapper.message(
        timetoken: '17300000000000020',
        publisher: '42',
        payload: {
          'type': 'voice_translation',
          'uuid': 42,
          'voice': {
            'audio_url': 'https://cdn/orig.mp3',
            'translation_audio_url': 'https://cdn/en.mp3',
            'translated_text': 'Hello',
            'detected_lang': 'vi',
            'target_lang': 'en',
          },
        },
        myUserId: _me,
      )!;
      expect(voice.type, ChatMessageType.voice);
      final inline = voice.voice!.inlineTranslation(voice.id)!;
      expect(inline.audioUrl, 'https://cdn/en.mp3');
      expect(inline.text, 'Hello');
      expect(inline.sourceLang, 'vi');

      expect(
        ChatMapper.message(
          timetoken: '17300000000000021',
          publisher: '7',
          payload: {
            'type': 'text',
            'uuid': 7,
            'content': 'auto',
            'is_auto_message': true,
          },
          myUserId: _me,
        ),
        isNull,
      );
    });
  });

  test('card + following text of same sender within 2 min are paired', () {
    const card = ChatCardEntity(kind: ChatCardKind.request, description: 'x');
    final messages = [
      // 130 s sau thẻ → quá 2 phút, không gộp.
      _msg('17300002300000000', ChatMessageType.text, text: 'late'),
      _msg('17300001000000000', ChatMessageType.request, card: card),
      _msg('17300000000000000', ChatMessageType.text, text: 'Hi'),
      _msg('17299999990000000', ChatMessageType.request, card: card),
      _msg('17299999980000000', ChatMessageType.text, sender: _me, text: 'x'),
      _msg('17299999970000000', ChatMessageType.request, card: card),
    ];
    final pairing = ChatCardPairing.of(messages);
    expect(pairing.attached.keys, ['17300000000000000']);
    expect(pairing.hidden, {'17299999990000000'});
  });

  test('translationFor: voice translation shows even with auto off', () {
    final voice = _msg(
      '17300000000000030',
      ChatMessageType.voice,
      voice: const ChatVoice(url: 'https://cdn/orig.mp3', sourceLang: 'vi'),
    );
    final text = _msg('17300000000000031', ChatMessageType.text, text: 'Vâng');
    final state = ChatState(
      session: _Repo.session,
      messages: [text, voice],
      translations: {
        voice.id: ChatTranslation(
          messageId: voice.id,
          audioUrl: 'https://cdn/en.mp3',
          text: 'Yes',
        ),
        text.id: ChatTranslation(messageId: text.id, text: 'Yes'),
      },
      settings: const ChatTranslationSettings(
        autoTranslate: false,
        targetLanguage: 'en',
      ),
    );
    expect(state.translationFor(voice)!.audioUrl, 'https://cdn/en.mp3');
    expect(state.translationFor(voice)!.text, isNull);
    expect(state.translationFor(text), isNull);

    final on = ChatState(
      session: state.session,
      messages: state.messages,
      translations: state.translations,
      settings: const ChatTranslationSettings(
        autoTranslate: true,
        targetLanguage: 'en',
      ),
    );
    expect(on.translationFor(text)!.text, 'Yes');
  });

  group('ChatBloc (web parity)', () {
    late _Repo repo;
    late ChatBadgeNotifier badge;

    setUp(() {
      repo = _Repo();
      badge = ChatBadgeNotifier(
        getUnreadTotal: GetChatUnreadTotalUseCase(repo),
        storage: _Storage(),
      );
    });

    tearDown(() => badge.dispose());

    test('voice translations load with auto-translate off', () async {
      repo.connection.history$ = [
        _msg(
          '17300000000000040',
          ChatMessageType.voice,
          voice: const ChatVoice(url: 'https://cdn/orig.mp3'),
        ),
        _msg('17300000000000039', ChatMessageType.text, text: 'Vâng'),
      ];
      final bloc = _chatBloc(repo, badge)..add(const ChatStarted());
      final loaded = await bloc.stream.firstWhere(
        (s) => s.translations.isNotEmpty,
      );
      expect(repo.voiceRequests.single, ['17300000000000040']);
      expect(repo.textRequests.every((ids) => ids.isEmpty), isTrue);
      expect(repo.connection.textChannel, isFalse);
      expect(
        loaded.translationFor(loaded.messages.first)!.audioUrl,
        'https://cdn/translated-17300000000000040.mp3',
      );
      await bloc.close();
    });

    test('legacy text translation for another language is ignored', () async {
      repo.settings = const ChatTranslationSettings(
        autoTranslate: true,
        targetLanguage: 'en',
      );
      repo.connection.history$ = [
        _msg('17300000000000050', ChatMessageType.text, text: 'Vâng'),
      ];
      final bloc = _chatBloc(repo, badge)..add(const ChatStarted());
      await bloc.stream.firstWhere((s) => s.status == ChatStatus.ready);
      repo.connection.events$
        ..add(
          const ChatTranslationArrived(
            ChatTranslation(
              messageId: '17300000000000050',
              text: 'Oui',
              targetLang: 'fr',
            ),
            legacy: true,
          ),
        )
        ..add(
          const ChatTranslationArrived(
            ChatTranslation(
              messageId: '17300000000000050',
              text: 'Yes',
              targetLang: 'en',
            ),
            legacy: true,
          ),
        );
      final s = await bloc.stream.firstWhere(
        (s) => s.translations.containsKey('17300000000000050'),
      );
      expect(s.translations['17300000000000050']!.text, 'Yes');
      await bloc.close();
    });

    test(
      'createChannel and history errors are retried before failing',
      () async {
        repo.openFailures = 2;
        repo.connection
          ..failHistory = 2
          ..history$ = [_msg('17300000000000060', ChatMessageType.text)];
        final bloc = _chatBloc(repo, badge)..add(const ChatStarted());
        final ready = await bloc.stream.firstWhere(
          (s) => s.status == ChatStatus.ready,
        );
        expect(repo.openCalls, 3);
        expect(repo.connection.historyCalls, 3);
        expect(ready.messages, hasLength(1));
        await bloc.close();
      },
    );
  });

  test(
    'ConversationsBloc: new row backfilled from REST; unread total applied',
    () async {
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
      await bloc.stream.firstWhere(
        (s) => s.status == ConversationsStatus.success,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      repo.page1 = const [
        ConversationEntity(
          channelId: '7_42_one_to_one',
          partnerId: _partner,
          partnerName: 'Minh Pham',
          partnerAvatar: 'https://cdn/minh.jpg',
        ),
      ];
      _Updates.latest!.controller.add(
        const ConversationChanged(
          ConversationEntity(
            channelId: '7_42_one_to_one',
            partnerId: _partner,
            partnerName: '',
            lastText: 'Hi',
            lastTimetoken: '17300000000000070',
          ),
        ),
      );
      final filled = await bloc.stream.firstWhere(
        (s) => s.items.isNotEmpty && s.items.first.partnerName.isNotEmpty,
      );
      expect(filled.items.single.partnerName, 'Minh Pham');
      expect(filled.items.single.partnerAvatar, 'https://cdn/minh.jpg');
      expect(filled.items.single.lastText, 'Hi');

      _Updates.latest!.controller.add(const UnreadChanged(5));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(badge.value, 5);
      await bloc.close();
      badge.dispose();
    },
  );

  group('Offer checkout (web parity)', () {
    test('offer already paid / cancelled → checkout blocked', () async {
      final paid = _checkoutBloc(
        _CheckoutRemote()
          ..offer = {'status': 'pending', 'payment_status': 'paid'},
      );
      final s1 = await paid.stream.firstWhere(
        (s) => s.status == OfferCheckoutStatus.unavailable,
      );
      expect(s1.blocked, OfferCheckoutBlocked.alreadyPaid);
      await paid.close();

      final cancelled = _checkoutBloc(
        _CheckoutRemote()..offer = {'status': 'cancelled'},
      );
      final s2 = await cancelled.stream.firstWhere(
        (s) => s.status == OfferCheckoutStatus.unavailable,
      );
      expect(s2.blocked, OfferCheckoutBlocked.cancelled);
      await cancelled.close();
    });

    test('fresh offer: applied voucher + points are sent again', () async {
      final remote = _CheckoutRemote()
        ..offer = {
          'status': 'pending',
          'payment_status': 'unpaid',
          'price': 50,
          'points_used': 300,
          'points_value': 3,
          'voucher_code': 'SAVE10',
          'voucher_value': 10,
        }
        // Lần đầu getOffer (kiểm tra) trả pending; sau Stripe vẫn chưa paid → pending.
        ..retry = {'client_secret': 'pi'};
      final bloc = _checkoutBloc(remote);
      await bloc.stream.firstWhere(
        (s) => s.status == OfferCheckoutStatus.ready,
      );
      expect(bloc.quote.price, closeTo(63, 0.0001));
      expect(bloc.quote.total, closeTo(50, 0.0001));
      bloc.add(const OfferCheckoutPayRequested());
      await bloc.stream.firstWhere(
        (s) => s.status == OfferCheckoutStatus.pending,
      );
      expect(remote.sentBody!['voucher_code'], 'SAVE10');
      expect(remote.sentBody!['points_used'], 300);
      expect(remote.sentBody!['points_value'], 3.0);
      await bloc.close();
    });

    test('retry-payment without client_secret → re-check offer', () async {
      final remote = _CheckoutRemote()..retry = {'offer_id': 9};
      final repo = CheckoutRepositoryImpl(
        remote,
        _Stripe(),
        pollInterval: Duration.zero,
        pollAttempts: 2,
      );
      const request = OfferPaymentRequest(offerId: 9, paymentMethodId: 'pm_1');
      remote.offer = {'payment_status': 'paid'};
      expect(
        (await repo.payOffer(
          request,
        )).getOrElse((_) => OfferPaymentResult.failed),
        OfferPaymentResult.paid,
      );
      remote.offer = {'payment_status': 'unpaid'};
      expect(
        (await repo.payOffer(
          request,
        )).getOrElse((_) => OfferPaymentResult.paid),
        OfferPaymentResult.failed,
      );
    });
  });
}
