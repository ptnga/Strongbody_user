/// Item expert/seller profile — `GET /user/strongbodyai/expert/balanced` (`data.list`)
/// hoặc `GET /public/profiles` (`data.data`), cùng shape.
class ProviderDto {
  final int? id;
  final int? userId;
  final String? slug;
  final String? shopName;
  final String? firstName;
  final String? lastName;
  final String? profilePicture;
  final String? country;
  final String? profession;
  final bool? sellerVerified;
  final int? yearsOfExperience;
  final double? rating;
  final int? reviewCount;
  final List<String> skills;
  final List<String> languages;

  const ProviderDto({
    this.id,
    this.userId,
    this.slug,
    this.shopName,
    this.firstName,
    this.lastName,
    this.profilePicture,
    this.country,
    this.profession,
    this.sellerVerified,
    this.yearsOfExperience,
    this.rating,
    this.reviewCount,
    this.skills = const [],
    this.languages = const [],
  });

  factory ProviderDto.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'])
        : const {};
    final country = json['country'] is Map
        ? json['country'] as Map
        : user['country'] is Map
        ? user['country'] as Map
        : const {};
    final professions = json['professions'] is List
        ? json['professions'] as List
        : const [];
    final firstProfession = professions.isNotEmpty && professions.first is Map
        ? (professions.first as Map)['name']?.toString()
        : null;
    final review = json['review_summary'] is Map
        ? json['review_summary'] as Map
        : const {};
    final rating =
        review['rating'] ??
        json['rating'] ??
        json['avg_rating'] ??
        json['rating_avg'];
    return ProviderDto(
      id: (json['id'] as num?)?.toInt(),
      userId:
          (json['user_id'] as num?)?.toInt() ?? (user['id'] as num?)?.toInt(),
      slug: json['slug']?.toString(),
      shopName: json['shop_name']?.toString(),
      firstName: user['first_name']?.toString(),
      lastName: user['last_name']?.toString(),
      profilePicture: user['profile_picture']?.toString(),
      country: (country['title'] ?? country['name'])?.toString(),
      profession: firstProfession,
      sellerVerified: json['seller_verified'] as bool?,
      yearsOfExperience: (json['years_of_experience'] as num?)?.toInt(),
      rating: rating is num
          ? rating.toDouble()
          : double.tryParse('${rating ?? ''}'),
      reviewCount: (review['review_count'] as num?)?.toInt(),
      skills: _strings(json['skills']),
      languages: _strings(json['supported_languages']),
    );
  }

  static List<String> _strings(dynamic value) => value is List
      ? value
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
      : const [];
}

/// Service của seller — `GET /public/services?user_id=` (lấy giá "from" + cách cung cấp).
class ProviderServiceDto {
  final double? price;
  final String? currency;
  final String? sessionMode;
  final int? durationMinutes;
  final int? sessionCount;

  /// `delivery_options[]`: `{ delivery_type: remote|at_home|at_office, price, is_active }`.
  final List<({String type, double? price})> deliveryOptions;

  const ProviderServiceDto({
    this.price,
    this.currency,
    this.sessionMode,
    this.durationMinutes,
    this.sessionCount,
    this.deliveryOptions = const [],
  });

  factory ProviderServiceDto.fromJson(Map<String, dynamic> json) {
    final options = json['delivery_options'] is List
        ? (json['delivery_options'] as List)
              .whereType<Map>()
              .where((o) => o['is_active'] != false)
              .map(
                (o) => (
                  type: o['delivery_type']?.toString() ?? '',
                  price: (o['price'] as num?)?.toDouble(),
                ),
              )
              .toList()
        : const <({String type, double? price})>[];
    return ProviderServiceDto(
      price: (json['price'] as num?)?.toDouble(),
      currency: json['currency']?.toString(),
      sessionMode: json['session_mode']?.toString(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      sessionCount: (json['session_count'] as num?)?.toInt(),
      deliveryOptions: options,
    );
  }
}
