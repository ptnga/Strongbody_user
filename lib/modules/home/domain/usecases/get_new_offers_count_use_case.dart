import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../repositories/home_repository.dart';

class GetNewOffersCountUseCase implements UseCase<int, NoParams> {
  final HomeRepository _repository;

  GetNewOffersCountUseCase(this._repository);

  @override
  Future<Either<Failure, int>> call(NoParams params) =>
      _repository.getNewOffersCount();
}
