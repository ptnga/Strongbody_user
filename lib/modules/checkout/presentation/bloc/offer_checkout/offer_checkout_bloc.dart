import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';
import 'package:strongbody_buyer/modules/account/domain/usecases/account_use_cases.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/my_request_entity.dart';

import '../../../domain/entities/checkout_entities.dart';
import '../../../domain/usecases/checkout_use_cases.dart';

part 'offer_checkout_event.dart';
part 'offer_checkout_state.dart';

/// "Accept & Pay" — luồng web `/checkout/offer`: thẻ đã lưu (chọn thẻ đầu), Lion Points,
/// `retry-payment` → Stripe → chờ offer chuyển `paid`.
class OfferCheckoutBloc
    extends BlocWithApi<OfferCheckoutEvent, OfferCheckoutState> {
  final RequestOfferEntity offer;
  final GetPaymentCardsUseCase _getCards;
  final AddPaymentCardUseCase _addCard;
  final PayOfferUseCase _payOffer;
  final GetLionPointsUseCase _getLionPoints;

  OfferCheckoutBloc({
    required this.offer,
    required GetPaymentCardsUseCase getCards,
    required AddPaymentCardUseCase addCard,
    required PayOfferUseCase payOffer,
    required GetLionPointsUseCase getLionPoints,
  }) : _getCards = getCards,
       _addCard = addCard,
       _payOffer = payOffer,
       _getLionPoints = getLionPoints,
       super(const OfferCheckoutState()) {
    on<OfferCheckoutStarted>(_onStarted);
    on<OfferCheckoutCardSelected>(
      (event, emit) => emit(state.copyWith(selectedCardId: event.cardId)),
    );
    on<OfferCheckoutPointsToggled>(
      (event, emit) => emit(state.copyWith(usePoints: event.usePoints)),
    );
    on<OfferCheckoutAddCardRequested>(_onAddCard);
    on<OfferCheckoutPayRequested>(_onPay);
  }

  OfferCheckoutQuote get quote => OfferCheckoutQuote.of(offer, state);

  Future<void> _onStarted(
    OfferCheckoutStarted event,
    Emitter<OfferCheckoutState> emit,
  ) async {
    await Future.wait([
      callApi(
        useCase: _getCards,
        param: const NoParams(),
        onSuccess: (cards) async => emit(
          state.copyWith(cards: cards, selectedCardId: cards.firstOrNull?.id),
        ),
        onFailure: (_) {},
      ),
      callApi(
        useCase: _getLionPoints,
        param: const NoParams(),
        onSuccess: (result) async {
          final usable = OfferCheckoutQuote.usablePoints(
            wallet: result.wallet.points,
            valueOfPoint: result.pointValue,
            price: offer.price ?? 0,
          );
          emit(
            state.copyWith(
              walletPoints: result.wallet.points,
              pointValue: result.pointValue,
              // Mockup: điểm áp sẵn khi dùng được.
              usePoints: usable > 0,
            ),
          );
        },
        onFailure: (_) {},
      ),
    ]);
    emit(state.copyWith(status: OfferCheckoutStatus.ready));
  }

  Future<void> _onAddCard(
    OfferCheckoutAddCardRequested event,
    Emitter<OfferCheckoutState> emit,
  ) async {
    if (state.addingCard) return;
    emit(state.copyWith(addingCard: true));
    final known = state.cards.map((c) => c.id).toSet();
    await callApi(
      useCase: _addCard,
      param: const NoParams(),
      onSuccess: (cards) async {
        if (cards == null) {
          emit(state.copyWith(addingCard: false));
          return;
        }
        // Thẻ vừa thêm được chọn luôn (như web `refetchAndSelectNew`).
        final added = cards.where((c) => !known.contains(c.id)).firstOrNull;
        emit(
          state.copyWith(
            cards: cards,
            selectedCardId: added?.id ?? state.selectedCardId,
            addingCard: false,
          ),
        );
      },
      onFailure: (_) => emit(
        state.copyWith(
          addingCard: false,
          notice: OfferCheckoutNotice.addCardFailed,
        ),
      ),
    );
  }

  Future<void> _onPay(
    OfferCheckoutPayRequested event,
    Emitter<OfferCheckoutState> emit,
  ) async {
    final q = quote;
    if (state.status != OfferCheckoutStatus.ready) return;
    if (!q.isFree && state.selectedCardId == null) return;
    emit(state.copyWith(status: OfferCheckoutStatus.paying));
    await callApi(
      useCase: _payOffer,
      param: OfferPaymentRequest(
        offerId: offer.id,
        pointsUsed: q.points,
        pointsValue: q.pointsDiscount,
        voucherCode: offer.voucherCode,
        paymentMethodId: q.isFree ? null : state.selectedCardId,
      ),
      onSuccess: (result) async => emit(switch (result) {
        OfferPaymentResult.paid => state.copyWith(
          status: OfferCheckoutStatus.paid,
        ),
        OfferPaymentResult.pending => state.copyWith(
          status: OfferCheckoutStatus.pending,
        ),
        OfferPaymentResult.cancelled => state.copyWith(
          status: OfferCheckoutStatus.ready,
        ),
        OfferPaymentResult.failed => state.copyWith(
          status: OfferCheckoutStatus.ready,
          notice: OfferCheckoutNotice.payFailed,
        ),
      }),
      onFailure: (_) => emit(
        state.copyWith(
          status: OfferCheckoutStatus.ready,
          notice: OfferCheckoutNotice.payFailed,
        ),
      ),
    );
  }
}
