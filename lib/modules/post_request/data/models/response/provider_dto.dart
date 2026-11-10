import 'dart:convert';

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

  /// Cùng quy tắc web `expertToCard` (`_components/cards/adapters.ts`).
  factory ProviderDto.fromJson(Map<String, dynamic> json) {
    Map map(Object? v) => v is Map ? v : const {};
    String text(Object? v) => v is String ? v.trim() : '';
    final user = map(json['user']);
    final organization = map(json['organization']);
    // Organization mà seller là người đại diện (web `representedOrganization`).
    final org =
        json['is_org_owner'] == true &&
            organization['id'] != null &&
            text(organization['name']).isNotEmpty
        ? organization
        : null;

    // Tên = tên shop của provider, không thì tên organization — không dùng họ tên tài khoản.
    final shop = text(json['shop_name']);
    final orgName = text(organization['name']);

    // Nghề: `profession` (bỏ id / "undefined" lưu nhầm) → `professions[]` → category.
    final rawProfession = text(json['profession']);
    final professionText =
        rawProfession.isEmpty ||
            RegExp(r'^\d+$').hasMatch(rawProfession) ||
            const {
              'undefined',
              'null',
              'nan',
            }.contains(rawProfession.toLowerCase())
        ? null
        : rawProfession;
    final professions = json['professions'] is List
        ? json['professions'] as List
        : const [];
    final firstProfession = professions
        .map((p) => text(map(p)['name']))
        .where((n) => n.isNotEmpty)
        .firstOrNull;

    final review = map(json['review_summary']);
    final rating = review['rating'];
    final avatar = text(user['profile_picture']);
    final orgLanguages = org == null
        ? const <String>[]
        : _strings(org['languages']);
    return ProviderDto(
      id: (json['id'] as num?)?.toInt(),
      userId:
          (json['user_id'] as num?)?.toInt() ?? (user['id'] as num?)?.toInt(),
      slug: json['slug']?.toString(),
      shopName: shop.isNotEmpty && shop != 'undefined' ? shop : orgName,
      firstName: user['first_name']?.toString(),
      lastName: user['last_name']?.toString(),
      profilePicture: avatar.isNotEmpty ? avatar : text(org?['logo']),
      country: _country(json, org),
      profession: professionText ?? firstProfession ?? _category(json),
      sellerVerified: json['seller_verified'] == true,
      yearsOfExperience: (json['years_of_experience'] as num?)?.toInt(),
      rating: rating is num
          ? rating.toDouble()
          : double.tryParse('${rating ?? ''}'),
      reviewCount: (review['review_count'] as num?)?.toInt(),
      skills: _strings(json['skills']),
      languages: orgLanguages.isNotEmpty
          ? orgLanguages
          : _strings(json['supported_languages']),
    );
  }

  /// Nước CHỈ từ hồ sơ seller (web `sellerPlace`): organization (khi là người đại diện)
  /// hoặc `addresses[0]`, rồi `country` của hồ sơ — không lấy `user.country`.
  static String? _country(Map<String, dynamic> json, Map? org) {
    String text(Object? v) => v is String ? v.trim() : '';
    Map? first(Object? raw) {
      var v = raw;
      if (v is String && v.trim().isNotEmpty) {
        try {
          v = jsonDecode(v);
        } on FormatException {
          return null;
        }
      }
      if (v is List) return v.whereType<Map>().firstOrNull;
      return v is Map ? v : null;
    }

    String countryTitle(Object? c) => c is Map
        ? (text(c['title']).isNotEmpty ? text(c['title']) : text(c['name']))
        : '';

    if (org != null) {
      final title = countryTitle(org['country']);
      if (title.isNotEmpty) return title;
      final address = text(first(org['address'])?['country']);
      return address.isEmpty ? null : address;
    }
    final address = text(first(json['addresses'])?['country']);
    if (address.isNotEmpty) return address;
    final title = countryTitle(json['country']);
    return title.isEmpty ? null : title;
  }

  /// Category chính (`primary_category_id`) hoặc category đầu; Medical Travel thì bỏ.
  static String? _category(Map<String, dynamic> json) {
    if (json['is_medical_travel'] == true) return null;
    final raw = json['category'] ?? json['categories'];
    final list = raw is List ? raw.whereType<Map>().toList() : const <Map>[];
    if (list.isEmpty) return null;
    final primary = json['primary_category_id'];
    final pick =
        list.where((c) => primary != null && c['id'] == primary).firstOrNull ??
        list.first;
    final name = '${pick['name'] ?? ''}'.trim();
    return name.isEmpty ? null : name;
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
