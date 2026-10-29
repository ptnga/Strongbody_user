import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';

import '../../api_config/home_api_config.dart';

abstract class HomeRemoteDataSource {
  Future<int> getNewOffersCount();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final ApiClient _apiClient;

  HomeRemoteDataSourceImpl(this._apiClient);

  @override
  Future<int> getNewOffersCount() async {
    final body = await _apiClient.request(
      path: HomeApiConfig.sentOffersByMyRequests,
      method: ApiType.get,
      queryParameters: {'status': 'pending', 'page': 1, 'limit': 1},
    );
    // `{ data: { list, total, total_page } }`
    final data = body is Map ? body['data'] : null;
    final total = data is Map ? data['total'] : null;
    return total is num ? total.toInt() : int.tryParse('$total') ?? 0;
  }
}
