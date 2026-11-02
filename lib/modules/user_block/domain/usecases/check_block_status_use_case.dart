import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/block_status.dart';
import '../repositories/user_block_repository.dart';

class CheckBlockParams extends Equatable {
  const CheckBlockParams({required this.userId});

  final int userId;

  @override
  List<Object?> get props => [userId];
}

class CheckBlockStatusUseCase
    implements UseCase<BlockStatus, CheckBlockParams> {
  const CheckBlockStatusUseCase(this._repository);

  final UserBlockRepository _repository;

  @override
  Future<Either<Failure, BlockStatus>> call(CheckBlockParams params) =>
      _repository.checkBlock(userId: params.userId);
}
