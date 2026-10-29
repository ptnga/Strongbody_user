import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/services/stripe_payment_service.dart';
import 'package:strongbody_buyer/modules/account/domain/entities/account_entities.dart';
import 'package:strongbody_buyer/modules/account/domain/repositories/account_repository.dart';
import 'package:strongbody_buyer/modules/account/domain/usecases/account_use_cases.dart';
import 'package:strongbody_buyer/modules/checkout/data/datasources/remote/checkout_remote_datasource.dart';
import 'package:strongbody_buyer/modules/checkout/data/repositories/checkout_repository_impl.dart';
import 'package:strongbody_buyer/modules/checkout/domain/entities/checkout_entities.dart';
import 'package:strongbody_buyer/modules/checkout/domain/usecases/checkout_use_cases.dart';
import 'package:strongbody_buyer/modules/checkout/presentation/bloc/offer_checkout/offer_checkout_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/my_request_entity.dart';

class _Remote implements CheckoutRemoteDataSource {
  Map<String, dynamic> retry = {'client_secret': 'pi_secret', 'offer_id': 9};
  String offerStatus = 'paid';
  Map<String, dynamic>? sentBody;

  @override
  Future<List<Map<String, dynamic>>> getPaymentMethods() async => [
    {
      'id': 'pm_1',
      'brand': 'visa',
      'last4': '4242',
      'exp_month': 12,
      'exp_year': 2030,
    },
  ];

  @override
  Future<String> createSetupIntent() async => 'seti_secret';

  @override
  Future<Map<String, dynamic>> retryPayment(
    int offerId,
    Map<String, dynamic> body,
  ) async {
    sentBody = body;
    return retry;
  }

  @override
  Future<Map<String, dynamic>> getOffer(int offerId) async => {
    'payment_status': offerStatus,
  };

  @override
  Future<String?> publicIp() async => '1.2.3.4';
}

class _Stripe implements StripePaymentService {
  StripeResult result = StripeResult.success;
  String? confirmedWith;

  @override
  Future<StripeResult> confirmWithCard({
    required String clientSecret,
    required String paymentMethodId,
  }) async {
    confirmedWith = paymentMethodId;
    return result;
  }

  @override
  Future<StripeResult> addCard(String setupIntentClientSecret) async =>
      StripeResult.success;
}

class _AccountRepo implements AccountRepository {
  @override
  Future<Either<Failure, LionWallet>> getWallet() async =>
      const Right(LionWallet(id: 1, points: 1250));

  @override
  Future<Either<Failure, double?>> getPointValue() async => const Right(0.01);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _offer = RequestOfferEntity(
  id: 9,
  status: 'pending',
  sellerName: 'Minh Pham',
  sellerId: 42,
  price: 70,
);

CheckoutRepositoryImpl _repo(_Remote remote, _Stripe stripe) =>
    CheckoutRepositoryImpl(
      remote,
      stripe,
      pollInterval: Duration.zero,
      pollAttempts: 2,
    );

void main() {
  group('OfferCheckoutQuote', () {
    test('points capped at 20% of price (web useLionPoints)', () {
      // 20% của $70 = $14 → tối đa 1400 điểm × $0.01; ví có 1250 → dùng 1250.
      expect(
        OfferCheckoutQuote.usablePoints(
          wallet: 1250,
          valueOfPoint: 0.01,
          price: 70,
        ),
        1250,
      );
      expect(
        OfferCheckoutQuote.usablePoints(
          wallet: 5000,
          valueOfPoint: 0.01,
          price: 70,
        ),
        1400,
      );
      final quote = OfferCheckoutQuote.of(
        _offer,
        const OfferCheckoutState(
          walletPoints: 500,
          pointValue: 0.01,
          usePoints: true,
        ),
      );
      expect(quote.pointsDiscount, closeTo(5, 0.0001));
      expect(quote.total, closeTo(65, 0.0001));
    });

    test(
      'points already applied on the offer are kept, voucher subtracted',
      () {
        const applied = RequestOfferEntity(
          id: 1,
          status: 'pending',
          sellerName: 'A',
          price: 50,
          pointsUsed: 300,
          pointsValue: 3,
          voucherValue: 60,
          voucherCode: 'SAVE',
        );
        final quote = OfferCheckoutQuote.of(
          applied,
          const OfferCheckoutState(walletPoints: 9999, pointValue: 0.01),
        );
        expect(quote.canChoosePoints, isFalse);
        expect(quote.points, 300);
        expect(quote.total, 0);
        expect(quote.isFree, isTrue);
      },
    );
  });

  group('CheckoutRepositoryImpl.payOffer', () {
    test('card payment → Stripe → offer paid', () async {
      final remote = _Remote();
      final stripe = _Stripe();
      final result = await _repo(remote, stripe).payOffer(
        const OfferPaymentRequest(
          offerId: 9,
          pointsUsed: 500,
          pointsValue: 5,
          paymentMethodId: 'pm_1',
        ),
      );
      expect(
        result.getOrElse((_) => OfferPaymentResult.failed),
        OfferPaymentResult.paid,
      );
      expect(stripe.confirmedWith, 'pm_1');
      expect(remote.sentBody, {
        'method': 2,
        'ip_address': '1.2.3.4',
        'points_used': 500,
        'points_value': 5.0,
        'voucher_code': null,
      });
    });

    test('free order paid by backend; cancelled; pending; failed', () async {
      final remote = _Remote()..retry = {'payment_status': 'paid'};
      final stripe = _Stripe();
      expect(
        (await _repo(remote, stripe).payOffer(
          const OfferPaymentRequest(offerId: 9),
        )).getOrElse((_) => OfferPaymentResult.failed),
        OfferPaymentResult.paid,
      );
      expect(stripe.confirmedWith, isNull);

      remote.retry = {'client_secret': 'pi'};
      stripe.result = StripeResult.cancelled;
      expect(
        (await _repo(remote, stripe).payOffer(
          const OfferPaymentRequest(offerId: 9, paymentMethodId: 'pm_1'),
        )).getOrElse((_) => OfferPaymentResult.failed),
        OfferPaymentResult.cancelled,
      );

      stripe.result = StripeResult.success;
      remote.offerStatus = 'unpaid';
      expect(
        (await _repo(remote, stripe).payOffer(
          const OfferPaymentRequest(offerId: 9, paymentMethodId: 'pm_1'),
        )).getOrElse((_) => OfferPaymentResult.failed),
        OfferPaymentResult.pending,
      );

      stripe.result = StripeResult.failed;
      expect(
        (await _repo(remote, stripe).payOffer(
          const OfferPaymentRequest(offerId: 9, paymentMethodId: 'pm_1'),
        )).getOrElse((_) => OfferPaymentResult.paid),
        OfferPaymentResult.failed,
      );
    });
  });

  test(
    'OfferCheckoutBloc: first card + points preselected, pay → paid',
    () async {
      final remote = _Remote();
      final repo = _repo(remote, _Stripe());
      final bloc = OfferCheckoutBloc(
        offer: _offer,
        getCards: GetPaymentCardsUseCase(repo),
        addCard: AddPaymentCardUseCase(repo),
        payOffer: PayOfferUseCase(repo),
        getLionPoints: GetLionPointsUseCase(_AccountRepo()),
      )..add(const OfferCheckoutStarted());
      final ready = await bloc.stream.firstWhere(
        (s) => s.status == OfferCheckoutStatus.ready,
      );
      expect(ready.selectedCardId, 'pm_1');
      expect(ready.usePoints, isTrue);
      expect(bloc.quote.points, 1250);
      expect(bloc.quote.total, closeTo(57.5, 0.0001));

      bloc.add(const OfferCheckoutPayRequested());
      await bloc.stream.firstWhere((s) => s.status == OfferCheckoutStatus.paid);
      expect(remote.sentBody!['points_used'], 1250);
      await bloc.close();
    },
  );
}
