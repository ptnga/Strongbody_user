import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/posted_request_entity.dart';
import '../repositories/post_request_repository.dart';

/// Request vừa đăng — param là id request.
class GetSentRequestUseCase implements UseCase<SentRequest, int> {
  final PostRequestRepository _repository;

  GetSentRequestUseCase(this._repository);

  @override
  Future<Either<Failure, SentRequest>> call(int id) =>
      _repository.getSentRequest(id);
}
