import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../repositories/user_block_repository.dart';

class UnblockUserParams extends Equatable {
  const UnblockUserParams({required this.blockRecordId});

  /// Id **bản ghi block**, không phải user id.
  final int blockRecordId;

  @override
  List<Object?> get props => [blockRecordId];
}

class UnblockUserUseCase implements UseCase<Unit, UnblockUserParams> {
  const UnblockUserUseCase(this._repository);

  final UserBlockRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(UnblockUserParams params) =>
      _repository.unblockUser(blockRecordId: params.blockRecordId);
}
