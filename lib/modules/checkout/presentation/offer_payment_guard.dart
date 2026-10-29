/// Offer đã trả (paid / đang xác nhận) trong phiên này. BE có thể vẫn trả `pending` một lúc
/// (webhook Stripe trễ) và `retry-payment` tạo PaymentIntent MỚI mỗi lần gọi → khoá
/// "Accept & Pay" của offer này để không trừ tiền hai lần.
abstract final class OfferPaymentGuard {
  static final _submitted = <int>{};

  static bool isSubmitted(int offerId) => _submitted.contains(offerId);

  static void markSubmitted(int offerId) => _submitted.add(offerId);
}
