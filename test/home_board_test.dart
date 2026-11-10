import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/modules/home/data/mappers/home_board_mapper.dart';
import 'package:strongbody_buyer/modules/home/data/repositories/home_board_repository_impl.dart';
import 'package:strongbody_buyer/modules/home/domain/entities/board_entities.dart';
import 'package:strongbody_buyer/modules/home/domain/repositories/home_board_repository.dart';
import 'package:strongbody_buyer/modules/home/domain/usecases/home_board_use_cases.dart';
import 'package:strongbody_buyer/modules/home/presentation/bloc/board/board_cubit.dart';

class _Repo implements HomeBoardRepository {
  final queries = <BoardQuery>[];
  final pages = <int, Either<Failure, BoardPage<BoardRequest>>>{};
  Completer<void>? gate;

  @override
  Future<Either<Failure, BoardPage<BoardRequest>>> getRequests(
    BoardQuery query,
  ) async {
    queries.add(query);
    await gate?.future;
    return pages[query.page] ?? const Right(BoardPage());
  }

  @override
  Future<Either<Failure, BoardPage<BoardOffer>>> getOffers(
    BoardQuery query,
  ) async => const Right(BoardPage());

  @override
  Future<Either<Failure, List<BoardCountry>>> getCountries(
    BoardKind kind,
  ) async => const Right([BoardCountry(id: 230, title: 'Vietnam', count: 3)]);
}

BoardRequest _req(int id) => BoardRequest(id: id, text: 'Request $id');

BoardCubit<BoardRequest> _cubit(_Repo repo) => BoardCubit<BoardRequest>(
  kind: BoardKind.requests,
  fetch: GetBoardRequestsUseCase(repo).call,
  idOf: (r) => r.id,
  getCountries: GetBoardCountriesUseCase(repo),
);

Future<BoardState<BoardRequest>> _until(
  BoardCubit<BoardRequest> cubit,
  bool Function(BoardState<BoardRequest>) test,
) => test(cubit.state)
    ? Future.value(cubit.state)
    : cubit.stream.firstWhere(test);

void main() {
  group('HomeBoardMapper', () {
    test('request: public author, country flag, photos vs files', () {
      final r = HomeBoardMapper.request({
        'id': 5,
        'content': 'Need a sleep coach',
        'anonymous': false,
        'created_at': '2026-11-01 10:00:00',
        'status': 'closed',
        'min_budget': 50,
        'max_budget': 80,
        'currency': 'usd',
        'delivery_type': 'remote',
        'seller_languages': '["en","vi"]',
        'attachments':
            '[{"url":"https://x/a.jpg","name":"a.jpg"},{"url":"https://x/b.pdf","name":"b.pdf","type":"application/pdf"}]',
        'category': {'name': 'Longevity'},
        'user': {
          'id': 9,
          'first_name': 'Lan',
          'last_name': 'Tran',
          'profile_picture': 'https://x/p.png',
          'country': {'title': 'Vietnam', 'code': 'VN'},
        },
      })!;
      expect(r.authorName, 'Lan Tran');
      expect(r.userId, 9);
      expect(r.flag, 'https://flagcdn.com/w40/vn.png');
      expect(r.createdAt, DateTime.utc(2026, 11, 1, 10));
      expect(r.closed, isTrue);
      expect(r.currency, 'USD');
      expect(r.languages, ['en', 'vi']);
      expect(r.attachments.where((a) => a.isPhoto).length, 1);
      expect(r.category, 'Longevity');
    });

    test('request is anonymous unless the API says false', () {
      final r = HomeBoardMapper.request({
        'id': 6,
        'description': 'Help',
        'user': {'first_name': 'Lan', 'profile_picture': 'p'},
      })!;
      expect(r.anonymous, isTrue);
      expect(r.authorName, isEmpty);
      expect(r.avatar, isNull);
    });

    test('offer: one service price, active delivery types, verified checks', () {
      final o = HomeBoardMapper.offer({
        'id': 1,
        'title': 'Yoga',
        'price': 99,
        'is_free_consultation': true,
        'delivery_options': [
          {'delivery_type': 'at_home', 'price': 40, 'is_active': true},
          {'delivery_type': 'remote', 'price': 30, 'is_active': true},
          {'delivery_type': 'at_office', 'price': 10, 'is_active': false},
        ],
        'user': {
          'verification': {
            'checks': [
              {'key': 'identity', 'state': 'verified'},
              {'key': 'phone', 'state': 'pending'},
            ],
          },
        },
      })!;
      // Web 79f0b5c8a: giá là của service, không lấy giá thấp nhất theo hình thức.
      expect(o.price, 99);
      expect(o.consultation, isFalse);
      expect(o.priceMax, isNull);
      expect(o.deliveryTypes, ['remote', 'at_home']);
      expect(o.verifiedChecks, 1);
      expect(o.freeConsultation, isTrue);
    });
  });

  test('consultation service: price range, inquiry only', () {
    final o = HomeBoardMapper.offer({
      'id': 2,
      'title': 'Sleep plan',
      'price': 80,
      'price_max': 150,
      'pricing_mode': 'consultation',
    })!;
    expect(o.consultation, isTrue);
    expect(o.price, 80);
    expect(o.priceMax, 150);
    final fixed = HomeBoardMapper.offer({
      'id': 3,
      'price': 80,
      'price_max': 150,
    })!;
    expect(fixed.priceMax, isNull);
  });

  test(
    'offers feed keeps one seed for every page, requests send none',
    () async {
      final queries = <BoardQuery>[];
      final repo = _Repo();
      final offers = BoardCubit<BoardOffer>(
        kind: BoardKind.offers,
        fetch: (q) async {
          queries.add(q);
          return Right(BoardPage(items: const [], totalPage: 3));
        },
        idOf: (o) => o.id,
        getCountries: GetBoardCountriesUseCase(repo),
      );
      await offers.start(locale: 'en');
      expect(queries.single.seed, isNotNull);
      await offers.close();

      final requests = _cubit(repo);
      await requests.start(locale: 'en');
      expect(repo.queries.single.seed, isNull);
      await requests.close();
    },
  );

  test('search v2 body follows the web filters', () {
    final body = HomeBoardRepositoryImpl.searchBody(
      BoardKind.requests,
      const BoardQuery(
        page: 1,
        keyword: ' physio ',
        locale: 'vi',
        filters: BoardFilters(
          postedDays: 7,
          delivery: 'at_home',
          price: (min: 50, max: 200),
          noResponses: true,
          country: BoardCountry(id: 230, title: 'Vietnam'),
        ),
      ),
    );
    expect(body['kinds'], ['requests']);
    expect(body['q'], 'physio');
    expect(body['sort'], 'relevance');
    expect(body['include_closed'], isTrue);
    expect(body['with_facets'], isTrue);
    expect(body['viewer_language'], 'vi');
    expect(body['filters'], {
      'created_within_days': 7,
      'delivery_types': ['at_home'],
      'price_min_usd': 50,
      'price_max_usd': 200,
      'responders_max': 0,
      'country_ids': ['230'],
    });
  });

  test('country alone uses the feed, other filters need search', () {
    const country = BoardFilters(country: BoardCountry(id: 1, title: 'X'));
    expect(const BoardQuery(filters: country).isSearch, isFalse);
    expect(
      const BoardQuery(filters: BoardFilters(sort: 'newest')).isSearch,
      isTrue,
    );
    expect(country.activeCount, 1);
  });

  group('BoardCubit', () {
    test('load more appends without duplicates, stops at last page', () async {
      final repo = _Repo()
        ..pages[1] = Right(BoardPage(items: [_req(1), _req(2)], totalPage: 2))
        ..pages[2] = Right(BoardPage(items: [_req(2), _req(3)], totalPage: 2));
      final cubit = _cubit(repo);
      await cubit.start(locale: 'en');
      await cubit.loadMore();
      expect(cubit.state.items.map((r) => r.id), [1, 2, 3]);
      expect(cubit.state.hasMore, isFalse);
      await cubit.loadMore();
      expect(repo.queries.length, 2);
      final countries = await _until(cubit, (s) => s.countries != null);
      expect(countries.countries!.single.title, 'Vietnam');
      await cubit.close();
    });

    test('search clears the topic and keeps the old list dimmed', () async {
      final repo = _Repo()
        ..pages[1] = Right(BoardPage(items: [_req(1)], totalPage: 1));
      final cubit = _cubit(repo);
      await cubit.start(locale: 'en');
      await cubit.toggleTopic(96655);
      expect(repo.queries.last.topicId, 96655);

      repo.gate = Completer<void>();
      final pending = cubit.search('yoga');
      final dimmed = await _until(cubit, (s) => s.reloading);
      expect(dimmed.items, isNotEmpty);
      repo.gate!.complete();
      await pending;
      expect(repo.queries.last.keyword, 'yoga');
      expect(repo.queries.last.topicId, isNull);
      expect(cubit.state.reloading, isFalse);
      await cubit.close();
    });

    test('first page failure → failure state, retry recovers', () async {
      final repo = _Repo()..pages[1] = Left(ServerFailure('down'));
      final cubit = _cubit(repo);
      await cubit.start(locale: 'en');
      expect(cubit.state.status, BoardStatus.failure);
      repo.pages[1] = Right(BoardPage(items: [_req(1)], totalPage: 1));
      await cubit.retry();
      expect(cubit.state.status, BoardStatus.success);
      expect(cubit.state.items.single.id, 1);
      await cubit.close();
    });
  });
}
