import 'package:equatable/equatable.dart';

import 'request_form_values.dart';

/// Request của buyer trong "My requests" (`GET /user/requests`).
class MyRequestEntity extends Equatable {
  final int id;

  /// pending | active | closed | expired | canceled
  final String status;
  final int offersCount;

  /// BE `responders_count` — số provider đã phản hồi (Multime "N responded").
  final int respondersCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool hasVoice;

  /// Mô tả, ngân sách, cách nhận, ngày/lịch — đọc như web `requestToFormValues`.
  final RequestFormValues details;

  const MyRequestEntity({
    required this.id,
    required this.status,
    required this.details,
    this.offersCount = 0,
    this.respondersCount = 0,
    this.createdAt,
    this.updatedAt,
    this.hasVoice = false,
  });

  String get description => details.description;

  /// Tab "Closed": đã đóng / hết hạn / bị huỷ (Multime `isInactive`).
  bool get isClosed =>
      const {'closed', 'expired', 'canceled', 'cancelled'}.contains(status);

  @override
  List<Object?> get props => [
    id,
    status,
    offersCount,
    respondersCount,
    createdAt,
    updatedAt,
    hasVoice,
    details,
  ];
}

class MyRequestPage extends Equatable {
  final List<MyRequestEntity> items;
  final int totalPage;

  const MyRequestPage({required this.items, required this.totalPage});

  @override
  List<Object?> get props => [items, totalPage];
}

/// Offer provider gửi cho một request (`GET /buyer/offer/sent-offers-by-my-requests?request_id=`).
class RequestOfferEntity extends Equatable {
  final int id;

  /// pending (chờ buyer trả tiền) | accepted | delivered | completed | cancelled
  final String status;

  /// User id của provider — mở chat (`Reply`).
  final int? sellerId;
  final int? requestId;

  /// Request kèm theo offer (mở trang Offers từ chat khi chưa có request trong tay).
  final MyRequestEntity? request;
  final String sellerName;
  final String? sellerAvatar;
  final bool sellerVerified;
  final String title;

  /// Lời nhắn của provider (web hiện ở chi tiết offer).
  final String description;
  final double? price;
  final String? currency;

  /// `Service.rating` — 0/null = chưa có đánh giá.
  final double? rating;
  final int? reviewCount;

  /// Tên danh mục của service ("Physiotherapist").
  final String? profession;

  /// `Service.address` (địa chỉ của provider).
  final String? address;

  /// `Service.delivery_lead_time_day` — dùng cho sắp xếp "Soonest".
  final int? leadTimeDays;

  /// File audio trong `files` của offer.
  final String? voiceUrl;
  final DateTime? createdAt;
  final DateTime? paidAt;

  /// unpaid | paid | …
  final String paymentStatus;

  /// Điểm / voucher đã áp ở lần checkout trước (`points_used` > 0 → không chọn lại điểm).
  final int pointsUsed;
  final double pointsValue;
  final double voucherValue;
  final String? voucherCode;

  const RequestOfferEntity({
    required this.id,
    required this.status,
    required this.sellerName,
    this.sellerId,
    this.requestId,
    this.request,
    this.sellerAvatar,
    this.sellerVerified = false,
    this.title = '',
    this.description = '',
    this.price,
    this.currency,
    this.rating,
    this.reviewCount,
    this.profession,
    this.address,
    this.leadTimeDays,
    this.voiceUrl,
    this.createdAt,
    this.paidAt,
    this.paymentStatus = '',
    this.pointsUsed = 0,
    this.pointsValue = 0,
    this.voucherValue = 0,
    this.voucherCode,
  });

  bool get isPaid => paymentStatus == 'paid';

  /// Offer mới, buyer chưa nhận (web/Multime đếm "new offers" theo `status=pending`).
  bool get isNew => status == 'pending';

  /// Buyer đã trả tiền → đã đặt provider này.
  bool get isBooked =>
      const {'accepted', 'delivered', 'completed'}.contains(status);

  bool get isCancelled => status == 'cancelled' || status == 'canceled';

  @override
  List<Object?> get props => [
    id,
    status,
    sellerId,
    requestId,
    request,
    sellerName,
    sellerAvatar,
    sellerVerified,
    title,
    description,
    price,
    currency,
    rating,
    reviewCount,
    profession,
    address,
    leadTimeDays,
    voiceUrl,
    createdAt,
    paidAt,
    paymentStatus,
    pointsUsed,
    pointsValue,
    voucherValue,
    voucherCode,
  ];
}
