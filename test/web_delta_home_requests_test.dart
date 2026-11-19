import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/modules/home/data/datasources/remote/home_board_remote_datasource.dart';
import 'package:strongbody_buyer/modules/home/data/mappers/home_board_mapper.dart';
import 'package:strongbody_buyer/modules/home/data/repositories/home_board_repository_impl.dart';
import 'package:strongbody_buyer/modules/home/domain/entities/board_entities.dart';
import 'package:strongbody_buyer/modules/home/domain/usecases/home_board_use_cases.dart';
import 'package:strongbody_buyer/modules/home/presentation/bloc/board_stats/board_stats_cubit.dart';
import 'package:strongbody_buyer/modules/home/presentation/widgets/board/board_offer_row.dart';
import 'package:strongbody_buyer/modules/home/presentation/widgets/board/board_request_card.dart';
import 'package:strongbody_buyer/modules/home/presentation/widgets/board/recently_matched.dart';
import 'package:strongbody_buyer/modules/home/presentation/widgets/board/requests_intro.dart';
import 'package:strongbody_buyer/modules/post_request/data/mappers/post_request_mapper.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/my_request_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_form_values.dart';
import 'package:strongbody_buyer/modules/post_request/domain/repositories/post_request_repository.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/get_matched_providers_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/matched_providers/matched_providers_cubit.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/request_matches/request_matches_cubit.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/widgets/my_requests/my_request_formatters.dart';

/// Datasource giả của board: ghi lại query, trả trang rỗng / số liệu dựng sẵn.
class _Remote implements HomeBoardRemoteDataSource {
  final requestQueries = <Map<String, dynamic>>[];
  final searchBodies = <Map<String, dynamic>>[];
  Map<String, dynamic>? stats;

  @override
  Future<BoardRawPage> getRequests(Map<String, dynamic> query) async {
    requestQueries.add(query);
    return const BoardRawPage(items: [], totalPage: 1);
  }

  @override
  Future<BoardSearchHits> search(String kind, Map<String, dynamic> body) async {
    searchBodies.add(body);
    return const BoardSearchHits(ids: [3], total: 1);
  }

  @override
  Future<Map<String, dynamic>> getRequestBoardStats() async =>
      stats ?? (throw const FormatException('board-stats: no week_total'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements GlobalStorage {
  @override
  bool get isLoggedIn => false;

  @override
  int? get userId => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PostRepo implements PostRequestRepository {
  final calls = <({int id, int page, int limit})>[];
  final pages = <int, Either<Failure, MatchedProvidersPage>>{};

  @override
  Future<Either<Failure, MatchedProvidersPage>> getMatchedProviders(
    int requestId, {
    int page = 1,
    int limit = 20,
  }) async {
    calls.add((id: requestId, page: page, limit: limit));
    return pages[page] ?? const Right(MatchedProvidersPage());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MyRequestEntity _request(String status, {RequestAiRefine? refine}) =>
    MyRequestEntity(
      id: 1,
      status: status,
      details: const RequestFormValues(description: 'x'),
      aiRefine: refine,
    );

void main() {
  group('Home board (web acb552dcc · 884fd2e87 · 9f3804171)', () {
    test('requests feed + search ask for the seed-only feed=home', () async {
      final remote = _Remote();
      final repo = HomeBoardRepositoryImpl(remote, _Storage());
      await repo.getRequests(const BoardQuery(page: 2));
      expect(remote.requestQueries.single['feed'], 'home');
      expect(remote.requestQueries.single['statuses'], 'active,closed');

      await repo.getRequests(const BoardQuery(keyword: 'sleep'));
      expect(remote.searchBodies.single['feed'], 'home');
      // Tải thẻ theo id của search cũng cùng bộ lọc feed.
      expect(remote.requestQueries.last['ids'], '3');
      expect(remote.requestQueries.last['feed'], 'home');

      final offers = HomeBoardRepositoryImpl.searchBody(
        BoardKind.offers,
        const BoardQuery(keyword: 'yoga'),
      );
      expect(offers.containsKey('feed'), isFalse);
    });

    test('board-stats: real weekly numbers + recently matched', () {
      final stats = HomeBoardMapper.stats({
        'week_total': 169,
        'week_matched': 12,
        'recent_matched': [
          {
            'id': 1,
            'title': 'Need help',
            'service': 'Nutrition Coaching',
            'country': {'title': 'Vietnam', 'code': 'vn'},
          },
          {'id': 2, 'title': 'Spam', 'service': ''},
          {'title': 'no id'},
        ],
      });
      expect(stats.weekTotal, 169);
      expect(stats.weekMatched, 12);
      expect(stats.recentMatched.map((m) => m.id), [1, 2]);
      expect(stats.recentMatched.first.country, 'Vietnam');
      expect(stats.recentMatched.first.flag, isNotNull);
    });

    test('stats failure leaves stats null (row hidden)', () async {
      final remote = _Remote();
      final cubit = BoardStatsCubit(
        GetBoardStatsUseCase(HomeBoardRepositoryImpl(remote, _Storage())),
      );
      await cubit.load();
      expect(cubit.state.status, BoardStatsStatus.failure);
      expect(cubit.state.stats, isNull);

      remote.stats = {'week_total': 3, 'week_matched': 0};
      await cubit.load();
      expect(cubit.state.status, BoardStatsStatus.success);
      expect(cubit.state.stats!.weekTotal, 3);
      await cubit.close();
    });

    test(
      'stat tiles: none / week only / week + matched (no marketing floor)',
      () {
        expect(RequestsIntro.tiles(null, 'en'), isEmpty);
        expect(RequestsIntro.tiles(const BoardStats(), 'en'), isEmpty);
        final one = RequestsIntro.tiles(const BoardStats(weekTotal: 1), 'en');
        expect(one.single.display, '1');
        expect(one.single.label, 'boardIntroStatWeekOne');
        final two = RequestsIntro.tiles(
          const BoardStats(weekTotal: 1234, weekMatched: 56),
          'en',
        );
        expect(two.map((t) => t.display), ['1,234', '56']);
        expect(two.last.label, 'boardIntroStatMatched');
      },
    );

    test('recently matched: only classified requests, at most 3 rows', () {
      final items = [
        for (var i = 0; i < 5; i++)
          BoardMatchedItem(id: i, service: i == 1 ? ' ' : 'Service $i'),
      ];
      expect(RecentlyMatched.visible(items).map((i) => i.id), [0, 2, 3]);
    });

    testWidgets('recently matched block renders rows, hides when empty', (
      tester,
    ) async {
      Future<void> pump(List<BoardMatchedItem> items) => tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: Scaffold(body: RecentlyMatched(items: items)),
          ),
        ),
      );
      await pump(const [
        BoardMatchedItem(id: 1, service: 'Sleep coaching', country: 'Japan'),
      ]);
      expect(find.text('boardMatchedTitle'), findsOneWidget);
      expect(find.text('Sleep coaching'), findsOneWidget);
      expect(find.text('boardMatchedLabel'), findsOneWidget);
      await pump(const [BoardMatchedItem(id: 2)]);
      expect(find.text('boardMatchedTitle'), findsNothing);
    });

    test('compact card: "Teri M." for public authors, null when anonymous', () {
      expect(
        BoardRequestCard.displayName(
          const BoardRequest(
            id: 1,
            text: 't',
            anonymous: false,
            firstName: 'Teri',
            lastName: 'Morris',
          ),
        ),
        'Teri M.',
      );
      expect(
        BoardRequestCard.displayName(
          const BoardRequest(id: 1, text: 't', firstName: 'Teri'),
        ),
        isNull,
      );
    });

    test('request tag prefers the service classification', () {
      final r = HomeBoardMapper.request({
        'id': 1,
        'content': 'x',
        'service_classification': {'name': 'Nutrition Coaching'},
        'category': {'name': 'Longevity'},
      })!;
      expect(r.category, 'Nutrition Coaching');
    });

    test('offer row: first classification, no "Consultation" price label', () {
      final o = HomeBoardMapper.offer({
        'id': 2,
        'title': 'Sleep plan',
        'price': 80,
        'price_max': 150,
        'pricing_mode': 'consultation',
        'service_classifications': [
          {'name': 'Sleep coaching'},
          {'name': 'Stress'},
        ],
      })!;
      expect(o.classification, 'Sleep coaching');
      expect(BoardOfferRow.priceLabel(o, 'USD'), isNot(contains('board')));
      expect(BoardOfferRow.priceLabel(o, 'USD'), contains('–'));
    });
  });

  group('My requests (web e5d069172 · acb552dcc · 288d5cecb)', () {
    test('ai_refine + matched_providers are parsed', () {
      final page = PostRequestMapper.myRequests({
        'list': [
          {
            'id': 9,
            'status': 'rejected',
            'description': 'help',
            'matched_providers': 4,
            'ai_refine': {
              'score': 2,
              'is_empty': false,
              'suggestion': 'Hãy thêm chi tiết',
              'suggestion_en': 'Add details',
            },
          },
        ],
      });
      final r = page.items.single;
      expect(r.matchedProviders, 4);
      expect(r.aiRefine!.score, 2);
      expect(r.aiRefine!.suggestionFor('en'), 'Add details');
      expect(r.aiRefine!.suggestionFor('vi'), 'Hãy thêm chi tiết');
      expect(r.showsAiReview, isTrue);
      expect(r.isRejected, isTrue);
    });

    test('rejected but rescoring shows "In review", not closed', () {
      final r = _request(
        'rejected',
        refine: const RequestAiRefine(score: 2, rescoring: true),
      );
      expect(r.isInReview, isTrue);
      expect(r.isRejected, isFalse);
      expect(r.isClosed, isFalse);
      expect(r.showsAiReview, isTrue);
      expect(MyRequestFormatters.status(r), 'myRequestsStatusPending');
    });

    test('AI review only below the approval score; 0-score note elsewhere', () {
      const good = RequestAiRefine(score: 7, suggestionEn: 'ok');
      const low = RequestAiRefine(score: 3, suggestionEn: 'more');
      const empty = RequestAiRefine(isEmpty: true, suggestion: 'gì?');
      expect(_request('pending_approval', refine: good).showsAiReview, isFalse);
      expect(_request('pending_approval', refine: low).showsAiReview, isTrue);
      expect(_request('active', refine: low).showsAiReview, isFalse);
      expect(_request('active', refine: empty).showsAiReview, isTrue);
      expect(_request('active').showsAiReview, isFalse);
      expect(
        _request('rejected', refine: const RequestAiRefine()).showsAiReview,
        isFalse,
        reason: 'no suggestion text',
      );
    });

    test('closed shows Solved', () {
      expect(
        MyRequestFormatters.status(_request('closed')),
        'myRequestsStatusSolved',
      );
    });

    test('matched providers: expert profile → category card data', () {
      final page = PostRequestMapper.matchedProviders({
        'list': [
          {
            'user_id': 5,
            'name': 'Dr. A',
            'replied': true,
            'country': {'title': 'Japan', 'code': 'jp'},
            'expert': {'id': 11, 'user_id': 5, 'name': 'Dr. A'},
          },
          {'user_id': 6, 'name': 'Hidden'},
          {'name': 'no id'},
        ],
        'total': 7,
      });
      expect(page.total, 7);
      expect(page.items.map((p) => p.userId), [5, 6]);
      expect(page.items.first.replied, isTrue);
      expect(page.items.first.expert, isNotNull);
      expect(page.items.last.expert, isNull);
      expect(page.items.first.country, 'Japan');
    });

    test(
      'matched providers cubit: first open once, show more appends',
      () async {
        final repo = _PostRepo()
          ..pages[1] = const Right(
            MatchedProvidersPage(
              items: [MatchedProviderEntity(userId: 1)],
              total: 2,
            ),
          )
          ..pages[2] = const Right(
            MatchedProvidersPage(
              items: [MatchedProviderEntity(userId: 2)],
              total: 2,
            ),
          );
        final cubit = MatchedProvidersCubit(GetMatchedProvidersUseCase(repo));
        await cubit.open(42);
        await cubit.open(42);
        expect(repo.calls, [(id: 42, page: 1, limit: 20)]);
        expect(cubit.state.hasMore, isTrue);
        await cubit.loadMore();
        expect(cubit.state.items.map((p) => p.userId), [1, 2]);
        expect(cubit.state.hasMore, isFalse);

        repo.pages[3] = Left(ServerFailure('down'));
        await cubit.loadMore();
        expect(cubit.state.status, MatchedProvidersStatus.failure);
        expect(cubit.state.items, hasLength(2));
        await cubit.close();
      },
    );
  });

  test('request-sent page hides the matched experts block (web b260fc079)', () {
    expect(RequestMatchesCubit.showMatchedExperts, isFalse);
  });
}
