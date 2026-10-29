import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/account_entities.dart';
import '../repositories/account_repository.dart';

typedef ProfileParams = ({String firstName, String lastName, String city});
typedef LedgerParams = ({int walletId, int page});
typedef LedgerPage = ({List<LionLedgerItem> items, bool hasMore});

class GetAccountProfileUseCase implements UseCase<AccountProfile, NoParams> {
  final AccountRepository _repository;
  GetAccountProfileUseCase(this._repository);

  @override
  Future<Either<Failure, AccountProfile>> call(NoParams params) =>
      _repository.getProfile();
}

class UpdateAccountProfileUseCase
    implements UseCase<AccountProfile, ProfileParams> {
  final AccountRepository _repository;
  UpdateAccountProfileUseCase(this._repository);

  @override
  Future<Either<Failure, AccountProfile>> call(ProfileParams params) =>
      _repository.updateProfile(
        firstName: params.firstName,
        lastName: params.lastName,
        city: params.city,
      );
}

/// Ví + giá trị 1 điểm (song song); thiếu giá trị vẫn trả ví.
class GetLionPointsUseCase
    implements UseCase<({LionWallet wallet, double? pointValue}), NoParams> {
  final AccountRepository _repository;
  GetLionPointsUseCase(this._repository);

  @override
  Future<Either<Failure, ({LionWallet wallet, double? pointValue})>> call(
    NoParams params,
  ) async {
    final walletFuture = _repository.getWallet();
    final valueFuture = _repository.getPointValue();
    final wallet = await walletFuture;
    final value = (await valueFuture).getOrElse((_) => null);
    return wallet.map((w) => (wallet: w, pointValue: value));
  }
}

class GetLionLedgerUseCase implements UseCase<LedgerPage, LedgerParams> {
  final AccountRepository _repository;
  GetLionLedgerUseCase(this._repository);

  @override
  Future<Either<Failure, LedgerPage>> call(LedgerParams params) =>
      _repository.getLedger(walletId: params.walletId, page: params.page);
}

class LogoutUseCase implements UseCase<Unit, NoParams> {
  final AccountRepository _repository;
  LogoutUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(NoParams params) => _repository.logout();
}
