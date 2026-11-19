import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/my_request_entity.dart';
import '../repositories/post_request_repository.dart';

class GetMatchedProvidersParams extends Equatable {
  final int requestId;
  final int page;
  final int limit;

  const GetMatchedProvidersParams({
    required this.requestId,
    this.page = 1,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [requestId, page, limit];
}

/// Chuyên gia request đã được gửi thẳng tới (web `getMatchedProviders`).
class GetMatchedProvidersUseCase
    implements UseCase<MatchedProvidersPage, GetMatchedProvidersParams> {
  final PostRequestRepository _repository;

  GetMatchedProvidersUseCase(this._repository);

  @override
  Future<Either<Failure, MatchedProvidersPage>> call(
    GetMatchedProvidersParams params,
  ) => _repository.getMatchedProviders(
    params.requestId,
    page: params.page,
    limit: params.limit,
  );
}
