part of 'offer_checkout_bloc.dart';

enum OfferCheckoutStatus { loading, ready, paying, paid, pending }

enum OfferCheckoutNotice { payFailed, addCardFailed }

class OfferCheckoutState extends Equatable {
  final OfferCheckoutStatus status;
  final List<PaymentCard> cards;
  final String? selectedCardId;
  final bool addingCard;

  /// Ví Lion Points (điểm) + USD / điểm.
  final int walletPoints;
  final double? pointValue;
  final bool usePoints;
  final OfferCheckoutNotice? notice;
  final int noticeId;

  const OfferCheckoutState({
    this.status = OfferCheckoutStatus.loading,
    this.cards = const [],
    this.selectedCardId,
    this.addingCard = false,
    this.walletPoints = 0,
    this.pointValue,
    this.usePoints = false,
    this.notice,
    this.noticeId = 0,
  });

  OfferCheckoutState copyWith({
    OfferCheckoutStatus? status,
    List<PaymentCard>? cards,
    String? selectedCardId,
    bool? addingCard,
    int? walletPoints,
    double? pointValue,
    bool? usePoints,
    OfferCheckoutNotice? notice,
  }) {
    return OfferCheckoutState(
      status: status ?? this.status,
      cards: cards ?? this.cards,
      selectedCardId: selectedCardId ?? this.selectedCardId,
      addingCard: addingCard ?? this.addingCard,
      walletPoints: walletPoints ?? this.walletPoints,
      pointValue: pointValue ?? this.pointValue,
      usePoints: usePoints ?? this.usePoints,
      notice: notice ?? this.notice,
      noticeId: notice != null ? noticeId + 1 : noticeId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    cards,
    selectedCardId,
    addingCard,
    walletPoints,
    pointValue,
    usePoints,
    notice,
    noticeId,
  ];
}

/// Tiền của một lần checkout — quy tắc web `useLionPoints` + `summary.tsx`.
class OfferCheckoutQuote extends Equatable {
  final double price;

  /// Được chọn dùng điểm (offer chưa áp điểm ở lần trước).
  final bool canChoosePoints;
  final int points;
  final double pointsDiscount;
  final double voucherDiscount;

  const OfferCheckoutQuote({
    required this.price,
    required this.canChoosePoints,
    required this.points,
    required this.pointsDiscount,
    required this.voucherDiscount,
  });

  /// Tối đa 20% giá trị offer được trả bằng điểm.
  static int usablePoints({
    required int wallet,
    required double? valueOfPoint,
    required double price,
  }) {
    final value = valueOfPoint ?? 0;
    if (value <= 0 || wallet <= 0 || price <= 0) return 0;
    final maxByPrice = (price * 0.2 / value).ceil();
    return wallet < maxByPrice ? wallet : maxByPrice;
  }

  factory OfferCheckoutQuote.of(
    RequestOfferEntity offer,
    OfferCheckoutState s,
  ) {
    final price = offer.price ?? 0;
    final canChoose = offer.pointsUsed == 0 && offer.pointsValue == 0;
    final usable = usablePoints(
      wallet: s.walletPoints,
      valueOfPoint: s.pointValue,
      price: price,
    );
    final points = canChoose ? (s.usePoints ? usable : 0) : offer.pointsUsed;
    return OfferCheckoutQuote(
      price: price,
      canChoosePoints: canChoose && usable > 0,
      points: points,
      pointsDiscount: canChoose
          ? points * (s.pointValue ?? 0)
          : offer.pointsValue,
      voucherDiscount: offer.voucherValue,
    );
  }

  double get total {
    final value = price - pointsDiscount - voucherDiscount;
    return value < 0 ? 0 : value;
  }

  bool get isFree => total <= 0;

  @override
  List<Object?> get props => [
    price,
    canChoosePoints,
    points,
    pointsDiscount,
    voucherDiscount,
  ];
}
