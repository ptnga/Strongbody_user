import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/board_entities.dart';
import '../repositories/home_board_repository.dart';

class GetBoardRequestsUseCase
    implements UseCase<BoardPage<BoardRequest>, BoardQuery> {
  final HomeBoardRepository _repository;

  GetBoardRequestsUseCase(this._repository);

  @override
  Future<Either<Failure, BoardPage<BoardRequest>>> call(BoardQuery query) =>
      _repository.getRequests(query);
}

class GetBoardOffersUseCase
    implements UseCase<BoardPage<BoardOffer>, BoardQuery> {
  final HomeBoardRepository _repository;

  GetBoardOffersUseCase(this._repository);

  @override
  Future<Either<Failure, BoardPage<BoardOffer>>> call(BoardQuery query) =>
      _repository.getOffers(query);
}

class GetBoardCountriesUseCase
    implements UseCase<List<BoardCountry>, BoardKind> {
  final HomeBoardRepository _repository;

  GetBoardCountriesUseCase(this._repository);

  @override
  Future<Either<Failure, List<BoardCountry>>> call(BoardKind kind) =>
      _repository.getCountries(kind);
}
