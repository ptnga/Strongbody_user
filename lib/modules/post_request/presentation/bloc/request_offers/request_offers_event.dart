part of 'request_offers_bloc.dart';

sealed class RequestOffersEvent extends Equatable {
  const RequestOffersEvent();

  @override
  List<Object?> get props => [];
}

/// Tải offer của request (cũng dùng cho kéo để làm mới).
final class RequestOffersStarted extends RequestOffersEvent {
  final int requestId;
  final List<RequestOfferEntity>? initialOffers;

  const RequestOffersStarted(this.requestId, {this.initialOffers});

  @override
  List<Object?> get props => [requestId, initialOffers];
}

final class RequestOffersSortChanged extends RequestOffersEvent {
  final OfferSort sort;

  const RequestOffersSortChanged(this.sort);

  @override
  List<Object?> get props => [sort];
}
