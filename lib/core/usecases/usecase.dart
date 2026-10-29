import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../base/failure.dart';

abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
