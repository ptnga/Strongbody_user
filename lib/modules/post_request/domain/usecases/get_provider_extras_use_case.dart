import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/provider_entity.dart';
import '../repositories/post_request_repository.dart';

class GetProviderExtrasUseCase
    implements UseCase<ProviderExtras, ProviderEntity> {
  final PostRequestRepository _repository;

  GetProviderExtrasUseCase(this._repository);

  @override
  Future<Either<Failure, ProviderExtras>> call(ProviderEntity provider) =>
      _repository.getProviderExtras(provider);
}
