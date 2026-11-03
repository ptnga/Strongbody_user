import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/network/exception.dart';

import '../../domain/entities/report_reason.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/remote/report_remote_datasource.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ReportRemoteDataSource _remote;
  final GlobalStorage _storage;

  ReportRepositoryImpl(this._remote, this._storage);

  @override
  Future<Either<Failure, Unit>> reportUser({
    required int reportedUserId,
    required ReportReason reason,
    String? note,
    String context = 'chat',
  }) async {
    try {
      final trimmed = note?.trim() ?? '';
      // Mirror payload Provider (`reporter_id` + `type` + `content`); Provider báo
      // cáo bài viết nên dùng `post_id`, báo cáo NGƯỜI dùng ở đây dùng
      // `reported_id`. reporter_id gửi tường minh vì reports không tự lấy từ JWT
      // (khác user_blocks).
      await _remote.submitReport({
        if (_storage.userId != null) 'reporter_id': _storage.userId,
        'reported_id': reportedUserId,
        'type': reason.code,
        if (trimmed.isNotEmpty) 'content': trimmed,
        'context': context,
      });
      return const Right(unit);
    } on ReportApiException catch (e) {
      return Left(ServerFailure(e.message));
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['message']?.toString() : null;
      return Left(
        ServerFailure(
          message ?? 'Create report failed',
          statusCode: e.response?.statusCode,
        ),
      );
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(Failure('Create report failed'));
    }
  }
}
