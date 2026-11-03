import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';

import '../entities/block_status.dart';
import '../entities/blocked_user_page.dart';
import '../entities/user_block.dart';

abstract class UserBlockRepository {
  Future<Either<Failure, UserBlock>> blockUser({
    required int userId,
    String? reason,
  });

  /// [blockRecordId] là id **bản ghi block**, không phải user id.
  Future<Either<Failure, Unit>> unblockUser({required int blockRecordId});

  Future<Either<Failure, BlockedUserPage>> getMyBlocked({
    int page = 1,
    int limit = 20,
  });

  Future<Either<Failure, BlockStatus>> checkBlock({required int userId});

  Future<int?> resolveBlockRecordId(int userId);
}
