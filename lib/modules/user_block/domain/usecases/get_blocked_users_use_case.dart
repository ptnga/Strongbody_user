import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/blocked_user_page.dart';
import '../repositories/user_block_repository.dart';

class BlockedUsersParams extends Equatable {
  const BlockedUsersParams({this.page = 1, this.limit = 20});

  final int page;
  final int limit;

  @override
  List<Object?> get props => [page, limit];
}

class GetBlockedUsersUseCase
    implements UseCase<BlockedUserPage, BlockedUsersParams> {
  const GetBlockedUsersUseCase(this._repository);

  final UserBlockRepository _repository;

  @override
  Future<Either<Failure, BlockedUserPage>> call(BlockedUsersParams params) =>
      _repository.getMyBlocked(page: params.page, limit: params.limit);
}
