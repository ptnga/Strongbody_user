import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';

import '../entities/checkout_entities.dart';

abstract class CheckoutRepository {
  Future<Either<Failure, List<PaymentCard>>> getCards();

  /// Thêm thẻ (setup intent → PaymentSheet) rồi trả danh sách thẻ mới; cancelled = Right(null).
  Future<Either<Failure, List<PaymentCard>?>> addCard();

  /// `retry-payment` → (nếu cần) Stripe → đọc lại offer để biết đã paid chưa.
  Future<Either<Failure, OfferPaymentResult>> payOffer(
    OfferPaymentRequest request,
  );
}
