import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/network/exception.dart';
import 'package:strongbody_buyer/core/utils/app_logger.dart';

import '../../domain/entities/block_status.dart';
import '../../domain/entities/blocked_user_page.dart';
import '../../domain/entities/user_block.dart';
import '../../domain/entities/user_block_error.dart';
import '../../domain/repositories/user_block_repository.dart';
import '../datasources/remote/user_block_remote_datasource.dart';
import '../models/block_status_dto.dart';
import '../models/blocked_user_page_dto.dart';
import '../models/user_block_dto.dart';
import '../models/user_block_error_mapper.dart';

class UserBlockRepositoryImpl implements UserBlockRepository {
  final UserBlockRemoteDataSource _remote;

  UserBlockRepositoryImpl(this._remote);

  /// Đưa mọi lỗi về `UserBlockFailure` có `kind`.
  Failure _asFailure(Object error) {
    if (error is UserBlockApiException) {
      return UserBlockErrorMapper.map(error.code, error.message);
    }
    if (error is NetworkException) {
      return UserBlockErrorMapper.network(error);
    }
    if (error is DioException) {
      if (error.response == null) return UserBlockErrorMapper.network(error);
      final data = error.response?.data;
      final code = data is Map ? (data['code'] as num?)?.toInt() : null;
      final message = data is Map ? data['message']?.toString() : null;
      return UserBlockErrorMapper.map(
        code ?? error.response?.statusCode ?? 0,
        message ?? error.message ?? 'Request failed',
      );
    }
    return UserBlockErrorMapper.network(error);
  }

  Failure _logged(String action, Object error) {
    final failure = _asFailure(error);
    final kind = failure is UserBlockFailure ? failure.kind.name : 'unmapped';
    AppLogger.e('$action failed ($kind): ${failure.message}');
    return failure;
  }

  @override
  Future<Either<Failure, UserBlock>> blockUser({
    required int userId,
    String? reason,
  }) async {
    try {
      return Right(UserBlockDto.toEntity(await _remote.block(userId, reason: reason)));
    } catch (error) {
      return Left(_logged('Block user $userId', error));
    }
  }

  @override
  Future<Either<Failure, Unit>> unblockUser({
    required int blockRecordId,
  }) async {
    try {
      await _remote.unblock(blockRecordId);
      return const Right(unit);
    } catch (error) {
      return Left(_logged('Unblock record $blockRecordId', error));
    }
  }

  @override
  Future<Either<Failure, BlockedUserPage>> getMyBlocked({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      return Right(
        BlockedUserPageDto.toEntity(
          await _remote.myBlocked(page: page, limit: limit),
        ),
      );
    } catch (error) {
      return Left(_logged('Load blocked users', error));
    }
  }

  @override
  Future<Either<Failure, BlockStatus>> checkBlock({required int userId}) async {
    try {
      return Right(BlockStatusDto.toEntity(await _remote.check(userId)));
    } catch (error) {
      return Left(_logged('Check block $userId', error));
    }
  }

  @override
  Future<int?> resolveBlockRecordId(int userId) async {
    // Quét tối đa 5 trang: dò vô hạn sẽ treo nút đang chờ.
    for (var page = 1; page <= 5; page++) {
      final result = await getMyBlocked(page: page, limit: 100);
      final found = result.fold((_) => null, (data) {
        for (final item in data.items) {
          if (item.userId == userId) return item.blockRecordId;
        }
        return data.hasMore ? -1 : null;
      });
      if (found == null) return null;
      if (found > 0) return found;
    }
    return null;
  }
}
