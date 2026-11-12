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

  static CheckoutOfferSnapshot snapshot(Map<String, dynamic> json) {
    double d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    final price = json['price'];
    final code = json['voucher_code']?.toString();
    return CheckoutOfferSnapshot(
      status: '${json['status'] ?? ''}',
      paymentStatus: '${json['payment_status'] ?? ''}',
      price: price == null ? null : d(price),
      pointsUsed: d(json['points_used']).toInt(),
      pointsValue: d(json['points_value']),
      voucherValue: d(json['voucher_value']),
      voucherCode: code == null || code.isEmpty || code == 'null' ? null : code,
    );
  }

  @override
  Future<Either<Failure, CheckoutOfferSnapshot>> getOffer(int offerId) async {
    try {
      final data = await _remote.getOffer(offerId);
      if (data.isEmpty) return Left(NotFoundFailure('Offer not found'));
      return Right(snapshot(data));
    } catch (e) {
      return Left(_toFailure(e, 'Cannot load this offer'));
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
      // Web: không có client_secret → chờ xác nhận rồi đọc lại offer; chưa paid = thất bại
      // (app chưa trừ tiền qua Stripe nên không báo "đang xử lý").
      if (secret == null || secret.isEmpty) {
        final result = await _waitUntilPaid(request.offerId);
        return Right(
          result == OfferPaymentResult.paid
              ? OfferPaymentResult.paid
              : OfferPaymentResult.failed,
        );
      }
      if (card == null) return const Right(OfferPaymentResult.failed);
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
