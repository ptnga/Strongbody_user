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
  );
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
  final String? sellerFirstName;
  final String? sellerLastName;
  final String? sellerAvatar;
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
    this.sellerFirstName,
    this.sellerLastName,
    this.sellerAvatar,
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
      currency: (json['currency'] ?? seller['currency'])?.toString(),
      sellerFirstName: seller['first_name']?.toString(),
      sellerLastName: seller['last_name']?.toString(),
      sellerAvatar: seller['profile_picture']?.toString(),
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
}
