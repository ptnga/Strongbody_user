import 'dart:async';

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
  int retryCalls = 0;
  Completer<void>? retryGate;
  bool hasCards = true;

  @override
  Future<List<Map<String, dynamic>>> getPaymentMethods() async => [
    if (hasCards)
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
    retryCalls++;
    sentBody = body;
    await retryGate?.future;
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
  StripeResult addResult = StripeResult.success;
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
      addResult;
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
      'discounts already applied: price is net (BE retry-payment) → pay exactly price',
      () {
        // BE: price = gốc 113 − (điểm 3 + voucher 60) = 50 → Stripe thu $50.
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
        expect(quote.price, closeTo(113, 0.0001));
        expect(quote.total, closeTo(50, 0.0001));
        expect(quote.isFree, isFalse);

        // Đã áp đủ để miễn phí: price 0 → đơn 0$.
        const free = RequestOfferEntity(
          id: 2,
          status: 'pending',
          sellerName: 'A',
          price: 0,
          voucherValue: 70,
          voucherCode: 'FREE',
        );
        expect(
          OfferCheckoutQuote.of(free, const OfferCheckoutState()).isFree,
          isTrue,
        );
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

  group('OfferCheckoutBloc guards', () {
    OfferCheckoutBloc bloc0(_Remote remote, _Stripe stripe, {offer = _offer}) =>
        OfferCheckoutBloc(
          offer: offer,
          getCards: GetPaymentCardsUseCase(_repo(remote, stripe)),
          addCard: AddPaymentCardUseCase(_repo(remote, stripe)),
          payOffer: PayOfferUseCase(_repo(remote, stripe)),
          getLionPoints: GetLionPointsUseCase(_AccountRepo()),
        )..add(const OfferCheckoutStarted());

    test('Pay tapped twice while paying → charged once', () async {
      final remote = _Remote()..retryGate = Completer<void>();
      final bloc = bloc0(remote, _Stripe());
      await bloc.stream.firstWhere(
        (s) => s.status == OfferCheckoutStatus.ready,
      );
      bloc
        ..add(const OfferCheckoutPayRequested())
        ..add(const OfferCheckoutPayRequested());
      await bloc.stream.firstWhere(
        (s) => s.status == OfferCheckoutStatus.paying,
      );
      await Future<void>.delayed(Duration.zero);
      remote.retryGate!.complete();
      await bloc.stream.firstWhere((s) => s.status == OfferCheckoutStatus.paid);
      bloc.add(const OfferCheckoutPayRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(remote.retryCalls, 1);
      await bloc.close();
    });

    test('no saved card on a paid order → Pay does nothing', () async {
      final remote = _Remote()..hasCards = false;
      final bloc = bloc0(remote, _Stripe());
      final ready = await bloc.stream.firstWhere(
        (s) => s.status == OfferCheckoutStatus.ready,
      );
      expect(ready.selectedCardId, isNull);
      expect(bloc.quote.isFree, isFalse);
      bloc.add(const OfferCheckoutPayRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(remote.retryCalls, 0);
      expect(bloc.state.status, OfferCheckoutStatus.ready);
      await bloc.close();
    });

    test('add card: cancelled is silent, failure shows notice', () async {
      final stripe = _Stripe()..addResult = StripeResult.cancelled;
      final bloc = bloc0(_Remote(), stripe);
      await bloc.stream.firstWhere(
        (s) => s.status == OfferCheckoutStatus.ready,
      );
      bloc.add(const OfferCheckoutAddCardRequested());
      await bloc.stream.firstWhere((s) => !s.addingCard);
      expect(bloc.state.notice, isNull);

      stripe.addResult = StripeResult.failed;
      bloc.add(const OfferCheckoutAddCardRequested());
      final s = await bloc.stream.firstWhere(
        (s) => !s.addingCard && s.notice != null,
      );
      expect(s.notice, OfferCheckoutNotice.addCardFailed);
      await bloc.close();
    });

    test('points toggled off → full price, no points sent', () async {
      final remote = _Remote();
      final bloc = bloc0(remote, _Stripe());
      await bloc.stream.firstWhere(
        (s) => s.status == OfferCheckoutStatus.ready,
      );
      bloc.add(const OfferCheckoutPointsToggled(false));
      await bloc.stream.firstWhere((s) => !s.usePoints);
      expect(bloc.quote.total, closeTo(70, 0.0001));
      bloc.add(const OfferCheckoutPayRequested());
      await bloc.stream.firstWhere((s) => s.status == OfferCheckoutStatus.paid);
      expect(remote.sentBody!['points_used'], 0);
      await bloc.close();
    });
  });
}
