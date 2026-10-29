part of 'offer_checkout_bloc.dart';

sealed class OfferCheckoutEvent extends Equatable {
  const OfferCheckoutEvent();

  @override
  List<Object?> get props => [];
}

/// Tải thẻ đã lưu + Lion Points.
final class OfferCheckoutStarted extends OfferCheckoutEvent {
  const OfferCheckoutStarted();
}

final class OfferCheckoutCardSelected extends OfferCheckoutEvent {
  final String cardId;

  const OfferCheckoutCardSelected(this.cardId);

  @override
  List<Object?> get props => [cardId];
}

final class OfferCheckoutPointsToggled extends OfferCheckoutEvent {
  final bool usePoints;

  const OfferCheckoutPointsToggled(this.usePoints);

  @override
  List<Object?> get props => [usePoints];
}

final class OfferCheckoutAddCardRequested extends OfferCheckoutEvent {
  const OfferCheckoutAddCardRequested();
}

final class OfferCheckoutPayRequested extends OfferCheckoutEvent {
  const OfferCheckoutPayRequested();
}
