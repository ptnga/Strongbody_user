import 'package:equatable/equatable.dart';

/// Thẻ đã lưu (`GET /buyer/stripe/my-payment-methods` → `data.payment_methods`).
class PaymentCard extends Equatable {
  final String id;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;

  const PaymentCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
  });

  @override
  List<Object?> get props => [id, brand, last4, expMonth, expYear];
}

/// paid = đã trả xong; pending = Stripe đã nhận, chờ backend xác nhận (webhook).
enum OfferPaymentResult { paid, pending, failed, cancelled }

/// Body `POST /buyer/offer/{id}/retry-payment` — như web `handleConfirmOrder`.
class OfferPaymentRequest extends Equatable {
  final int offerId;
  final int pointsUsed;
  final double pointsValue;
  final String? voucherCode;

  /// Thẻ trả tiền; null khi tổng = 0 (backend tự đánh dấu paid).
  final String? paymentMethodId;

  const OfferPaymentRequest({
    required this.offerId,
    this.pointsUsed = 0,
    this.pointsValue = 0,
    this.voucherCode,
    this.paymentMethodId,
  });

  @override
  List<Object?> get props => [
    offerId,
    pointsUsed,
    pointsValue,
    voucherCode,
    paymentMethodId,
  ];
}

/// Offer đọc lại lúc mở checkout (web `getOfferById` → `/user/offer/{id}`): chặn offer đã
/// trả / đã huỷ, lấy điểm + voucher đã áp mới nhất.
class CheckoutOfferSnapshot extends Equatable {
  final String status;
  final String paymentStatus;
  final double? price;
  final int pointsUsed;
  final double pointsValue;
  final double voucherValue;
  final String? voucherCode;

  const CheckoutOfferSnapshot({
    this.status = '',
    this.paymentStatus = '',
    this.price,
    this.pointsUsed = 0,
    this.pointsValue = 0,
    this.voucherValue = 0,
    this.voucherCode,
  });

  bool get isPaid => paymentStatus == 'paid';
  bool get isCancelled => status == 'cancelled' || status == 'canceled';

  @override
  List<Object?> get props => [
    status,
    paymentStatus,
    price,
    pointsUsed,
    pointsValue,
    voucherValue,
    voucherCode,
  ];
}
