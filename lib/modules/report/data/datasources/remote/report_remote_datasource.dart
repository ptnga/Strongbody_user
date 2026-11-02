import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';

import '../../api_config/report_api_config.dart';

/// strongbody-api trả `{code, message, data}` (code != 0/200 = lỗi, kể cả HTTP 200).
class ReportApiException implements Exception {
  final String message;

  ReportApiException(this.message);

  @override
  String toString() => message;
}

abstract class ReportRemoteDataSource {
  Future<void> submitReport(Map<String, dynamic> body);
}

class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final ApiClient _api;

  ReportRemoteDataSourceImpl(this._api);

  dynamic _unwrap(dynamic body) {
    if (body is Map) {
      final code = body['code'];
      if (code is num && code != 0 && code != 200) {
        throw ReportApiException(body['message']?.toString() ?? 'Failed');
      }
      return body.containsKey('data') ? body['data'] : body;
    }
    return body;
  }

  @override
  Future<void> submitReport(Map<String, dynamic> body) async {
    _unwrap(
      await _api.request(
        path: ReportApiConfig.reports,
        method: ApiType.post,
        data: body,
      ),
    );
  }
}
