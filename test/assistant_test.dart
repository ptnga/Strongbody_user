import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:strongbody_buyer/modules/assistant/data/datasources/remote/assistant_remote_datasource.dart';
import 'package:strongbody_buyer/modules/assistant/data/mappers/assistant_mapper.dart';
import 'package:strongbody_buyer/modules/assistant/domain/entities/assistant_entities.dart';
import 'package:strongbody_buyer/modules/assistant/domain/repositories/assistant_repository.dart';
import 'package:strongbody_buyer/modules/assistant/domain/usecases/assistant_use_cases.dart';
import 'package:strongbody_buyer/modules/assistant/presentation/bloc/assistant_chat_cubit.dart';
import 'package:strongbody_buyer/modules/assistant/presentation/widgets/assistant_rich_text.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_form_values.dart';

/// Shape thật của BE (rút từ một lượt `POST /api/search/assistant/chat`).
Map<String, dynamic> _searchResult() => {
  'branch': 'search',
  'answer': 'I understand you are looking for nutritionist.',
  'understanding': {
    'query': 'nutritionist',
    'category_ids': [96657],
  },
  'kinds': ['sellers', 'services', 'public_offers'],
  'totals': {'sellers': 1143, 'services': 206, 'public_offers': 0},
  'cards': {
    'sellers': [
      {
        'ref': 'sellers:128',
        'kind': 'seller',
        'id': '128',
        'title': 'sarahkhan113355',
        'subtitle': 'Functional Nutritionist',
        'languages': ['en'],
        'years_experience': 4,
        'slug': 'functional.nutritionist',
        'user_id': '135',
        'description': 'Integrative and Functional Nutrition',
      },
    ],
    'services': [
      {
        'ref': 'services:15962',
        'kind': 'service',
        'id': '15962',
        'title': 'Nutrióloga',
        'provider': 'Maricela Sánchez',
        'price_from': 25,
        'currency': 'USD',
        'delivery': ['remote'],
        'image': 'https://img/1',
        'slug': 'nutriologa',
        'user_id': '55321',
        'provider_slug': 'maricela.sanchez',
        'provider_avatar': 'https://img/a',
      },
    ],
  },
  'close_matches': {
    'services': [
      {
        'ref': 'services:1',
        'kind': 'service',
        'id': '1',
        'title': 'Close one',
        'missing': ['languages', 'price', 'unknown'],
      },
    ],
  },
};

class _FakeRepo implements AssistantRepository {
  final requests = <Map<String, Object?>>[];
  StreamController<AssistantEvent>? controller;
  List<AssistantTurn> saved = const [];
  List<AssistantTurn> stored = const [];

  @override
  Stream<AssistantEvent> chat({
    required List<AssistantTurn> history,
    required String language,
    String? timezone,
    Map<String, dynamic>? previous,
    String? previousText,
    CancelToken? cancelToken,
  }) {
    requests.add({
      'history': AssistantMapper.historyMessages(history),
      'language': language,
      'previous': previous,
      'previousText': previousText,
    });
    final c = StreamController<AssistantEvent>();
    cancelToken?.whenCancel.then((_) {
      if (!c.isClosed) {
        c.addError(
          DioException.requestCancelled(
            requestOptions: RequestOptions(),
            reason: 'stop',
          ),
        );
        c.close();
      }
    });
    controller = c;
    return c.stream;
  }

  @override
  List<AssistantTurn> loadTurns() => stored;

  @override
  Future<void> saveTurns(List<AssistantTurn> turns) async => saved = turns;

  @override
  Future<void> clearTurns() async => saved = const [];
}

AssistantChatCubit _cubit(_FakeRepo repo) => AssistantChatCubit(
  chat: StreamAssistantChatUseCase(repo),
  history: AssistantHistoryUseCase(repo),
);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  group('SseDataParser', () {
    test('splits data lines across chunks and ignores other fields', () {
      final p = SseDataParser();
      expect(p.add('data: {"type":"route"}\n\nda'), ['{"type":"route"}']);
      expect(p.add('ta: {"type":"delta","text":"Hi"}\r\n'), isEmpty);
      expect(p.add('\r\nevent: x\n\n'), ['{"type":"delta","text":"Hi"}']);
    });
  });

  group('AssistantMapper', () {
    test('maps result groups to Social Market card entities', () {
      final r = AssistantMapper.result(_searchResult());
      expect(r.branch, 'search');
      expect(r.kinds.first, AssistantKind.sellers);
      expect(r.totals[AssistantKind.sellers], 1143);
      final service = r.cards[AssistantKind.services]!.single.service!;
      expect(service.id, 15962);
      expect(service.seller.shopName, 'Maricela Sánchez');
      expect(service.seller.id, 55321);
      expect(service.price?.amount, 25);
      expect(service.images, ['https://img/1']);
      final seller = r.cards[AssistantKind.sellers]!.single.seller!;
      expect(seller.name, 'sarahkhan113355');
      expect(seller.languages, ['English']);
      expect(seller.yearsOfExperience, 4);
      final close = r.closeMatches[AssistantKind.services]!.single;
      expect(close.missing, [
        AssistantMissing.languages,
        AssistantMissing.price,
      ]);
    });

    test('offer card keeps the provider name', () {
      final card = AssistantMapper.card({
        'kind': 'offer',
        'id': '7',
        'title': 'Home physio',
        'provider': 'Ana',
        'user_id': '9',
        'price_from': 40,
        'currency': 'USD',
        'delivery': ['at_home'],
      })!;
      expect(card.offer!.sellerName, 'Ana');
      expect(card.offer!.sellerUserId, 9);
      expect(card.offer!.minPrice, 40);
    });

    test(
      'request_draft → form values (budget range, past deadline dropped)',
      () {
        final today = DateTime(2026, 10, 31);
        final d = AssistantMapper.requestDraft({
          'description': 'Physio at home',
          'category_ids': [96654],
          'delivery_types': ['at_home', 'bogus'],
          'budget_min': 30,
          'budget_max': 50,
          'currency': 'usd',
          'deadline': '2026-11-07',
          'seller_languages': ['en', 'xx'],
          'rank': 6,
          'suggestion': 'Add details',
        }, today: today);
        expect(d.values.budget, '30-50');
        expect(d.values.currency, 'USD');
        expect(d.values.deliveryTypes, [RequestDeliveryType.atHome]);
        expect(d.values.deadline, DateTime(2026, 11, 7, 9));
        expect(d.values.sellerLanguages, ['en']);
        expect(d.assistant.categoryIds, [96654]);
        expect(d.assistant.qualityScore, 6);
        final past = AssistantMapper.requestDraft({
          'description': 'x',
          'deadline': '2026-10-01',
        }, today: today);
        expect(past.values.deadline, isNull);
      },
    );

    test(
      'understanding → draft (said text + place, at_office → at_clinic)',
      () {
        final d = AssistantMapper.understandingToDraft(
          {
            'location_text': 'Hanoi',
            'delivery_types': ['at_office'],
            'budget_max': 50,
            'currency': 'USD',
          },
          'physio next week',
          today: DateTime(2026, 10, 31),
        );
        expect(d.values.description, 'physio next week (Hanoi)');
        expect(d.values.deliveryTypes, [RequestDeliveryType.atClinic]);
        expect(d.values.budget, '50');
      },
    );

    test('turns round-trip through storage JSON', () {
      final turns = <AssistantTurn>[
        const AssistantUserTurn('nutritionist'),
        AssistantReplyTurn(
          branch: 'search',
          text: 'Here you go',
          history: '[Search results for: nutritionist]',
          result: AssistantMapper.result(_searchResult()),
          saidText: 'nutritionist',
          requestDraft: AssistantMapper.requestDraft({
            'description': 'Need a nutritionist',
            'budget_max': 20,
          }),
        ),
      ];
      final back = turns
          .map(AssistantMapper.turnJson)
          .map(AssistantMapper.turn)
          .nonNulls
          .toList();
      expect(back, turns);
      expect(AssistantMapper.historyMessages(back), [
        {'role': 'user', 'content': 'nutritionist'},
        {'role': 'assistant', 'content': '[Search results for: nutritionist]'},
      ]);
    });

    test('rich text strips citations and bold markers', () {
      expect(
        AssistantRichText.clean('## Pay\n**Confirm** & pay [4].'),
        'Pay\nConfirm & pay.',
      );
    });
  });

  group('AssistantChatCubit', () {
    test('streams a search turn and saves it', () async {
      final repo = _FakeRepo();
      final cubit = _cubit(repo);
      cubit.start(language: 'vi', text: 'nutritionist', source: 'home');
      await _flush();
      expect(cubit.state.busy, isTrue);
      final c = repo.controller!;
      c.add(const AssistantRouteEvent('search'));
      c.add(AssistantResultEvent(AssistantMapper.result(_searchResult())));
      c.add(const AssistantDoneEvent(branch: 'search', historyText: 'H'));
      await c.close();
      await _flush();

      expect(repo.requests.single['language'], 'vi');
      final reply = cubit.state.turns.last as AssistantReplyTurn;
      expect(reply.streaming, isFalse);
      expect(reply.text, 'I understand you are looking for nutritionist.');
      expect(reply.history, 'H');
      expect(reply.result!.hasCards, isTrue);
      expect(cubit.state.busy, isFalse);
      expect(repo.saved, cubit.state.turns);
      await cubit.close();
    });

    test('follow-up sends previous understanding and said text', () async {
      final repo = _FakeRepo();
      final cubit = _cubit(repo);
      cubit.start(language: 'en', text: 'nutritionist');
      await _flush();
      repo.controller!
        ..add(AssistantResultEvent(AssistantMapper.result(_searchResult())))
        ..close();
      await _flush();
      // saidText của lượt đầu = câu đã nói.
      cubit.ask('cheaper');
      await _flush();
      expect(repo.requests.last['previous'], {
        'query': 'nutritionist',
        'category_ids': [96657],
      });
      expect(repo.requests.last['previousText'], 'nutritionist');
      expect(
        (cubit.state.turns.last as AssistantReplyTurn).saidText,
        'nutritionist · cheaper',
      );
      await cubit.close();
    });

    test('rag answer arrives through deltas', () async {
      final repo = _FakeRepo();
      final cubit = _cubit(repo);
      cubit.start(language: 'en', text: 'How do I pay?');
      await _flush();
      repo.controller!
        ..add(const AssistantRouteEvent('info'))
        ..add(const AssistantResultEvent(AssistantResult(branch: 'info')))
        ..add(const AssistantDeltaEvent('To'))
        ..add(const AssistantDeltaEvent(' pay'))
        ..close();
      await _flush();
      expect((cubit.state.turns.last as AssistantReplyTurn).text, 'To pay');
      await cubit.close();
    });

    test('rate limit → error, retry resends the question', () async {
      final repo = _FakeRepo();
      final cubit = _cubit(repo);
      cubit.start(language: 'en', text: 'physio');
      await _flush();
      repo.controller!
        ..addError(const AssistantRateLimitException())
        ..close();
      await _flush();
      final failed = cubit.state.turns.last as AssistantReplyTurn;
      expect(failed.error, AssistantTurnError.rateLimited);

      cubit.retry();
      await _flush();
      expect(cubit.state.turns.length, 2);
      expect(cubit.state.turns.first, const AssistantUserTurn('physio'));
      expect((cubit.state.turns.last as AssistantReplyTurn).streaming, isTrue);
      await cubit.close();
    });

    test('stop before any output drops the empty reply', () async {
      final repo = _FakeRepo();
      final cubit = _cubit(repo);
      cubit.start(language: 'en', text: 'physio');
      await _flush();
      cubit.stop();
      await _flush();
      await _flush();
      expect(cubit.state.turns, [const AssistantUserTurn('physio')]);
      expect(cubit.state.busy, isFalse);
      await cubit.close();
    });

    test(
      'post request on no results builds a draft from the question',
      () async {
        final repo = _FakeRepo();
        final cubit = _cubit(repo);
        cubit.start(language: 'en', text: 'reiki healer in Hue');
        await _flush();
        repo.controller!
          ..add(
            const AssistantResultEvent(
              AssistantResult(
                branch: 'search',
                understanding: {'location_text': 'Hue', 'budget_max': 30},
              ),
            ),
          )
          ..close();
        await _flush();
        cubit.postRequest(1);
        final reply = cubit.state.turns.last as AssistantReplyTurn;
        expect(reply.requestDraft!.values.description, 'reiki healer in Hue');
        expect(reply.requestDraft!.values.budget, '30');
        await cubit.close();
      },
    );

    test('new chat clears turns and storage', () async {
      final repo = _FakeRepo()
        ..stored = const [AssistantUserTurn('old')]
        ..saved = const [AssistantUserTurn('old')];
      final cubit = _cubit(repo);
      cubit.start(language: 'en');
      expect(cubit.state.turns, const [AssistantUserTurn('old')]);
      await cubit.startNew();
      expect(cubit.state.turns, isEmpty);
      expect(repo.saved, isEmpty);
      await cubit.close();
    });
  });
}
