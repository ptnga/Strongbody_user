import 'package:strongbody_buyer/core/config/environment.dart';
import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';

import '../../api_config/home_board_api_config.dart';

/// Body thô của một trang: `data.list` (hoặc `data.data`) + `data.total_page`.
class BoardRawPage {
  final List<Map<String, dynamic>> items;
  final int totalPage;

  const BoardRawPage({this.items = const [], this.totalPage = 0});
}

/// Kết quả search v2 của một loại: id theo thứ tự + tổng + facet.
class BoardSearchHits {
  final List<int> ids;
  final int total;

  /// `facets.country_id` → id nước : số item.
  final Map<int, int> countryCounts;

  /// `facets.languages` (service).
  final List<String> languages;

  const BoardSearchHits({
    this.ids = const [],
    this.total = 0,
    this.countryCounts = const {},
    this.languages = const [],
  });
}

abstract class HomeBoardRemoteDataSource {
  Future<BoardRawPage> getRequests(Map<String, dynamic> query);

  Future<List<Map<String, dynamic>>> getRequestCountries();

  /// [withAuth] = gửi token khi đã đăng nhập (thứ tự "recommended" theo người xem).
  Future<BoardRawPage> getServices(
    Map<String, dynamic> query, {
    bool withAuth = false,
  });

  Future<List<Map<String, dynamic>>> getServiceCountries();

  Future<BoardSearchHits> search(String kind, Map<String, dynamic> body);
}

class HomeBoardRemoteDataSourceImpl implements HomeBoardRemoteDataSource {
  final ApiClient _apiClient;

  HomeBoardRemoteDataSourceImpl(this._apiClient);

  static Map<String, dynamic> get _publicHeaders => {
    'x-api-key': AppConfig.publicApiKey,
    'Accept': 'application/json',
  };

  Future<dynamic> _get(
    String path,
    Map<String, dynamic> query, {
    bool withAuth = false,
  }) => _apiClient.request(
    path: path,
    method: ApiType.get,
    queryParameters: query,
    headers: _publicHeaders,
    skipAuth: !withAuth,
  );

  static Map<String, dynamic> _data(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  static List<Map<String, dynamic>> _maps(Object? raw) => raw is List
      ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : const [];

  static BoardRawPage _page(dynamic body) {
    final data = _data(body);
    return BoardRawPage(
      items: _maps(data['list'] ?? data['data']),
      totalPage: num.tryParse('${data['total_page']}')?.toInt() ?? 0,
    );
  }

  /// Facet nước: BE trả 200 mà thiếu `data.list` → coi như lỗi (web).
  static List<Map<String, dynamic>> _countries(dynamic body) {
    final list = _data(body)['list'];
    if (list is! List) throw const FormatException('countries: no list');
    return _maps(list);
  }

  @override
  Future<BoardRawPage> getRequests(Map<String, dynamic> query) async =>
      _page(await _get(HomeBoardApiConfig.requests, query));

  @override
  Future<List<Map<String, dynamic>>> getRequestCountries() async => _countries(
    await _get(HomeBoardApiConfig.requestCountries, {
      'status': 'active',
      'type': 'ldp',
      'statuses': 'active,closed',
    }),
  );

  @override
  Future<BoardRawPage> getServices(
    Map<String, dynamic> query, {
    bool withAuth = false,
  }) async =>
      _page(await _get(HomeBoardApiConfig.services, query, withAuth: withAuth));

  @override
  Future<List<Map<String, dynamic>>> getServiceCountries() async =>
      _countries(await _get(HomeBoardApiConfig.serviceCountries, const {}));

  @override
  Future<BoardSearchHits> search(String kind, Map<String, dynamic> body) async {
    final res = await _apiClient.request(
      path: HomeBoardApiConfig.search,
      method: ApiType.post,
      data: body,
      headers: _publicHeaders,
      skipAuth: true,
    );
    final results = _data(res)['results'];
    final group = results is Map ? results[kind] : null;
    final hits = group is Map ? group['hits'] : null;
    if (hits is! List) throw const FormatException('search: no hits');
    final facets = group['facets'];
    final countries = facets is Map ? facets['country_id'] : null;
    final languages = facets is Map ? facets['languages'] : null;
    int? id(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    return BoardSearchHits(
      ids: [
        for (final h in hits)
          if (h is Map) ?id(h['id']),
      ],
      total: id(group['total']) ?? hits.length,
      countryCounts: {
        if (countries is List)
          for (final f in countries.whereType<Map>())
            ?id(f['key']): id(f['count']) ?? 0,
      },
      languages: [
        if (languages is List)
          for (final f in languages.whereType<Map>())
            if ('${f['key'] ?? ''}'.isNotEmpty) '${f['key']}',
      ],
    );
  }
}
