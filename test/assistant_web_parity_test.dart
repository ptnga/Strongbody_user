import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';
import 'package:strongbody_buyer/modules/assistant/data/datasources/remote/assistant_remote_datasource.dart';
import 'package:strongbody_buyer/modules/assistant/data/mappers/assistant_mapper.dart';
import 'package:strongbody_buyer/modules/assistant/data/repositories/assistant_repository_impl.dart';
import 'package:strongbody_buyer/modules/assistant/domain/entities/assistant_entities.dart';
import 'package:strongbody_buyer/modules/assistant/domain/repositories/assistant_repository.dart';
import 'package:strongbody_buyer/modules/assistant/domain/usecases/assistant_use_cases.dart';
import 'package:strongbody_buyer/modules/assistant/presentation/bloc/assistant_chat_cubit.dart';
import 'package:strongbody_buyer/modules/assistant/presentation/widgets/assistant_typewriter.dart';

/// ApiClient giả: trả SSE dựng sẵn, ghi lại tham số gọi.
class _FakeApi implements ApiClient {
  final List<String> events;
  final calls = <Map<String, Object?>>[];

  _FakeApi(this.events);

  @override
  Future<dynamic> request({
    required String path,
    required ApiType method,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    Duration? timeout,
    bool skipAuth = false,
    ResponseType? responseType,
  }) async {
    calls.add({
      'path': path,
      'data': data,
      'skipAuth': skipAuth,
      'accept': headers?['Accept'],
    });
    final body = events.map((e) => 'data: $e\n\n').join();
    return ResponseBody(
      Stream.value(Uint8List.fromList(utf8.encode(body))),
      200,
      headers: {
        'content-type': ['text/event-stream; charset=utf-8'],
      },
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRemote implements AssistantRemoteDataSource {
  final bodies = <Map<String, dynamic>>[];

  @override
  Stream<Map<String, dynamic>> streamChat(
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) {
    bodies.add(body);
    return const Stream.empty();
  }
}

class _NoPrefs implements UserPreferences {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepo implements AssistantRepository {
  final requests = <Map<String, Object?>>[];
  final controllers = <StreamController<AssistantEvent>>[];

  @override
  Stream<AssistantEvent> chat({
    required List<AssistantTurn> history,
    required String language,
    String? timezone,
    Map<String, dynamic>? previous,
    String? previousText,
    Map<String, dynamic>? understanding,
    CancelToken? cancelToken,
  }) {
    requests.add({'previous': previous, 'previousText': previousText});
    final c = StreamController<AssistantEvent>();
    controllers.add(c);
    return c.stream;
  }

  @override
  List<AssistantTurn> loadTurns() => const [];

  @override
  Future<void> saveTurns(List<AssistantTurn> turns) async {}

  @override
  Future<void> clearTurns() async {}
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  setUpAll(
    () => dotenv.loadFromString(envString: 'WEB_BASE_URL=https://web.test'),
  );

  group('Assistant cards (web searchAssistant.ts)', () {
    test('consultation service carries the price range, deliveries no price', () {
      final card = AssistantMapper.card({
        'ref': 'services:1',
        'kind': 'service',
        'id': '1',
        'title': 'Nutrition consult',
        'price_from': 20,
        'price_to': 60,
        'pricing_mode': 'consultation',
        'currency': 'USD',
        'delivery': ['remote', 'at_home'],
        'distance_km': 2.43,
      })!;
      final s = card.service!;
      expect(s.price?.amount, 20);
      // Social Market card: khoảng giá + nhãn Consultation, chỉ Send inquiry.
      expect(s.price?.max, 60);
      expect(s.price?.consultation, isTrue);
      expect(s.deliveries.map((d) => d.price), [null, null]);
      expect(card.distanceKm, 2.43);
      // Thẻ dịch vụ: địa chỉ đã nằm trong card, dòng vị trí chỉ có khoảng cách.
      expect(card.address, isNull);
      expect(card.hasPlaceLine, isTrue);
    });

    test('seller card shows country + flagcdn png and full language names', () {
      final card = AssistantMapper.card({
        'ref': 'sellers:2',
        'kind': 'seller',
        'id': '2',
        'title': 'Dr. An',
        'languages': ['vi', 'en'],
        'country': 'Vietnam',
        'country_flag': 'https://flagcdn.com/vn.svg',
        'address': 'Hoàn Kiếm, Hà Nội',
        'verified': true,
      })!;
      final e = card.seller!;
      expect(e.country, 'Vietnam');
      expect(e.flag, 'https://flagcdn.com/w40/vn.png');
      expect(e.languages, ['Vietnamese', 'English']);
      expect(e.verified, isTrue);
      expect(card.address, 'Hoàn Kiếm, Hà Nội');
    });

    test('missing "distance" is understood', () {
      final card = AssistantMapper.card({
        'kind': 'service',
        'id': '3',
        'title': 'x',
        'missing': ['distance', 'gender'],
      })!;
      expect(card.missing, [
        AssistantMissing.distance,
        AssistantMissing.gender,
      ]);
    });

    test('formatKm: one decimal under 10 km (min 0.1), rounded above', () {
      expect(AssistantCard.formatKm(2.43), '2.4');
      expect(AssistantCard.formatKm(2.0), '2');
      expect(AssistantCard.formatKm(0.01), '0.1');
      expect(AssistantCard.formatKm(12.6), '13');
    });
  });

  group('Near / relaxed (web NearLine, RelaxedLine)', () {
    Map<String, dynamic> result({
      Map<String, dynamic>? near,
      Map<String, dynamic>? relaxed,
    }) => {
      'branch': 'search',
      'near': ?near,
      'relaxed': ?relaxed,
      'cards': {
        'services': [
          {'kind': 'service', 'id': '1', 'title': 'Physio'},
        ],
      },
    };

    test('gps label keeps district + city, soft flag parsed', () {
      final r = AssistantMapper.result(
        result(
          near: {
            'label': 'French Quarter, Hoàn Kiếm, Hà Nội, Việt Nam',
            'km': 5,
            'source': 'gps',
            'soft': true,
          },
        ),
      );
      expect(r.near!.fromGps, isTrue);
      expect(r.near!.soft, isTrue);
      expect(r.near!.displayLabel, 'Hoàn Kiếm, Hà Nội');
      final told = AssistantMapper.result(
        result(near: {'label': 'District 1, HCMC, Vietnam', 'source': 'x'}),
      );
      expect(told.near!.displayLabel, 'District 1, HCMC');
      final unnamed = AssistantMapper.result(
        result(near: {'label': 'GPS', 'source': 'gps'}),
      );
      expect(unnamed.near!.displayLabel, '');
    });

    test('relaxed only counts kinds that show cards', () {
      final r = AssistantMapper.result(
        result(
          relaxed: {
            'services': ['delivery_types', 'languages', 'unknown'],
            'public_offers': ['near', 'gender'],
          },
        ),
      );
      expect(r.relaxed, [
        AssistantMissing.delivery,
        AssistantMissing.languages,
      ]);
      expect(r.nearRelaxed, isFalse);
      final near = AssistantMapper.result(
        result(
          relaxed: {
            'services': ['near'],
          },
        ),
      );
      expect(near.nearRelaxed, isTrue);
      expect(near.relaxed, isEmpty);
    });
  });

  group('Request draft', () {
    test('keeps any 3-letter currency code (web isCurrencyCode)', () {
      final d = AssistantMapper.requestDraft({
        'description': 'x',
        'currency': 'chf',
      });
      expect(d.values.currency, 'CHF');
      final bad = AssistantMapper.requestDraft({
        'description': 'x',
        'currency': 'dollars',
      });
      expect(bad.values.currency, 'USD');
    });
  });

  group('Request body / stream', () {
    test('timezone: whole-hour offsets → Etc/GMT∓N, odd offsets omitted', () {
      expect(
        AssistantRepositoryImpl.deviceTimeZone(const Duration(hours: 7)),
        'Etc/GMT-7',
      );
      expect(
        AssistantRepositoryImpl.deviceTimeZone(const Duration(hours: -5)),
        'Etc/GMT+5',
      );
      expect(AssistantRepositoryImpl.deviceTimeZone(Duration.zero), 'UTC');
      expect(
        AssistantRepositoryImpl.deviceTimeZone(
          const Duration(hours: 5, minutes: 30),
        ),
        isNull,
      );
    });

    test(
      'body: history + language + timezone; understanding replaces previous',
      () async {
        final remote = _FakeRemote();
        final repo = AssistantRepositoryImpl(remote, _NoPrefs());
        await repo
            .chat(
              history: const [
                AssistantUserTurn('physio'),
                AssistantReplyTurn(text: 'shown', history: 'H'),
                AssistantReplyTurn(error: AssistantTurnError.failed),
                AssistantUserTurn('cheaper'),
              ],
              language: 'vi',
              previous: const {'query': 'physio'},
              previousText: 'physio',
            )
            .toList();
        final first = remote.bodies.single;
        expect(first['messages'], [
          {'role': 'user', 'content': 'physio'},
          {'role': 'assistant', 'content': 'H'},
          {'role': 'user', 'content': 'cheaper'},
        ]);
        expect(first['language'], 'vi');
        expect(first['timezone'], AssistantRepositoryImpl.deviceTimeZone());
        expect(first['previous'], {'query': 'physio'});
        expect(first['previous_text'], 'physio');

        await repo
            .chat(
              history: const [AssistantUserTurn('physio')],
              language: 'en',
              previous: const {'query': 'physio'},
              previousText: 'physio',
              understanding: const {'query': 'physio', 'relax': true},
            )
            .toList();
        final second = remote.bodies.last;
        expect(second['understanding'], {'query': 'physio', 'relax': true});
        expect(second.containsKey('previous'), isFalse);
        expect(second.containsKey('previous_text'), isFalse);
      },
    );

    test('sends the token (no skipAuth) and finishes on done', () async {
      final api = _FakeApi([
        '{"type":"route","branch":"search"}',
        '{"type":"done","branch":"search","history_text":"H"}',
      ]);
      final events = await AssistantRemoteDataSourceImpl(
        api,
      ).streamChat({'messages': [], 'language': 'en'}).toList();
      expect(events.map((e) => e['type']), ['route', 'done']);
      expect(api.calls.single['skipAuth'], isFalse);
      expect(
        api.calls.single['path'],
        'https://web.test/api/search/assistant/chat',
      );
      expect(api.calls.single['accept'], 'text/event-stream');
    });

    test('stream that ends before done is an error (retryable)', () async {
      final api = _FakeApi(['{"type":"route","branch":"search"}', 'broken']);
      final stream = AssistantRemoteDataSourceImpl(
        api,
      ).streamChat({'messages': [], 'language': 'en'});
      await expectLater(
        stream,
        emitsInOrder([
          isA<Map<String, dynamic>>(),
          emitsError(isA<AssistantIncompleteException>()),
        ]),
      );
    });
  });

  group('AssistantChatCubit (web lastSearch / ask)', () {
    AssistantReplyTurn reply(String branch, Map<String, dynamic> u) =>
        AssistantReplyTurn(
          result: AssistantResult(branch: branch, understanding: u),
          saidText: 'said',
        );

    test('lastSearch counts search, request and the no_topic follow-up', () {
      expect(
        AssistantChatCubit.lastSearch([
          reply('request', {'query': 'insomnia'}),
        ])?.understanding,
        {'query': 'insomnia'},
      );
      expect(
        AssistantChatCubit.lastSearch([
          reply('out_of_scope', {'scope_reason': 'no_topic', 'date': 'x'}),
        ])?.text,
        'said',
      );
      expect(
        AssistantChatCubit.lastSearch([
          reply('out_of_scope', {'reason': 'weather'}),
        ]),
        isNull,
      );
    });

    test(
      'asking mid-stream stops the old spinner; new reply is live',
      () async {
        final repo = _FakeRepo();
        final cubit = AssistantChatCubit(
          chat: StreamAssistantChatUseCase(repo),
          history: AssistantHistoryUseCase(repo),
        );
        cubit.start(language: 'en', text: 'physio');
        await _flush();
        cubit.ask('online only');
        await _flush();
        final turns = cubit.state.turns;
        expect(turns.length, 4);
        expect((turns[1] as AssistantReplyTurn).streaming, isFalse);
        final last = turns.last as AssistantReplyTurn;
        expect(last.streaming, isTrue);
        expect(last.live, isTrue);
        for (final c in repo.controllers) {
          await c.close();
        }
        await cubit.close();
      },
    );
  });

  group('Typewriter (web useTypewriter)', () {
    test('steps at least 2 chars, catches up on long backlog', () {
      expect(AssistantTypewriter.nextCount(0, 10), 2);
      expect(AssistantTypewriter.nextCount(0, 500), 20);
      expect(AssistantTypewriter.nextCount(9, 10), 10);
    });

    test('never cuts an emoji in half', () {
      const text = 'a😀b';
      expect(AssistantTypewriter.visible(text, 2), 'a');
      expect(AssistantTypewriter.visible(text, 3), 'a😀');
    });
  });
}
