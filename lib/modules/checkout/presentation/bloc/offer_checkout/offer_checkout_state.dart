part of 'offer_checkout_bloc.dart';

/// [unavailable] = offer đã trả / đã huỷ (web chặn checkout, xem [OfferCheckoutBlocked]).
enum OfferCheckoutStatus { loading, ready, paying, paid, pending, unavailable }

enum OfferCheckoutNotice { payFailed, addCardFailed }

/// Lý do chặn checkout (web `offer_already_paid` / `offer_cancelled`).
enum OfferCheckoutBlocked { alreadyPaid, cancelled }

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

  /// Offer đọc lại lúc mở (điểm / voucher đã áp mới nhất); null = dùng offer truyền vào.
  final CheckoutOfferSnapshot? snapshot;
  final OfferCheckoutBlocked? blocked;

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
    this.snapshot,
    this.blocked,
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
    CheckoutOfferSnapshot? snapshot,
    OfferCheckoutBlocked? blocked,
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
      snapshot: snapshot ?? this.snapshot,
      blocked: blocked ?? this.blocked,
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
    snapshot,
    blocked,
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
    // Offer đọc lại lúc mở checkout (web `getOfferById`) thắng offer truyền vào.
    final fresh = s.snapshot;
    final netPrice = fresh?.price ?? offer.price ?? 0;
    final pointsUsed = fresh?.pointsUsed ?? offer.pointsUsed;
    final pointsValue = fresh?.pointsValue ?? offer.pointsValue;
    final voucherValue = fresh?.voucherValue ?? offer.voucherValue;
    // BE (`retry-payment`) lưu `price` = giá gốc + phí − (điểm + voucher) đã áp → giá gốc
    // = price + phần đã giảm; tổng phải trả khi đã áp = đúng `price` BE sẽ thu.
    final price = netPrice + pointsValue + voucherValue;
    final canChoose = pointsUsed == 0 && pointsValue == 0;
    final usable = usablePoints(
      wallet: s.walletPoints,
      valueOfPoint: s.pointValue,
      price: price,
    );
    final points = canChoose ? (s.usePoints ? usable : 0) : pointsUsed;
    return OfferCheckoutQuote(
      price: price,
      canChoosePoints: canChoose && usable > 0,
      points: points,
      pointsDiscount: canChoose ? points * (s.pointValue ?? 0) : pointsValue,
      voucherDiscount: voucherValue,
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
