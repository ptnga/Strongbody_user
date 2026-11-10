import 'package:equatable/equatable.dart';

/// Một trang của list có phân trang (listing service / provider…).
class MarketPage<T> extends Equatable {
  final List<T> items;
  final int total;
  final int totalPages;

  const MarketPage({
    required this.items,
    required this.total,
    required this.totalPages,
  });

  @override
  List<Object?> get props => [items, total, totalPages];
}

/// 3 mục xác minh công khai của provider (web `ProviderVerifications`): danh tính,
/// số điện thoại (OTP), bằng cấp. Có ít nhất 1 mục → card hiện trạng thái verified.
class MarketVerifications extends Equatable {
  final bool identity;
  final bool phone;
  final bool diploma;

  const MarketVerifications({
    this.identity = false,
    this.phone = false,
    this.diploma = false,
  });

  bool get any => identity || phone || diploma;

  /// Số mục đã xác minh (chấm số trên huy hiệu `VerificationSummary`).
  int get count => [identity, phone, diploma].where((v) => v).length;

  @override
  List<Object?> get props => [identity, phone, diploma];
}

/// Người bán đi kèm service — web `resolveSeller()`: danh tính là TÊN SHOP (hoặc
/// organization khi là người đại diện), nước/cờ chỉ từ hồ sơ seller.
class MarketSeller extends Equatable {
  /// User id — người nhận inquiry / chat.
  final int? id;

  /// Tên shop; null → card hiện nhãn mặc định "StrongBody Provider".
  final String? shopName;
  final String? avatar;
  final String? country;
  final String? flag;
  final String? profession;

  /// Slug hồ sơ seller (`/{slug}`).
  final String? slug;

  /// Mục đã xác minh (web `seller.verifications`); null = chưa mục nào.
  final MarketVerifications? verifications;

  /// Ngôn ngữ làm việc của seller (tên đầy đủ: "English").
  final List<String> languages;

  const MarketSeller({
    this.id,
    this.shopName,
    this.avatar,
    this.country,
    this.flag,
    this.profession,
    this.slug,
    this.verifications,
    this.languages = const [],
  });

  bool get verified => verifications?.any ?? false;

  @override
  List<Object?> get props => [
    id,
    shopName,
    avatar,
    country,
    flag,
    profession,
    slug,
    verifications,
    languages,
  ];
}

/// Cách cung cấp — khớp `entity.ServiceDeliveryMethod` của backend.
enum MarketDeliveryType {
  remote('remote'),
  atOffice('at_office'),
  atHome('at_home');

  final String apiValue;

  const MarketDeliveryType(this.apiValue);

  static MarketDeliveryType? fromApi(String? value) {
    for (final t in values) {
      if (t.apiValue == value) return t;
    }
    return null;
  }
}

/// Badge hình thức trên card (web `deliveryBadges`). Hình thức nhận KHÔNG có giá riêng
/// (giá là của service — [MarketPrice]); [price] chỉ còn là dữ liệu cũ của API.
class MarketDelivery extends Equatable {
  final MarketDeliveryType type;
  final double? price;

  /// Chỉ at_home: "10 km".
  final String coverage;

  const MarketDelivery({required this.type, this.price, this.coverage = ''});

  @override
  List<Object?> get props => [type, price, coverage];
}

/// Giá hiển thị (web `servicePrice`) — của SERVICE, không theo hình thức nhận:
/// Đặt ngay = 1 giá (`price`); Tư vấn (`pricing_mode = consultation`) = khoảng
/// `price` – `price_max` ("$50 – $200"), không mua được, chỉ inquiry.
class MarketPrice extends Equatable {
  /// Giá chung (Đặt ngay) hoặc giá Từ (Tư vấn).
  final double? amount;

  /// Giá Đến — chỉ service Tư vấn.
  final double? max;

  /// "$80" / "$50 – $200".
  final String text;

  /// Luôn false: giá không còn theo hình thức nhận nên không có "From" (giữ cho tương thích).
  final bool from;

  /// Service Tư vấn: card hiện nhãn "Consultation", CTA chỉ là Send inquiry.
  final bool consultation;
  final String currency;

  const MarketPrice({
    required this.amount,
    required this.text,
    this.from = false,
    required this.currency,
    this.max,
    this.consultation = false,
  });

  @override
  List<Object?> get props => [amount, max, text, from, consultation, currency];
}

class MarketServiceEntity extends Equatable {
  final int? id;
  final String slug;
  final String title;

  /// Mô tả đã bỏ HTML (API trả rich text).
  final String description;

  /// Loại hình Medical Travel (cờ BE): ẩn giá, nút "View & book".
  final bool isMedicalTravel;
  final List<String> images;
  final List<MarketDelivery> deliveries;
  final MarketPrice? price;

  /// Giá gạch ngang — chỉ khi `original_price` cao hơn giá đang bán.
  final String? strikePrice;

  /// Dòng meta: bán kính phục vụ + ngôn ngữ (web `metaLine`).
  final String? coverage;
  final String? languages;

  /// `location || address || nước seller`; null → "Online".
  final String? place;

  /// Cờ khi [place] là một nước (nước seller / nước cơ sở Medical Travel).
  final String? placeFlag;
  final MarketSeller seller;

  /// Field thô cho card đính kèm tin nhắn inquiry (web `cardData`).
  final num? rawPrice;
  final num? originalPrice;
  final String? status;
  final List<String> imageList;
  final List<String> coverList;
  final String? rawDescription;

  /// `pricing_mode` thô: 'fixed' (Đặt ngay, mặc định) | 'consultation' (Tư vấn).
  final String? pricingMode;

  /// `price_max` thô (Giá Đến của service Tư vấn) — gửi kèm card inquiry.
  final num? priceMax;

  const MarketServiceEntity({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.isMedicalTravel,
    required this.images,
    required this.deliveries,
    required this.price,
    required this.strikePrice,
    required this.coverage,
    required this.languages,
    required this.place,
    this.placeFlag,
    required this.seller,
    this.rawPrice,
    this.originalPrice,
    this.status,
    this.imageList = const [],
    this.coverList = const [],
    this.rawDescription,
    this.pricingMode,
    this.priceMax,
  });

  String? get previewImage => images.isEmpty ? null : images.first;

  /// Service Tư vấn (web `isConsultationService`): khoảng giá, không Book / View & book.
  bool get isConsultation => pricingMode == 'consultation';

  /// Ảnh card: CHỈ ảnh bìa (cover), chưa có bìa → ảnh đầu tiên (web `firstImage(cover, image)`).
  String? get coverImage => coverList.isNotEmpty
      ? coverList.first
      : imageList.isNotEmpty
      ? imageList.first
      : previewImage;

  @override
  List<Object?> get props => [id, slug, title, price, deliveries, seller];
}

/// Card hồ sơ (biến thể `profile` của web `ExpertCard`, dữ liệu `expertToCard`).
class MarketExpertEntity extends Equatable {
  /// Id hồ sơ seller — target của engagement `seller_profile`.
  final int? id;
  final int? userId;

  /// Tên shop / organization; rỗng → nhãn mặc định.
  final String name;
  final String? slug;
  final String? avatar;

  /// Nghề / category; null + `medicalTravel` → nhãn "Medical Travel".
  final String? subtitle;
  final bool medicalTravel;
  final String? country;
  final String? flag;
  final int? yearsOfExperience;
  final double ratingValue;
  final int ratingCount;
  final int? booked;

  /// Đã xác minh danh tính (`seller_verified`).
  final bool verified;

  /// 3 mục xác minh công khai (ID / phone / bằng cấp) — huy hiệu trên avatar.
  final MarketVerifications? verifications;

  /// Tổ chức của provider — hiện dưới tên (bỏ khi trùng tên provider).
  final String? organization;
  final String? about;
  final List<String> languages;

  /// Coordinator (Medical Travel): "Representative of {org}" / "Independent …"
  /// thay dòng phụ khi không có nghề (web `affiliation`).
  final String? representativeOf;
  final bool independent;

  const MarketExpertEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.slug,
    this.avatar,
    this.subtitle,
    this.medicalTravel = false,
    this.country,
    this.flag,
    this.yearsOfExperience,
    this.ratingValue = 0,
    this.ratingCount = 0,
    this.booked,
    this.verified = false,
    this.verifications,
    this.organization,
    this.about,
    this.languages = const [],
    this.representativeOf,
    this.independent = false,
  });

  bool get hasRating => ratingCount > 0 && ratingValue > 0;

  /// Nguồn chỉ có cờ `verified` (danh tính) → coi như 1 mục ID (web `cardVerifications`).
  MarketVerifications? get cardVerifications =>
      verifications ??
      (verified ? const MarketVerifications(identity: true) : null);

  @override
  List<Object?> get props => [id, userId, name, slug, ratingValue, ratingCount];
}
