import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/checkout_entities.dart';
import '../repositories/checkout_repository.dart';

class GetPaymentCardsUseCase implements UseCase<List<PaymentCard>, NoParams> {
  final CheckoutRepository _repository;
  GetPaymentCardsUseCase(this._repository);

  @override
  Future<Either<Failure, List<PaymentCard>>> call(NoParams params) =>
      _repository.getCards();
}

class AddPaymentCardUseCase implements UseCase<List<PaymentCard>?, NoParams> {
  final CheckoutRepository _repository;
  AddPaymentCardUseCase(this._repository);

  @override
  Future<Either<Failure, List<PaymentCard>?>> call(NoParams params) =>
      _repository.addCard();
}

class PayOfferUseCase
    implements UseCase<OfferPaymentResult, OfferPaymentRequest> {
  final CheckoutRepository _repository;
  PayOfferUseCase(this._repository);

  @override
  Future<Either<Failure, OfferPaymentResult>> call(
    OfferPaymentRequest params,
  ) => _repository.payOffer(params);
}
