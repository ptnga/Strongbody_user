import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';

import '../../domain/entities/board_entities.dart';
import '../../domain/repositories/home_board_repository.dart';
import '../api_config/home_board_api_config.dart';
import '../datasources/remote/home_board_remote_datasource.dart';
import '../mappers/home_board_mapper.dart';

class HomeBoardRepositoryImpl implements HomeBoardRepository {
  final HomeBoardRemoteDataSource _remote;
  final GlobalStorage _storage;

  HomeBoardRepositoryImpl(this._remote, this._storage);

  static const _size = HomeBoardApiConfig.pageSize;

  @override
  Future<Either<Failure, BoardPage<BoardRequest>>> getRequests(
    BoardQuery query,
  ) => _guard(() async {
    if (query.isSearch) {
      final hits = await _remote.search(
        BoardKind.requests.searchKind,
        searchBody(BoardKind.requests, query),
      );
      final raw = hits.ids.isEmpty
          ? const BoardRawPage()
          : await _remote.getRequests({
              'limit': hits.ids.length,
              'page': 1,
              // Rỗng thật (web gửi `status=&type=`) để BE không lọc lại theo trạng thái.
              'status': '',
              'type': '',
              'offers_limit': 1,
              'ids': hits.ids.join(','),
            });
      return _searchPage(hits, raw, query, HomeBoardMapper.request);
    }
    final raw = await _remote.getRequests({
      'limit': _size,
      'page': query.page,
      'status': 'active',
      'type': 'ldp',
      'statuses': 'active,closed',
      'offers_limit': 1,
      'country_id': ?query.filters.country?.id,
      'category_id': ?query.topicId,
    });
    return BoardPage(
      items: raw.items.map(HomeBoardMapper.request).nonNulls.toList(),
      totalPage: raw.totalPage,
    );
  }, 'Cannot load requests');

  @override
  Future<Either<Failure, BoardPage<BoardOffer>>> getOffers(BoardQuery query) =>
      _guard(() async {
        if (query.isSearch) {
          final hits = await _remote.search(
            BoardKind.offers.searchKind,
            searchBody(BoardKind.offers, query),
          );
          final raw = hits.ids.isEmpty
              ? const BoardRawPage()
              : await _remote.getServices({
                  'ids': hits.ids.join(','),
                  'limit': hits.ids.length,
                  'page': 1,
                });
          return _searchPage(hits, raw, query, HomeBoardMapper.offer);
        }
        final raw = await _remote.getServices({
          'page': query.page,
          'limit': _size,
          'order_by': 'recommended',
          'country_id': ?query.filters.country?.id,
          'seed': ?query.seed,
        }, withAuth: _storage.isLoggedIn);
        return BoardPage(
          items: raw.items.map(HomeBoardMapper.offer).nonNulls.toList(),
          totalPage: raw.totalPage,
        );
      }, 'Cannot load offers');

  @override
  Future<Either<Failure, List<BoardCountry>>> getCountries(BoardKind kind) =>
      _guard(() async {
        final raw = kind == BoardKind.requests
            ? await _remote.getRequestCountries()
            : await _remote.getServiceCountries();
        return raw
            .map(HomeBoardMapper.country)
            .nonNulls
            .where((c) => c.count > 0)
            .toList();
      }, 'Cannot load countries');

  /// Thẻ đúng thứ tự của search (id feed không trả thì bỏ).
  BoardPage<T> _searchPage<T>(
    BoardSearchHits hits,
    BoardRawPage raw,
    BoardQuery query,
    T? Function(Map<String, dynamic>) map,
  ) {
    final byId = {for (final item in raw.items) '${item['id']}': item};
    return BoardPage(
      items: [
        for (final id in hits.ids)
          if (byId['$id'] case final item?) ?map(item),
      ],
      totalPage: (hits.total / _size).ceil(),
      total: query.page == 1 ? hits.total : null,
      countryCounts: query.page == 1 ? hits.countryCounts : null,
      languages: query.page == 1 ? hits.languages : null,
    );
  }

  /// Body search v2 (web `boardSearch.ts`).
  static Map<String, dynamic> searchBody(BoardKind kind, BoardQuery query) {
    final f = query.filters;
    final q = query.keyword.trim();
    final price = f.price;
    return {
      'kinds': [kind.searchKind],
      'q': q,
      'sort': f.sort ?? (q.isNotEmpty ? 'relevance' : 'newest'),
      'page': query.page,
      'size': _size,
      'with_facets': query.page == 1,
      if (kind == BoardKind.requests) 'include_closed': true,
      'filters': {
        'created_within_days': ?f.postedDays,
        if (f.delivery != null) 'delivery_types': [f.delivery],
        'price_min_usd': ?price?.min,
        'price_max_usd': ?price?.max,
        if (kind == BoardKind.requests && f.noResponses) 'responders_max': 0,
        if (kind == BoardKind.offers && f.verified) 'verified': true,
        if (kind == BoardKind.offers && f.free) 'has_free_option': true,
        if (kind == BoardKind.offers && f.language != null)
          'languages': [f.language],
        if (f.country?.id != null) 'country_ids': ['${f.country!.id}'],
      },
      'viewer_language': query.locale,
    };
  }

  Future<Either<Failure, T>> _guard<T>(
    Future<T> Function() run,
    String message,
  ) async {
    try {
      return Right(await run());
    } catch (e) {
      return Left(ServerFailure(message));
    }
  }
}
