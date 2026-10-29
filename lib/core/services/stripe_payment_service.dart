import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_stripe/flutter_stripe.dart';

import '../config/environment.dart';
import '../utils/app_logger.dart';

enum StripeResult { success, processing, cancelled, failed }

/// Stripe trên máy — cùng vai trò `stripe.confirmCardPayment` / `confirmCardSetup` của web.
abstract class StripePaymentService {
  /// Trả tiền PaymentIntent bằng thẻ đã lưu (tự xử lý 3DS).
  Future<StripeResult> confirmWithCard({
    required String clientSecret,
    required String paymentMethodId,
  });

  /// Lưu thẻ mới cho customer bằng SetupIntent (PaymentSheet chế độ setup).
  Future<StripeResult> addCard(String setupIntentClientSecret);
}

class StripePaymentServiceImpl implements StripePaymentService {
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    Stripe.publishableKey = AppConfig.stripePublishableKey;
    await Stripe.instance.applySettings();
    _ready = true;
  }

  @override
  Future<StripeResult> confirmWithCard({
    required String clientSecret,
    required String paymentMethodId,
  }) async {
    try {
      await _ensureReady();
      final intent = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.cardFromMethodId(
          paymentMethodData: PaymentMethodDataCardFromMethod(
            paymentMethodId: paymentMethodId,
          ),
        ),
      );
      return switch (intent.status) {
        PaymentIntentsStatus.Succeeded => StripeResult.success,
        PaymentIntentsStatus.Processing => StripeResult.processing,
        _ => StripeResult.failed,
      };
    } on StripeException catch (e) {
      AppLogger.w('Stripe confirm failed', e.error.localizedMessage);
      return e.error.code == FailureCode.Canceled
          ? StripeResult.cancelled
          : StripeResult.failed;
    } catch (e) {
      AppLogger.w('Stripe confirm failed', e);
      return StripeResult.failed;
    }
  }

  @override
  Future<StripeResult> addCard(String setupIntentClientSecret) async {
    try {
      await _ensureReady();
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: setupIntentClientSecret,
          merchantDisplayName: 'StrongBody',
          style: ThemeMode.light,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return StripeResult.success;
    } on StripeException catch (e) {
      return e.error.code == FailureCode.Canceled
          ? StripeResult.cancelled
          : StripeResult.failed;
    } catch (e) {
      AppLogger.w('Stripe add card failed', e);
      return StripeResult.failed;
    }
  }
}
