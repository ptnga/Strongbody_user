import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/my_request_entity.dart';
import '../repositories/post_request_repository.dart';

class GetMyRequestsParams extends Equatable {
  final int userId;
  final int page;
  final int limit;

  const GetMyRequestsParams({
    required this.userId,
    this.page = 1,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [userId, page, limit];
}

class GetMyRequestsUseCase
    implements UseCase<MyRequestPage, GetMyRequestsParams> {
  final PostRequestRepository _repository;

  GetMyRequestsUseCase(this._repository);

  @override
  Future<Either<Failure, MyRequestPage>> call(GetMyRequestsParams params) =>
      _repository.getMyRequests(
        userId: params.userId,
        page: params.page,
        limit: params.limit,
      );
}
