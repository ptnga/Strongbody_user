import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';

import '../../api_config/checkout_api_config.dart';

class CheckoutApiException implements Exception {
  final String message;

  CheckoutApiException(this.message);

  @override
  String toString() => message;
}

abstract class CheckoutRemoteDataSource {
  Future<List<Map<String, dynamic>>> getPaymentMethods();
  Future<String> createSetupIntent();
  Future<Map<String, dynamic>> retryPayment(
    int offerId,
    Map<String, dynamic> body,
  );
  Future<Map<String, dynamic>> getOffer(int offerId);
  Future<String?> publicIp();
}

class CheckoutRemoteDataSourceImpl implements CheckoutRemoteDataSource {
  final ApiClient _api;

  CheckoutRemoteDataSourceImpl(this._api);

  Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  dynamic _unwrap(dynamic body) {
    if (body is Map) {
      final code = body['code'];
      if (code is num && code != 0 && code != 200) {
        throw CheckoutApiException(body['message']?.toString() ?? 'Failed');
      }
      return body['data'];
    }
    return body;
  }

  @override
  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final data = _map(
      _unwrap(
        await _api.request(
          path: CheckoutApiConfig.paymentMethods,
          method: ApiType.get,
        ),
      ),
    );
    final list = data['payment_methods'];
    return list is List
        ? list.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const [];
  }

  @override
  Future<String> createSetupIntent() async {
    final data = _map(
      _unwrap(
        await _api.request(
          path: CheckoutApiConfig.setupIntent,
          method: ApiType.post,
        ),
      ),
    );
    final secret = data['client_secret']?.toString();
    if (secret == null || secret.isEmpty) {
      throw CheckoutApiException('No setup intent');
    }
    return secret;
  }

  @override
  Future<Map<String, dynamic>> retryPayment(
    int offerId,
    Map<String, dynamic> body,
  ) async => _map(
    _unwrap(
      await _api.request(
        path: CheckoutApiConfig.retryPayment(offerId),
        method: ApiType.post,
        data: body,
        timeout: const Duration(seconds: 60),
      ),
    ),
  );

  @override
  Future<Map<String, dynamic>> getOffer(int offerId) async => _map(
    _unwrap(
      await _api.request(
        path: CheckoutApiConfig.offer(offerId),
        method: ApiType.get,
      ),
    ),
  );

  @override
  Future<String?> publicIp() async {
    try {
      final body = await _api.request(
        path: CheckoutApiConfig.ipLookup,
        method: ApiType.get,
        skipAuth: true,
        timeout: const Duration(seconds: 5),
      );
      return body is Map ? body['ip']?.toString() : null;
    } catch (_) {
      return null;
    }
  }
}
