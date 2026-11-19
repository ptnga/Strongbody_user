/// Item của `GET /user/requests` — `{ data: { list, total, total_page } }`.
class MyRequestDto {
  final int? id;
  final String? description;
  final String? status;
  final int? offersCount;
  final int? respondersCount;
  final String? createdAt;
  final String? updatedAt;
  final num? minBudget;
  final num? maxBudget;
  final num? budget;
  final String? currency;
  final String? deliveryType;
  final String? deadline;

  /// JSON `{ mon: [{from, to}] }` — có thể là object hoặc chuỗi JSON.
  final Object? schedule;
  final String? voiceUrl;

  /// `is_private` (BE mới) / `is_privated` (BE cũ) — request gửi riêng 1 provider.
  final bool? isPrivate;

  /// Request sinh từ inquiry (web `RequestInquiryInfo`): provider nhận + item đã hỏi.
  final Map<String, dynamic>? inquiry;

  /// Kết quả AI chấm (`ai_refine`: score, is_empty, suggestion, suggestion_en, rescoring).
  final Map<String, dynamic>? aiRefine;

  /// Số provider request đã được gửi thẳng tới (`matched_providers`, chỉ danh sách của chủ).
  final int? matchedProviders;

  const MyRequestDto({
    this.id,
    this.description,
    this.status,
    this.offersCount,
    this.respondersCount,
    this.createdAt,
    this.updatedAt,
    this.minBudget,
    this.maxBudget,
    this.budget,
    this.currency,
    this.deliveryType,
    this.deadline,
    this.schedule,
    this.voiceUrl,
    this.isPrivate,
    this.inquiry,
    this.aiRefine,
    this.matchedProviders,
  });

  factory MyRequestDto.fromJson(Map<String, dynamic> json) => MyRequestDto(
    id: (json['id'] as num?)?.toInt(),
    description: json['description']?.toString(),
    status: json['status']?.toString(),
    offersCount: ((json['offers_count'] ?? json['total_offers']) as num?)
        ?.toInt(),
    respondersCount: (json['responders_count'] as num?)?.toInt(),
    createdAt: json['created_at']?.toString(),
    updatedAt: json['updated_at']?.toString(),
    minBudget: json['min_budget'] as num?,
    maxBudget: json['max_budget'] as num?,
    budget: json['budget'] as num?,
    currency: json['currency']?.toString(),
    deliveryType: json['delivery_type']?.toString(),
    deadline: json['deadline']?.toString(),
    schedule: json['schedule'],
    voiceUrl: (json['voice_url'] ?? json['audio_url'])?.toString(),
    isPrivate: _bool(json['is_private'] ?? json['is_privated']),
    inquiry: json['inquiry'] is Map
        ? Map<String, dynamic>.from(json['inquiry'] as Map)
        : null,
    aiRefine: json['ai_refine'] is Map
        ? Map<String, dynamic>.from(json['ai_refine'] as Map)
        : null,
    matchedProviders: (json['matched_providers'] is num)
        ? (json['matched_providers'] as num).toInt()
        : int.tryParse('${json['matched_providers'] ?? ''}'),
  );

  static bool? _bool(Object? v) =>
      v is bool ? v : (v == null ? null : '$v'.toLowerCase() == 'true');
}

/// Item của `GET /buyer/offer/sent-offers-by-my-requests` (web `OfferBuyer`).
class RequestOfferDto {
  final int? id;
  final int? sellerId;
  final int? requestId;

  /// `Request` lồng trong offer (cùng shape item `/user/requests`).
  final Map<String, dynamic>? request;
  final String? status;
  final String? title;
  final String? description;
  final num? price;
  final String? currency;

  /// Tên hiển thị của seller (web `sellerDisplayName`): tên organization khi là người
  /// đại diện, không thì tên shop — không dùng họ tên tài khoản.
  final String? sellerDisplayName;
  final String? sellerAvatar;

  /// `Seller.rating` (web hiện ở thẻ offer).
  final num? sellerRating;
  final bool? sellerVerified;
  final num? serviceRating;
  final num? serviceReviewCount;
  final String? serviceCategory;
  final String? serviceAddress;
  final num? leadTimeDays;

  /// File đính kèm đầu tiên có kiểu audio (voice message của provider).
  final String? voiceUrl;
  final String? createdAt;
  final String? paymentDate;
  final String? paymentStatus;

  /// Điểm / voucher đã áp ở lần checkout trước (web không cho chọn lại).
  final num? pointsUsed;
  final num? pointsValue;
  final num? voucherValue;
  final String? voucherCode;

  const RequestOfferDto({
    this.id,
    this.sellerId,
    this.requestId,
    this.request,
    this.status,
    this.title,
    this.description,
    this.price,
    this.currency,
    this.sellerDisplayName,
    this.sellerAvatar,
    this.sellerRating,
    this.sellerVerified,
    this.serviceRating,
    this.serviceReviewCount,
    this.serviceCategory,
    this.serviceAddress,
    this.leadTimeDays,
    this.voiceUrl,
    this.createdAt,
    this.paymentDate,
    this.paymentStatus,
    this.pointsUsed,
    this.pointsValue,
    this.voucherValue,
    this.voucherCode,
  });

  factory RequestOfferDto.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> map(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
    num? number(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');
    final seller = map(json['Seller'] ?? json['seller']);
    final sellerProfile = map(
      seller['seller_profile'] ?? map(seller['user'])['seller_profile'],
    );
    final service = map(json['Service'] ?? json['service']);
    final category = map(
      service['SubCategory'] ?? service['Category'] ?? service['category'],
    );
    final verified =
        seller['seller_verified'] ??
        seller['is_verified'] ??
        seller['verified'];
    String? voice;
    final files = json['files'];
    if (files is List) {
      for (final f in files.whereType<Map>()) {
        final type = '${f['type'] ?? ''}'.toLowerCase();
        final url = '${f['url'] ?? ''}';
        final isAudio =
            type.startsWith('audio') ||
            RegExp(r'\.(m4a|mp3|aac|wav|ogg|webm|flac)(\?|$)').hasMatch(url);
        if (isAudio && url.isNotEmpty) {
          voice = url;
          break;
        }
      }
    }
    return RequestOfferDto(
      id: (json['id'] as num?)?.toInt(),
      sellerId: number(json['seller_id'] ?? seller['id'])?.toInt(),
      requestId: number(json['request_id'])?.toInt(),
      request: json['Request'] is Map
          ? Map<String, dynamic>.from(json['Request'] as Map)
          : null,
      status: json['status']?.toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      price: number(json['price']),
      // Web: giá offer là số thu (USD) — `Money kind="charged" currency="USD"`;
      // `Seller.currency` là tiền tài khoản của seller, không phải tiền của offer.
      currency: (json['charge_currency'] ?? 'USD').toString(),
      sellerDisplayName: _displayName(
        sellerProfile.isEmpty ? seller : sellerProfile,
        seller,
      ),
      sellerAvatar: _cleanImageUrl(seller['profile_picture']),
      sellerRating: number(seller['rating']),
      sellerVerified: verified is bool ? verified : null,
      serviceRating: number(service['rating']),
      serviceReviewCount: number(
        service['review_count'] ??
            service['total_reviews'] ??
            service['reviews_count'],
      ),
      serviceCategory: category['name']?.toString(),
      serviceAddress: service['address']?.toString(),
      leadTimeDays: number(service['delivery_lead_time_day']),
      voiceUrl: voice,
      createdAt: json['created_at']?.toString(),
      paymentDate: json['payment_date']?.toString(),
      paymentStatus: json['payment_status']?.toString(),
      pointsUsed: number(json['points_used']),
      pointsValue: number(json['points_value']),
      voucherValue: number(json['voucher_value']),
      voucherCode: json['voucher_code']?.toString(),
    );
  }

  /// Web `sellerDisplayName`: organization (khi `is_org_owner`) → `shop_name` của hồ sơ
  /// → `shop_name` của owner; rỗng thì nơi hiển thị tự dùng nhãn mặc định.
  static String? _displayName(Map<String, dynamic> profile, Map owner) {
    final org = profile['organization'];
    if (profile['is_org_owner'] == true &&
        org is Map &&
        org['id'] != null &&
        '${org['name'] ?? ''}'.trim().isNotEmpty) {
      return '${org['name']}'.trim();
    }
    for (final v in [profile['shop_name'], owner['shop_name']]) {
      final name = '${v ?? ''}'.trim();
      if (name.isNotEmpty) return name;
    }
    return null;
  }

  /// Web `cleanImageUrl`: bỏ `{}` / `"` thừa, chỉ nhận URL hợp lệ.
  static String? _cleanImageUrl(Object? raw) {
    final url = '${raw ?? ''}'.replaceAll(RegExp(r'[{}"]'), '').trim();
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty ? url : null;
  }
}

/// Item của `GET /user/request/{id}/matched-providers` (web `MatchedProvider`).
class MatchedProviderDto {
  final int? userId;
  final String? name;
  final String? avatar;
  final Map<String, dynamic>? country;
  final bool replied;
  final Map<String, dynamic>? expert;

  const MatchedProviderDto({
    this.userId,
    this.name,
    this.avatar,
    this.country,
    this.replied = false,
    this.expert,
  });

  factory MatchedProviderDto.fromJson(Map<String, dynamic> json) =>
      MatchedProviderDto(
        userId: json['user_id'] is num
            ? (json['user_id'] as num).toInt()
            : int.tryParse('${json['user_id'] ?? ''}'),
        name: json['name']?.toString(),
        avatar: json['avatar']?.toString(),
        country: json['country'] is Map
            ? Map<String, dynamic>.from(json['country'] as Map)
            : null,
        replied: json['replied'] == true,
        expert: json['expert'] is Map
            ? Map<String, dynamic>.from(json['expert'] as Map)
            : null,
      );
}
