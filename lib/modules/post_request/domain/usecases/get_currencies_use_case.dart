import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/posted_request_entity.dart';
import '../repositories/post_request_repository.dart';

/// Tiền tệ của ô Budget trong form request.
class GetCurrenciesUseCase implements UseCase<List<CurrencyOption>, NoParams> {
  final PostRequestRepository _repository;

  GetCurrenciesUseCase(this._repository);

  @override
  Future<Either<Failure, List<CurrencyOption>>> call(NoParams params) =>
      _repository.getCurrencies();
}
