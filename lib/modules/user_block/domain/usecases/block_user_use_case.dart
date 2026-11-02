import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/user_block.dart';
import '../repositories/user_block_repository.dart';

class BlockUserParams extends Equatable {
  const BlockUserParams({required this.userId, this.reason});

  final int userId;
  final String? reason;

  @override
  List<Object?> get props => [userId, reason];
}

class BlockUserUseCase implements UseCase<UserBlock, BlockUserParams> {
  const BlockUserUseCase(this._repository);

  final UserBlockRepository _repository;

  @override
  Future<Either<Failure, UserBlock>> call(BlockUserParams params) =>
      _repository.blockUser(userId: params.userId, reason: params.reason);
}
