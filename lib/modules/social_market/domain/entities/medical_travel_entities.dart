import 'package:equatable/equatable.dart';

/// Chứng nhận của cơ sở (organization) — lọc service + badge (web `CERT_LABELS`).
enum MarketCert {
  jciAccredited('jci_accredited'),
  iso9001('iso_9001'),
  visaLetterOnRequest('visa_letter_on_request'),
  medicalTranslator('medical_translator');

  final String apiValue;

  const MarketCert(this.apiValue);
}

/// Một nước trong "Browse by destination" (`/buyer/countries/destinations`).
class MarketDestination extends Equatable {
  final int id;
  final String country;
  final String? code;
  final String? flag;
  final String? image;

  /// Mô tả ngắn (admin nhập), đã bỏ HTML.
  final String focus;

  const MarketDestination({
    required this.id,
    required this.country,
    this.code,
    this.flag,
    this.image,
    this.focus = '',
  });

  @override
  List<Object?> get props => [id, country, code];
}

/// Một nước ở trang destination (`/country?code=`).
class MarketCountry extends Equatable {
  final int id;
  final String title;
  final String code;
  final String? flag;
  final String description;

  /// Gallery trước (cover thường chỉ là cờ).
  final List<String> images;

  const MarketCountry({
    required this.id,
    required this.title,
    required this.code,
    this.flag,
    this.description = '',
    this.images = const [],
  });

  @override
  List<Object?> get props => [id, code];
}

/// Câu hỏi thường gặp của service.
class MarketFaq extends Equatable {
  final String question;
  final List<String> answers;

  const MarketFaq({required this.question, required this.answers});

  @override
  List<Object?> get props => [question, answers];
}

/// Chi tiết service (web `ServiceDetail` + các helper `_lib/detail.ts`).
class MarketServiceDetail extends Equatable {
  final int id;
  final int userId;
  final String title;
  final String slug;

  /// HTML (rich text) — trang chi tiết tự chuyển thành đoạn / gạch đầu dòng.
  final String? description;

  /// Cover trước, rồi gallery, bỏ trùng.
  final List<String> images;
  final num price;
  final int? duration;

  /// minute | hour | day (lạ → day).
  final String durationUnit;
  final List<({String code, String label})> languages;
  final double rating;
  final bool isMedicalTravel;
  final List<MarketFaq> faqs;
  final String? locationTitle;
  final String? locationFlag;

  /// Organization gắn với service, không có thì tên shop / organization seller đại diện.
  final String? organizationName;

  /// Tên shop của seller (khối "Not sure this is the right package?").
  final String? providerName;
  final String? providerSlug;
  final String? providerAvatar;
  final List<MarketCert> certs;
  final List<String> included;
  final List<String> notIncluded;
  final String? roadmapTitle;
  final String? roadmapSteps;

  const MarketServiceDetail({
    required this.id,
    required this.userId,
    required this.title,
    this.slug = '',
    this.description,
    this.images = const [],
    this.price = 0,
    this.duration,
    this.durationUnit = 'day',
    this.languages = const [],
    this.rating = 0,
    this.isMedicalTravel = false,
    this.faqs = const [],
    this.locationTitle,
    this.locationFlag,
    this.organizationName,
    this.providerName,
    this.providerSlug,
    this.providerAvatar,
    this.certs = const [],
    this.included = const [],
    this.notIncluded = const [],
    this.roadmapTitle,
    this.roadmapSteps,
  });

  @override
  List<Object?> get props => [id, title, images, languages];
}

/// Mã vùng điện thoại "+84" kèm cờ (từ bảng countries của BE).
class PhoneCodeOption extends Equatable {
  final String code;
  final String label;

  const PhoneCodeOption({required this.code, required this.label});

  @override
  List<Object?> get props => [code, label];
}

/// Payload `POST /buyer/appointment-request` (web `AppointmentRequestPayload`).
class AppointmentRequest extends Equatable {
  final int serviceId;

  /// asap | within_3_months | specific_date | not_sure.
  final String timeframe;

  /// YYYY-MM-DD khi `specific_date`.
  final String? preferredFrom;
  final String firstName;
  final String email;

  /// email | whatsapp | phone_call.
  final String contactPreference;

  /// E.164 khi liên hệ qua WhatsApp / gọi điện.
  final String? phone;
  final String? preferredLanguage;
  final String notes;

  const AppointmentRequest({
    required this.serviceId,
    required this.timeframe,
    required this.firstName,
    required this.email,
    required this.contactPreference,
    this.preferredFrom,
    this.phone,
    this.preferredLanguage,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'service_id': serviceId,
    'timeframe_type': timeframe,
    'first_name': firstName,
    'email': email,
    'contact_preference': contactPreference,
    'notes': notes,
    'preferred_from': ?preferredFrom,
    'phone': ?phone,
    'preferred_language': ?preferredLanguage,
  };

  @override
  List<Object?> get props => [serviceId, timeframe, email];
}

/// Hàng coordinator: seller category theo score trước, hết thì seller ngẫu nhiên
/// ngoài category theo `seed` (web `CoordinatorsCursor`).
sealed class CoordinatorsCursor extends Equatable {
  const CoordinatorsCursor();
}

class CoordinatorsPhase extends CoordinatorsCursor {
  /// true = seller của category (`sort=score`), false = ngẫu nhiên (`sort=random`).
  final bool category;
  final int page;
  final String seed;

  const CoordinatorsPhase({
    required this.category,
    required this.page,
    required this.seed,
  });

  @override
  List<Object?> get props => [category, page, seed];
}

class CoordinatorsDone extends CoordinatorsCursor {
  const CoordinatorsDone();

  @override
  List<Object?> get props => [];
}

/// Bộ lọc service Medical Travel (landing "Recommended services" + tab Services
/// của destination) — web `PackagesFilters`.
class MedicalServiceFilters extends Equatable {
  /// recommended | top_rated | price.
  final String sort;
  final bool priceDesc;
  final double? minPrice;
  final double? maxPrice;
  final Set<MarketCert> certs;
  final int? countryId;
  final String keyword;

  const MedicalServiceFilters({
    this.sort = 'recommended',
    this.priceDesc = false,
    this.minPrice,
    this.maxPrice,
    this.certs = const {},
    this.countryId,
    this.keyword = '',
  });

  MedicalServiceFilters copyWith({
    String? sort,
    bool? priceDesc,
    double? Function()? minPrice,
    double? Function()? maxPrice,
    Set<MarketCert>? certs,
    String? keyword,
  }) => MedicalServiceFilters(
    sort: sort ?? this.sort,
    priceDesc: priceDesc ?? this.priceDesc,
    minPrice: minPrice != null ? minPrice() : this.minPrice,
    maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
    certs: certs ?? this.certs,
    countryId: countryId,
    keyword: keyword ?? this.keyword,
  );

  /// Query `/public/services` (web `buildServicesParams`, slug Medical Travel).
  Map<String, dynamic> toQuery({required int page, required int limit}) => {
    'limit': limit,
    if (page > 1) 'page': page,
    'is_medical_travel': true,
    'supported_country_id': ?countryId,
    if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
    if (sort == 'top_rated') ...{'order_by': 'rating', 'order_dir': 'DESC'},
    if (sort == 'price') ...{
      'order_by': 'price',
      'order_dir': priceDesc ? 'DESC' : 'ASC',
    },
    'min_price': ?minPrice,
    'max_price': ?maxPrice,
    for (final c in certs) c.apiValue: true,
  };

  @override
  List<Object?> get props => [
    sort,
    priceDesc,
    minPrice,
    maxPrice,
    certs,
    countryId,
    keyword,
  ];
}

/// Bộ lọc tab Providers của destination (web `fetchCountrySellers`).
class CountrySellerFilters extends Equatable {
  final int countryId;
  final String keyword;
  final bool verified;
  final bool introCall;
  final String language;

  const CountrySellerFilters({
    required this.countryId,
    this.keyword = '',
    this.verified = false,
    this.introCall = false,
    this.language = '',
  });

  CountrySellerFilters copyWith({
    String? keyword,
    bool? verified,
    bool? introCall,
    String? language,
  }) => CountrySellerFilters(
    countryId: countryId,
    keyword: keyword ?? this.keyword,
    verified: verified ?? this.verified,
    introCall: introCall ?? this.introCall,
    language: language ?? this.language,
  );

  Map<String, dynamic> toQuery({required int page, required int limit}) => {
    'limit': limit,
    'page': page,
    'supported_country_id': countryId,
    'org_owner': true,
    'is_medical_travel': true,
    'category_slug': 'medical-travel-2',
    if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
    if (verified) 'verified': true,
    if (introCall) 'intro_call': true,
    if (language.isNotEmpty) 'language': language,
  };

  @override
  List<Object?> get props => [
    countryId,
    keyword,
    verified,
    introCall,
    language,
  ];
}
