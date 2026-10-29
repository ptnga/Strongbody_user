import '../domain/entities/my_request_entity.dart';

/// Dữ liệu cho trang "Offers" (`extra`). Mở từ My requests: có sẵn [request] (+ offer đã tải).
/// Mở từ "Details" trong chat: chỉ có [requestId] + [highlightOfferId] — request lấy từ offer.
class RequestOffersPageArgs {
  final int requestId;
  final MyRequestEntity? request;

  /// Offer đã tải ở My requests — hiện ngay trong lúc tải lại.
  final List<RequestOfferEntity>? offers;

  /// Offer được in đậm viền + cuộn tới (từ chat); null = danh sách thường.
  final int? highlightOfferId;

  const RequestOffersPageArgs({
    required this.requestId,
    this.request,
    this.offers,
    this.highlightOfferId,
  });

  factory RequestOffersPageArgs.fromRequest(
    MyRequestEntity request, {
    List<RequestOfferEntity>? offers,
  }) => RequestOffersPageArgs(
    requestId: request.id,
    request: request,
    offers: offers,
  );
}
