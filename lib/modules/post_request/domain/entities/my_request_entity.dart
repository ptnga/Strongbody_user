import 'package:equatable/equatable.dart';

import 'package:strongbody_buyer/modules/social_market/domain/entities/market_listing_entities.dart';

import 'request_form_values.dart';

/// Request của buyer trong "My requests" (`GET /user/requests`).
class MyRequestEntity extends Equatable {
  final int id;

  /// Web: pending | pending_approval (đang duyệt) | active (đang mở) | closed |
  /// cancelled | rejected | spam (bị từ chối).
  final String status;
  final int offersCount;

  /// BE `responders_count` — số provider đã phản hồi (Multime "N responded").
  final int respondersCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool hasVoice;

  /// Mô tả, ngân sách, cách nhận, ngày/lịch — đọc như web `requestToFormValues`.
  final RequestFormValues details;

  /// Request gửi riêng một provider (tab "Private requests" của web).
  final bool isPrivate;

  /// Request sinh từ inquiry: provider nhận trả lời trong chat (không gửi offer).
  final RequestInquiryInfo? inquiry;

  /// Kết quả AI chấm request (`ai_refine`); null = chưa chấm.
  final RequestAiRefine? aiRefine;

  /// Số chuyên gia request đã được gửi thẳng tới (BE auto-match theo dịch vụ AI gán,
  /// `matched_providers`) — web "Sent to N matched experts".
  final int matchedProviders;

  const MyRequestEntity({
    required this.id,
    required this.status,
    required this.details,
    this.offersCount = 0,
    this.respondersCount = 0,
    this.createdAt,
    this.updatedAt,
    this.hasVoice = false,
    this.isPrivate = false,
    this.inquiry,
    this.aiRefine,
    this.matchedProviders = 0,
  });

  String get description => details.description;

  /// Bị từ chối nhưng người đăng đã sửa & gửi lại, AI đang chấm lại (`ai_refine.rescoring`)
  /// → web hiển thị "In review" chứ không còn "Not approved".
  bool get isRescoring =>
      (status == 'rejected' || isInReviewStatus) &&
      (aiRefine?.rescoring ?? false);

  bool get isInReviewStatus =>
      status == 'pending' || status == 'pending_approval';

  /// Đang duyệt (web badge "In review").
  bool get isInReview => isInReviewStatus || isRescoring;

  /// Bị từ chối (web: cancelled / rejected / spam → "Not approved").
  bool get isRejected =>
      !isRescoring &&
      const {'cancelled', 'canceled', 'rejected', 'spam'}.contains(status);

  /// Web `AIReview`: chờ duyệt (`pending_approval`) / bị từ chối mà AI chấm dưới điểm duyệt
  /// → hiện lý do (gợi ý AI); request khác AI chấm 0 điểm → chỉ hiện gợi ý.
  bool get showsAiReview {
    final refine = aiRefine;
    if (refine == null) return false;
    if (isRescoring) return true;
    if (status == 'pending_approval' || status == 'rejected') {
      return refine.belowApproval;
    }
    return refine.needsSuggestion;
  }

  /// Không còn nhận offer: đã đóng / hết hạn / bị từ chối.
  bool get isClosed => status == 'closed' || status == 'expired' || isRejected;

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
    isPrivate,
    inquiry,
    aiRefine,
    matchedProviders,
  ];
}

/// Kết quả AI chấm request (web `RequestAIRefine`, API `ai_refine`).
class RequestAiRefine extends Equatable {
  /// Điểm AI tối thiểu để request tự được duyệt (BE `RequestAutoApproveMinScore`).
  static const minScore = 5;

  final num score;

  /// Không đọc ra nhu cầu.
  final bool isEmpty;

  /// Gợi ý bằng ngôn ngữ của request / bằng tiếng Anh.
  final String suggestion;
  final String suggestionEn;

  /// AI đang chấm (lại) — vd người đăng vừa sửa; điểm / gợi ý là của lần trước.
  final bool rescoring;

  const RequestAiRefine({
    this.score = 0,
    this.isEmpty = false,
    this.suggestion = '',
    this.suggestionEn = '',
    this.rescoring = false,
  });

  bool get _hasSuggestion => suggestion.isNotEmpty || suggestionEn.isNotEmpty;

  /// Web `belowAIScore`: dưới điểm duyệt (hoặc không đọc ra nhu cầu) và có gợi ý.
  bool get belowApproval => (isEmpty || score < minScore) && _hasSuggestion;

  /// Web `needsAISuggestion`: AI chấm 0 điểm (Empty) và có gợi ý.
  bool get needsSuggestion => (isEmpty || score == 0) && _hasSuggestion;

  /// Trang của chính người đăng chỉ hiện MỘT bản (web `singleLanguage`): trang tiếng Anh →
  /// bản tiếng Anh trước; ngôn ngữ khác → bản ngôn ngữ của request trước.
  String suggestionFor(String locale) {
    final primary = locale == 'en' ? suggestionEn : suggestion;
    return primary.isNotEmpty
        ? primary
        : (suggestionEn.isNotEmpty ? suggestionEn : suggestion);
  }

  @override
  List<Object?> get props => [
    score,
    isEmpty,
    suggestion,
    suggestionEn,
    rescoring,
  ];
}

/// Chuyên gia request đã được gửi thẳng tới (web `MatchedProvider`, chỉ chủ request).
class MatchedProviderEntity extends Equatable {
  final int userId;
  final String name;
  final String? avatar;
  final String? country;
  final String? flag;

  /// Provider đã nhắn lại người mua trong chat.
  final bool replied;

  /// Hồ sơ chuyên gia (card như trang category) — null khi hồ sơ không còn công khai.
  final MarketExpertEntity? expert;

  const MatchedProviderEntity({
    required this.userId,
    this.name = '',
    this.avatar,
    this.country,
    this.flag,
    this.replied = false,
    this.expert,
  });

  @override
  List<Object?> get props => [userId, name, avatar, country, replied, expert];
}

class MatchedProvidersPage extends Equatable {
  final List<MatchedProviderEntity> items;
  final int total;

  const MatchedProvidersPage({this.items = const [], this.total = 0});

  @override
  List<Object?> get props => [items, total];
}

/// Web `RequestInquiryInfo` — item đã hỏi + provider nhận của request riêng.
class RequestInquiryInfo extends Equatable {
  /// User id provider nhận → "Open chat".
  final int? recipientId;
  final String recipientName;
  final String? recipientAvatar;

  /// service | product | offer
  final String targetType;
  final String title;

  const RequestInquiryInfo({
    this.recipientId,
    this.recipientName = '',
    this.recipientAvatar,
    this.targetType = '',
    this.title = '',
  });

  @override
  List<Object?> get props => [
    recipientId,
    recipientName,
    recipientAvatar,
    targetType,
    title,
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
  /// (web `StatusConfig`).
  final String status;

  /// User id của provider — mở chat (`Reply`).
  final int? sellerId;
  final int? requestId;

  /// Request kèm theo offer (mở trang Offers từ chat khi chưa có request trong tay).
  final MyRequestEntity? request;

  /// Tên shop / organization (web `sellerDisplayName`); rỗng = "Unknown Provider".
  final String sellerName;
  final String? sellerAvatar;
  final bool sellerVerified;
  final String title;

  /// Lời nhắn của provider (web hiện ở chi tiết offer).
  final String description;
  final double? price;
  final String? currency;

  /// `Seller.rating` như web (thiếu thì `Service.rating`) — 0/null = chưa có đánh giá.
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

  /// Web chỉ cho "Start order (Accept & Pay)" khi offer còn `pending`.
  bool get canPay => status == 'pending';

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
