import 'package:dio/dio.dart';

import 'package:strongbody_buyer/core/config/environment.dart';
import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';

import '../../api_config/social_market_api_config.dart';

/// Một trang list thô: `items` + phân trang (services/experts trả `data.list`,
/// solutions trả `data.data` — đọc cả hai như web `readPage`).
class RawListPage {
  final List<Map<String, dynamic>> items;
  final int total;
  final int totalPages;

  const RawListPage({
    required this.items,
    required this.total,
    required this.totalPages,
  });
}

abstract class SocialMarketRemoteDataSource {
  Future<RawListPage> getServices(Map<String, dynamic> query);

  Future<RawListPage> getExperts(Map<String, dynamic> query);

  Future<RawListPage> getPublicOffers({required int page, required int limit});

  Future<RawListPage> getPublicRequests({
    required int page,
    required int limit,
  });

  Future<RawListPage> getHealthSolutions(Map<String, dynamic> query);

  /// `items[]` của `POST /user/engagement/summary`; gắn token nếu đã đăng nhập.
  Future<List<Map<String, dynamic>>> getEngagementSummary({
    required String targetType,
    required List<int> targetIds,
    required bool withAuth,
  });

  /// Like/save (POST) hoặc bỏ (DELETE) → số đếm mới (`count`).
  Future<int?> setEngagement({
    required String kind,
    required String targetType,
    required int targetId,
    required bool on,
  });

  /// `POST /user/inquiries` → `data` (có `inquiry.recipient_user_id`).
  Future<Map<String, dynamic>> createInquiry(
    Map<String, dynamic> fields,
    List<String> attachmentPaths,
  );

  Future<bool> checkMessageService({
    required int serviceId,
    required String channelId,
  });

  Future<void> sendMessageService({
    required int serviceId,
    required String channelId,
  });

  /// → `matched_count`.
  Future<int> createHealthSolutionMatching({
    required int solutionId,
    required String role,
    required String message,
  });

  // Medical Travel
  Future<RawListPage> getFeaturedExperts(Map<String, dynamic> query);

  /// Nước có service / seller Medical Travel (`data.data`).
  Future<List<Map<String, dynamic>>> getDestinations();

  /// `data` của `GET /buyer/service/{id}`.
  Future<Map<String, dynamic>> getServiceDetail(int id);

  Future<void> createAppointmentRequest(Map<String, dynamic> body);

  /// `data` của `GET /country?code=`; rỗng khi không có.
  Future<Map<String, dynamic>> getCountryByCode(String code);

  Future<List<Map<String, dynamic>>> getActiveCountries();
}

class SocialMarketRemoteDataSourceImpl implements SocialMarketRemoteDataSource {
  final ApiClient _apiClient;

  SocialMarketRemoteDataSourceImpl(this._apiClient);

  static Map<String, dynamic> get _publicHeaders => {
    'x-api-key': AppConfig.publicApiKey,
  };

  Future<dynamic> _public(String path, Map<String, dynamic> query) =>
      _apiClient.request(
        path: path,
        method: ApiType.get,
        queryParameters: query,
        headers: _publicHeaders,
        skipAuth: true,
      );

  static Map<String, dynamic> _data(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  /// HTTP 200 nhưng `code` báo lỗi (BE: 0 = OK) → ném để repository trả Failure.
  static dynamic _ok(dynamic body) {
    final code = body is Map ? body['code'] : null;
    if (code is num && code != 0 && code != 200) {
      throw Exception(body['message']?.toString() ?? 'Request failed ($code)');
    }
    return body;
  }

  static List<Map<String, dynamic>> _maps(Object? raw) => raw is List
      ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : const [];

  static RawListPage _page(dynamic body) {
    final data = _data(body);
    final items = _maps(data['list'] ?? data['data']);
    final total = num.tryParse('${data['total']}')?.toInt() ?? items.length;
    final pages =
        num.tryParse('${data['total_page']}')?.toInt() ??
        (items.isEmpty ? 0 : 1);
    return RawListPage(items: items, total: total, totalPages: pages);
  }

  @override
  Future<RawListPage> getServices(Map<String, dynamic> query) async =>
      _page(await _public(SocialMarketApiConfig.publicServices, query));

  @override
  Future<RawListPage> getExperts(Map<String, dynamic> query) async =>
      _page(await _public(SocialMarketApiConfig.expertsBalanced, query));

  @override
  Future<RawListPage> getPublicOffers({
    required int page,
    required int limit,
  }) async => _page(
    await _public(SocialMarketApiConfig.publicOffers, {
      'limit': limit,
      'page': page,
      'status': 'active',
    }),
  );

  @override
  Future<RawListPage> getPublicRequests({
    required int page,
    required int limit,
  }) async => _page(
    await _public(SocialMarketApiConfig.publicRequestsWithOffers, {
      'limit': limit,
      'page': page,
      'status': 'active',
      'type': 'ldp',
    }),
  );

  @override
  Future<RawListPage> getHealthSolutions(Map<String, dynamic> query) async =>
      _page(await _public(SocialMarketApiConfig.healthSolutions, query));

  @override
  Future<List<Map<String, dynamic>>> getEngagementSummary({
    required String targetType,
    required List<int> targetIds,
    required bool withAuth,
  }) async {
    final body = await _apiClient.request(
      path: SocialMarketApiConfig.engagementSummary,
      method: ApiType.post,
      data: {'target_type': targetType, 'target_ids': targetIds},
      // Optional JWT: khách vẫn có số đếm (my_state = false).
      skipAuth: !withAuth,
    );
    final data = body is Map ? (body['data'] ?? body) : null;
    return data is Map ? _maps(data['items']) : const [];
  }

  @override
  Future<int?> setEngagement({
    required String kind,
    required String targetType,
    required int targetId,
    required bool on,
  }) async {
    final body = await _apiClient.request(
      path: SocialMarketApiConfig.engagement(kind, targetType, targetId),
      method: on ? ApiType.post : ApiType.delete,
    );
    final data = body is Map ? (body['data'] ?? body) : null;
    return data is Map ? num.tryParse('${data['count']}')?.toInt() : null;
  }

  @override
  Future<Map<String, dynamic>> createInquiry(
    Map<String, dynamic> fields,
    List<String> attachmentPaths,
  ) async {
    final clean = {
      for (final e in fields.entries)
        if (e.value != null && e.value != '') e.key: e.value,
    };
    // Có file → multipart (field rỗng bỏ qua), không thì JSON — như web `createInquiry`.
    final Object data;
    if (attachmentPaths.isEmpty) {
      data = clean;
    } else {
      final form = FormData();
      clean.forEach((k, v) => form.fields.add(MapEntry(k, '$v')));
      for (final path in attachmentPaths) {
        form.files.add(
          MapEntry('attachments', await MultipartFile.fromFile(path)),
        );
      }
      data = form;
    }
    final body = _ok(
      await _apiClient.request(
        path: SocialMarketApiConfig.inquiries,
        method: ApiType.post,
        data: data,
      ),
    );
    final result = body is Map ? (body['data'] ?? body) : null;
    return result is Map ? Map<String, dynamic>.from(result) : const {};
  }

  @override
  Future<bool> checkMessageService({
    required int serviceId,
    required String channelId,
  }) async {
    final body = await _apiClient.request(
      path: SocialMarketApiConfig.messageServiceCheck,
      method: ApiType.get,
      queryParameters: {'service_id': serviceId, 'channel_id': channelId},
    );
    return _data(body)['allowed'] == true;
  }

  @override
  Future<void> sendMessageService({
    required int serviceId,
    required String channelId,
  }) async {
    await _apiClient.request(
      path: SocialMarketApiConfig.messageService,
      method: ApiType.post,
      data: {'service_id': serviceId, 'channel_id': channelId},
    );
  }

  @override
  Future<int> createHealthSolutionMatching({
    required int solutionId,
    required String role,
    required String message,
  }) async {
    final body = _ok(
      await _apiClient.request(
        path: SocialMarketApiConfig.healthSolutionMatching(solutionId),
        method: ApiType.post,
        data: {'role': role, 'message': message},
      ),
    );
    final data = body is Map ? (body['data'] ?? body) : null;
    return data is Map
        ? num.tryParse('${data['matched_count']}')?.toInt() ?? 0
        : 0;
  }

  @override
  Future<RawListPage> getFeaturedExperts(Map<String, dynamic> query) async =>
      _page(await _public(SocialMarketApiConfig.expertsFeatured, query));

  @override
  Future<List<Map<String, dynamic>>> getDestinations() async {
    final body = _ok(
      await _public(SocialMarketApiConfig.countryDestinations, {
        'is_medical_travel': true,
      }),
    );
    return _maps(_data(body)['data']);
  }

  @override
  Future<Map<String, dynamic>> getServiceDetail(int id) async => _data(
    _ok(
      await _apiClient.request(
        path: SocialMarketApiConfig.buyerService(id),
        method: ApiType.get,
        skipAuth: true,
      ),
    ),
  );

  @override
  Future<void> createAppointmentRequest(Map<String, dynamic> body) async {
    _ok(
      await _apiClient.request(
        path: SocialMarketApiConfig.appointmentRequest,
        method: ApiType.post,
        data: body,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> getCountryByCode(String code) async => _data(
    _ok(
      await _public(SocialMarketApiConfig.countryByCode, {
        'code': code.toUpperCase(),
      }),
    ),
  );

  @override
  Future<List<Map<String, dynamic>>> getActiveCountries() async => _maps(
    _data(
      _ok(
        await _public(SocialMarketApiConfig.activeCountries, {'limit': 3000}),
      ),
    )['data'],
  );
}
