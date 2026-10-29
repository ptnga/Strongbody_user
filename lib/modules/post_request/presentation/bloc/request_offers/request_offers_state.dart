part of 'request_offers_bloc.dart';

enum RequestOffersStatus { loading, success, failure }

/// Best match: đánh giá cao → nhiều review → rẻ hơn. Soonest: thời gian giao
/// (`delivery_lead_time_day`) ngắn nhất, rồi offer đến sớm nhất.
enum OfferSort { bestMatch, lowestPrice, soonest }

class RequestOffersState extends Equatable {
  final RequestOffersStatus status;
  final List<RequestOfferEntity> offers;
  final OfferSort sort;

  const RequestOffersState({
    this.status = RequestOffersStatus.loading,
    this.offers = const [],
    this.sort = OfferSort.bestMatch,
  });

  /// Request lấy từ offer (`Request` lồng) — khi mở trang mà chưa có request trong tay.
  MyRequestEntity? get request =>
      offers.map((o) => o.request).nonNulls.firstOrNull;

  /// Offer còn hiệu lực trước, offer đã huỷ xuống cuối.
  List<RequestOfferEntity> get sortedOffers {
    int byPrice(RequestOfferEntity a, RequestOfferEntity b) =>
        (a.price ?? double.infinity).compareTo(b.price ?? double.infinity);
    int byCreated(RequestOfferEntity a, RequestOfferEntity b) =>
        (a.createdAt ?? DateTime(9999)).compareTo(
          b.createdAt ?? DateTime(9999),
        );
    final compare = switch (sort) {
      OfferSort.bestMatch => (RequestOfferEntity a, RequestOfferEntity b) {
        final rating = (b.rating ?? 0).compareTo(a.rating ?? 0);
        if (rating != 0) return rating;
        final reviews = (b.reviewCount ?? 0).compareTo(a.reviewCount ?? 0);
        return reviews != 0 ? reviews : byPrice(a, b);
      },
      OfferSort.lowestPrice => byPrice,
      OfferSort.soonest => (RequestOfferEntity a, RequestOfferEntity b) {
        final lead = (a.leadTimeDays ?? 1 << 20).compareTo(
          b.leadTimeDays ?? 1 << 20,
        );
        return lead != 0 ? lead : byCreated(a, b);
      },
    };
    return [...offers]..sort((a, b) {
      if (a.isCancelled != b.isCancelled) return a.isCancelled ? 1 : -1;
      return compare(a, b);
    });
  }

  RequestOffersState copyWith({
    RequestOffersStatus? status,
    List<RequestOfferEntity>? offers,
    OfferSort? sort,
  }) {
    return RequestOffersState(
      status: status ?? this.status,
      offers: offers ?? this.offers,
      sort: sort ?? this.sort,
    );
  }

  @override
  List<Object?> get props => [status, offers, sort];
}
