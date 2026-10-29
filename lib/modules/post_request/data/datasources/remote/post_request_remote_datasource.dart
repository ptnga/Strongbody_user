import 'package:dio/dio.dart';

import 'package:strongbody_buyer/core/config/environment.dart';
import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';
import 'package:strongbody_buyer/core/network/exception.dart';

import '../../api_config/post_request_api_config.dart';
import '../../models/response/request_draft_response_dto.dart';

/// BE báo vượt giới hạn chuyển giọng nói.
class SpeechRateLimitException implements Exception {
  final String message;

  SpeechRateLimitException(this.message);

  @override
  String toString() => message;
}

abstract class PostRequestRemoteDataSource {
  Future<String> transcribeAudio(String audioPath);

  Future<RequestDraftResponseDto> draftRequest(Map<String, dynamic> body);

  /// Trả về body JSON của `POST /buyer/request`.
  Future<dynamic> createBuyerRequest(FormData formData);

  /// `POST /buyer/request/to-seller` — gửi riêng cho một seller.
  Future<dynamic> createBuyerRequestToSeller(FormData formData);

  /// `GET /user/strongbodyai/expert/balanced?keyword=` → `{ list, total, total_page }`.
  Future<Map<String, dynamic>> searchProviders({
    required String keyword,
    required int page,
    required int limit,
  });

  /// `GET /public/services?user_id=` → danh sách service (`data.data`).
  Future<List<Map<String, dynamic>>> getProviderServices(int userId);

  /// `GET /seller/profile/slug/{slug}` → profile (`data`).
  Future<Map<String, dynamic>> getSellerProfile(String slug);

  /// `GET /user/requests` → `{ list, total, total_page }`.
  Future<Map<String, dynamic>> getMyRequests({
    required int userId,
    required int page,
    required int limit,
  });

  /// `GET /buyer/offer/sent-offers-by-my-requests?request_id=` → `{ list, total, total_page }`.
  Future<Map<String, dynamic>> getRequestOffers(int requestId);
}

class PostRequestRemoteDataSourceImpl implements PostRequestRemoteDataSource {
  final ApiClient _apiClient;

  PostRequestRemoteDataSourceImpl(this._apiClient);

  static const _uploadTimeout = Duration(seconds: 90);

  @override
  Future<String> transcribeAudio(String audioPath) async {
    final fileName = _audioFileName(audioPath);
    dynamic body;
    try {
      body = await _apiClient.request(
        path: PostRequestApiConfig.speechToText,
        method: ApiType.post,
        data: FormData.fromMap({
          'audio_file': await MultipartFile.fromFile(
            audioPath,
            filename: fileName,
          ),
        }),
        timeout: _uploadTimeout,
      );
    } on DioException catch (e) {
      body = e.response?.data;
      if (e.response?.statusCode == 404) {
        return _transcribeViaLegacyRoute(audioPath);
      }
      if (body is! Map) rethrow;
    } on NetworkException {
      // Lỗi mạng khi gọi BE → thử route cũ của web (giống web).
      return _transcribeViaLegacyRoute(audioPath);
    }

    // BE luôn trả envelope { code, message, data }: code 0 = thành công.
    if (body is Map) {
      final code = body['code'];
      if (code == 0) {
        final data = body['data'];
        return (data is Map ? data['text']?.toString() : null)?.trim() ?? '';
      }
      if (code == PostRequestApiConfig.codeRateLimited) {
        throw SpeechRateLimitException(
          body['message']?.toString() ?? 'Rate limited',
        );
      }
      if (code == PostRequestApiConfig.codeNotFound) {
        return _transcribeViaLegacyRoute(audioPath);
      }
      throw Exception(body['message']?.toString() ?? 'Speech-to-text failed');
    }
    throw Exception('Speech-to-text failed');
  }

  Future<String> _transcribeViaLegacyRoute(String audioPath) async {
    final body = await _apiClient.request(
      path: PostRequestApiConfig.legacyTranscription,
      method: ApiType.post,
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioPath,
          filename: _audioFileName(audioPath),
        ),
        'response_format': 'json',
      }),
      timeout: _uploadTimeout,
    );
    return (body is Map ? body['text']?.toString() : null)?.trim() ?? '';
  }

  @override
  Future<RequestDraftResponseDto> draftRequest(
    Map<String, dynamic> body,
  ) async {
    final response = await _apiClient.request(
      path: PostRequestApiConfig.requestDraft,
      method: ApiType.post,
      data: body,
      timeout: _uploadTimeout,
    );
    if (response is! Map) throw Exception('Invalid draft response');
    return RequestDraftResponseDto.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  @override
  Future<dynamic> createBuyerRequest(FormData formData) {
    return _apiClient.request(
      path: PostRequestApiConfig.buyerRequest,
      method: ApiType.post,
      data: formData,
      headers: {'Accept': 'application/json'},
      timeout: _uploadTimeout,
    );
  }

  @override
  Future<dynamic> createBuyerRequestToSeller(FormData formData) {
    return _apiClient.request(
      path: PostRequestApiConfig.buyerRequestToSeller,
      method: ApiType.post,
      data: formData,
      headers: {'Accept': 'application/json'},
      timeout: _uploadTimeout,
    );
  }

  @override
  Future<Map<String, dynamic>> searchProviders({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    final body = await _apiClient.request(
      path: PostRequestApiConfig.expertsBalanced,
      method: ApiType.get,
      queryParameters: {'keyword': keyword, 'page': page, 'limit': limit},
      headers: {'x-api-key': AppConfig.publicApiKey},
      skipAuth: true,
    );
    return _dataMap(body);
  }

  @override
  Future<List<Map<String, dynamic>>> getProviderServices(int userId) async {
    final body = await _apiClient.request(
      path: PostRequestApiConfig.publicServices,
      method: ApiType.get,
      queryParameters: {'user_id': userId, 'page': 1, 'limit': 20},
      headers: {'x-api-key': AppConfig.publicApiKey},
      skipAuth: true,
    );
    final data = _dataMap(body);
    final list = data['data'] ?? data['list'];
    return list is List
        ? list.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const [];
  }

  @override
  Future<Map<String, dynamic>> getSellerProfile(String slug) async {
    final body = await _apiClient.request(
      path: PostRequestApiConfig.sellerProfileBySlug(slug),
      method: ApiType.get,
      skipAuth: true,
    );
    return _dataMap(body);
  }

  @override
  Future<Map<String, dynamic>> getMyRequests({
    required int userId,
    required int page,
    required int limit,
  }) async {
    final body = await _apiClient.request(
      path: PostRequestApiConfig.myRequests,
      method: ApiType.get,
      queryParameters: {
        'user_id': userId,
        'page': page,
        'limit': limit,
        'sort_by': 'created_at',
        'sort_order': 'desc',
      },
    );
    return _dataMap(body);
  }

  @override
  Future<Map<String, dynamic>> getRequestOffers(int requestId) async {
    final body = await _apiClient.request(
      path: PostRequestApiConfig.requestOffers,
      method: ApiType.get,
      queryParameters: {
        'request_id': requestId,
        'include_pending': true,
        'source': 'request,chat',
        'order_by': 'created_at',
        'order_dir': 'desc',
        'limit': 100,
      },
    );
    return _dataMap(body);
  }

  Map<String, dynamic> _dataMap(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  String _audioFileName(String path) {
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : 'm4a';
    return 'request-${DateTime.now().millisecondsSinceEpoch}.$ext';
  }
}
