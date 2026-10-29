import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/my_request_entity.dart';
import '../repositories/post_request_repository.dart';

/// Offer của một request — param là `request_id`.
class GetRequestOffersUseCase
    implements UseCase<List<RequestOfferEntity>, int> {
  final PostRequestRepository _repository;

  GetRequestOffersUseCase(this._repository);

  @override
  Future<Either<Failure, List<RequestOfferEntity>>> call(int requestId) =>
      _repository.getRequestOffers(requestId);
}
