import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/network/exception.dart';
import 'package:strongbody_buyer/core/services/stripe_payment_service.dart';

import '../../domain/entities/checkout_entities.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../api_config/checkout_api_config.dart';
import '../datasources/remote/checkout_remote_datasource.dart';

class CheckoutRepositoryImpl implements CheckoutRepository {
  final CheckoutRemoteDataSource _remote;
  final StripePaymentService _stripe;

  /// Chờ backend xác nhận sau Stripe (web: Pusher `offer_paid`, timeout 5 s).
  final Duration pollInterval;
  final int pollAttempts;

  CheckoutRepositoryImpl(
    this._remote,
    this._stripe, {
    this.pollInterval = const Duration(seconds: 2),
    this.pollAttempts = 5,
  });

  Failure _toFailure(Object e, String fallback) {
    if (e is CheckoutApiException) return ServerFailure(e.message);
    if (e is DioException) {
      final data = e.response?.data;
      final message = data is Map ? data['message']?.toString() : null;
      return ServerFailure(
        message ?? fallback,
        statusCode: e.response?.statusCode,
      );
    }
    if (e is NetworkException) return NetworkFailure(e.message);
    return Failure(fallback);
  }

  static PaymentCard? _card(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final card = json['card'] is Map ? Map.from(json['card'] as Map) : json;
    int n(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return PaymentCard(
      id: id,
      brand: '${card['brand'] ?? ''}',
      last4: '${card['last4'] ?? ''}',
      expMonth: n(card['exp_month']),
      expYear: n(card['exp_year']),
    );
  }

  @override
  Future<Either<Failure, List<PaymentCard>>> getCards() async {
    try {
      final raw = await _remote.getPaymentMethods();
      return Right(raw.map(_card).nonNulls.toList());
    } catch (e) {
      return Left(_toFailure(e, 'Cannot load your cards'));
    }
  }

  @override
  Future<Either<Failure, List<PaymentCard>?>> addCard() async {
    try {
      final secret = await _remote.createSetupIntent();
      final result = await _stripe.addCard(secret);
      if (result == StripeResult.cancelled) return const Right(null);
      if (result != StripeResult.success) {
        return Left(Failure('Cannot add this card'));
      }
      return getCards();
    } catch (e) {
      return Left(_toFailure(e, 'Cannot add this card'));
    }
  }

  @override
  Future<Either<Failure, OfferPaymentResult>> payOffer(
    OfferPaymentRequest request,
  ) async {
    try {
      final data = await _remote.retryPayment(request.offerId, {
        'method': CheckoutApiConfig.methodCard,
        'ip_address': await _remote.publicIp() ?? '',
        'points_used': request.pointsUsed,
        'points_value': request.pointsValue,
        'voucher_code': request.voucherCode,
      });
      // Tổng 0$: backend đánh dấu paid ngay, không qua Stripe.
      if (data['payment_status'] == 'paid') {
        return const Right(OfferPaymentResult.paid);
      }
      final secret = data['client_secret']?.toString();
      final card = request.paymentMethodId;
      // Chưa paid mà không có client_secret / thẻ → chưa trừ tiền: báo lỗi, không "đang xử lý".
      if (secret == null || secret.isEmpty || card == null) {
        return const Right(OfferPaymentResult.failed);
      }
      final stripe = await _stripe.confirmWithCard(
        clientSecret: secret,
        paymentMethodId: card,
      );
      switch (stripe) {
        case StripeResult.cancelled:
          return const Right(OfferPaymentResult.cancelled);
        case StripeResult.failed:
          return const Right(OfferPaymentResult.failed);
        case StripeResult.success || StripeResult.processing:
          return Right(await _waitUntilPaid(request.offerId));
      }
    } catch (e) {
      return Left(_toFailure(e, 'Payment failed'));
    }
  }

  Future<OfferPaymentResult> _waitUntilPaid(int offerId) async {
    for (var i = 0; i < pollAttempts; i++) {
      try {
        final offer = await _remote.getOffer(offerId);
        if (offer['payment_status'] == 'paid') return OfferPaymentResult.paid;
      } catch (_) {}
      await Future<void>.delayed(pollInterval);
    }
    return OfferPaymentResult.pending;
  }
}
