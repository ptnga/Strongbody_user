import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/network/exception.dart';

import '../../domain/entities/my_request_entity.dart';
import '../../domain/entities/post_request_failure.dart';
import '../../domain/entities/provider_entity.dart';
import '../../domain/entities/request_draft_entity.dart';
import '../../domain/entities/request_form_values.dart';
import '../../domain/repositories/post_request_repository.dart';
import '../datasources/remote/post_request_remote_datasource.dart';
import '../mappers/post_request_mapper.dart';

class PostRequestRepositoryImpl implements PostRequestRepository {
  final PostRequestRemoteDataSource _remote;

  PostRequestRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, String>> transcribeAudio(String audioPath) async {
    try {
      return Right(await _remote.transcribeAudio(audioPath));
    } on SpeechRateLimitException catch (e) {
      return Left(SpeechRateLimitFailure(e.message));
    } catch (e) {
      return Left(_toFailure(e, 'Speech-to-text failed'));
    }
  }

  @override
  Future<Either<Failure, RequestDraftEntity>> draftRequest({
    required String text,
    required String locale,
  }) async {
    final body = {
      'text': text,
      'locale': locale,
      'now': _localNow(),
      'timeZone': _timeZone(),
    };
    // Route AI của web đôi khi trả 502/504 khi LLM chậm → thử lại một lần.
    for (var attempt = 0; ; attempt++) {
      try {
        final dto = await _remote.draftRequest(body);
        return Right(PostRequestMapper.draft(dto, fallbackText: text));
      } catch (e) {
        final status = e is DioException ? e.response?.statusCode : null;
        final retryable = status == 502 || status == 503 || status == 504;
        if (attempt == 0 && retryable) continue;
        return Left(_toFailure(e, 'AI draft failed'));
      }
    }
  }

  @override
  Future<Either<Failure, String?>> createBuyerRequest({
    required int userId,
    required RequestFormValues values,
    RequestAssistantMeta? assistant,
    List<int> sellerUserIds = const [],
  }) async {
    try {
      if (sellerUserIds.isEmpty) {
        final formData = await PostRequestMapper.createRequestFormData(
          userId: userId,
          values: values,
          assistant: assistant,
        );
        final body = _ensureSuccess(await _remote.createBuyerRequest(formData));
        return Right(PostRequestMapper.createdStatus(body));
      }
      // BE nhận 1 `seller_id` mỗi lần → gửi lần lượt cho từng provider đã chọn.
      String? status;
      for (final sellerUserId in sellerUserIds) {
        final formData = await PostRequestMapper.createRequestFormData(
          userId: userId,
          values: values,
          assistant: assistant,
          sellerUserId: sellerUserId,
        );
        final body = _ensureSuccess(
          await _remote.createBuyerRequestToSeller(formData),
        );
        status ??= PostRequestMapper.createdStatus(body);
      }
      return Right(status);
    } catch (e) {
      return Left(_toFailure(e, 'Failed to submit request'));
    }
  }

  @override
  Future<Either<Failure, ProviderPage>> searchProviders({
    required String keyword,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final data = await _remote.searchProviders(
        keyword: keyword,
        page: page,
        limit: limit,
      );
      return Right(PostRequestMapper.providers(data));
    } catch (e) {
      return Left(_toFailure(e, 'Cannot load providers'));
    }
  }

  @override
  Future<Either<Failure, ProviderExtras>> getProviderExtras(
    ProviderEntity provider,
  ) async {
    // Hai nguồn độc lập, lỗi bên nào thì bỏ phần đó (thẻ chỉ ẩn thông tin thiếu).
    final results = await Future.wait([
      _remote
          .getProviderServices(provider.userId)
          .catchError((_) => const <Map<String, dynamic>>[]),
      provider.slug.isEmpty
          ? Future.value(const <String, dynamic>{})
          : _remote
                .getSellerProfile(provider.slug)
                .catchError((_) => const <String, dynamic>{}),
    ]);
    return Right(
      PostRequestMapper.providerExtras(
        services: results[0] as List<Map<String, dynamic>>,
        profile: results[1] as Map<String, dynamic>,
      ),
    );
  }

  @override
  Future<Either<Failure, MyRequestPage>> getMyRequests({
    required int userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final data = await _remote.getMyRequests(
        userId: userId,
        page: page,
        limit: limit,
      );
      return Right(PostRequestMapper.myRequests(data));
    } catch (e) {
      return Left(_toFailure(e, 'Cannot load your requests'));
    }
  }

  @override
  Future<Either<Failure, List<RequestOfferEntity>>> getRequestOffers(
    int requestId,
  ) async {
    try {
      final data = await _remote.getRequestOffers(requestId);
      return Right(PostRequestMapper.requestOffers(data));
    } catch (e) {
      return Left(_toFailure(e, 'Cannot load offers'));
    }
  }

  /// BE đôi khi trả HTTP 200 kèm `code` lỗi (vd 50) — coi như thất bại (giống Multime).
  dynamic _ensureSuccess(dynamic body) {
    if (body is Map) {
      final code = body['code'];
      if (code is num && code != 0 && code != 200) {
        throw ServerFailureException(
          body['message']?.toString() ?? 'Request failed',
        );
      }
    }
    return body;
  }

  Failure _toFailure(Object e, String fallback) {
    if (e is ServerFailureException) return ServerFailure(e.message);
    if (e is DioException) {
      final data = e.response?.data;
      final message = data is Map
          ? (data['message'] ?? data['error'])?.toString()
          : null;
      return ServerFailure(
        message ?? fallback,
        statusCode: e.response?.statusCode,
      );
    }
    if (e is NetworkException) return NetworkFailure(e.message);
    return Failure(e.toString());
  }

  /// Giờ địa phương "YYYY-MM-DDTHH:mm" — để AI quy đổi "ngày mai", "thứ 6 này"…
  static String _localNow() =>
      DateTime.now().toIso8601String().substring(0, 16);

  /// Dart không có tên IANA của máy → quy offset giờ chẵn về `Etc/GMT±N`
  /// (dấu ngược quy ước IANA). Offset lẻ thì để UTC (web route cũng fallback UTC).
  static String _timeZone() {
    final offset = DateTime.now().timeZoneOffset;
    if (offset.inMinutes % 60 != 0) return 'UTC';
    final hours = offset.inHours;
    if (hours == 0) return 'UTC';
    return hours > 0 ? 'Etc/GMT-$hours' : 'Etc/GMT+${-hours}';
  }
}

class ServerFailureException implements Exception {
  final String message;

  ServerFailureException(this.message);

  @override
  String toString() => message;
}
