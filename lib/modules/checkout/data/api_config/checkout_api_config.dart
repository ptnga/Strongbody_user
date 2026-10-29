/// Checkout offer như web `/checkout/offer` (base đã có `/v1`).
class CheckoutApiConfig {
  CheckoutApiConfig._();

  static String retryPayment(int offerId) =>
      '/buyer/offer/$offerId/retry-payment';

  /// Đọc lại offer sau khi trả (web `getOfferById`).
  static String offer(int offerId) => '/user/offer/$offerId';

  static const String paymentMethods = '/buyer/stripe/my-payment-methods';
  static const String setupIntent = '/buyer/stripe/setup-intent';

  /// IP gửi kèm checkout (web `getUserIp`).
  static const String ipLookup = 'https://api.ipify.org?format=json';

  /// `method` của web: 1 = PayPal, 2 = thẻ Stripe.
  static const int methodCard = 2;
}
