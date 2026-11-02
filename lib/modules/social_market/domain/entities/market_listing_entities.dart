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

  const MarketSeller({
    this.id,
    this.shopName,
    this.avatar,
    this.country,
    this.flag,
    this.profession,
    this.slug,
  });

  @override
  List<Object?> get props => [
    id,
    shopName,
    avatar,
    country,
    flag,
    profession,
    slug,
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

/// Badge hình thức trên card (web `deliveryBadges`), mỗi loại có giá riêng.
class MarketDelivery extends Equatable {
  final MarketDeliveryType type;
  final double? price;

  /// Chỉ at_home: "10 km".
  final String coverage;

  const MarketDelivery({required this.type, this.price, this.coverage = ''});

  @override
  List<Object?> get props => [type, price, coverage];
}

/// Giá hiển thị (web `servicePrice`): mức thấp nhất, `from` khi nhiều mức khác nhau.
class MarketPrice extends Equatable {
  final double? amount;
  final String text;
  final bool from;
  final String currency;

  const MarketPrice({
    required this.amount,
    required this.text,
    required this.from,
    required this.currency,
  });

  @override
  List<Object?> get props => [amount, text, from, currency];
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
  final MarketSeller seller;

  /// Field thô cho card đính kèm tin nhắn inquiry (web `cardData`).
  final num? rawPrice;
  final num? originalPrice;
  final String? status;
  final List<String> imageList;
  final List<String> coverList;
  final String? rawDescription;

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
    required this.seller,
    this.rawPrice,
    this.originalPrice,
    this.status,
    this.imageList = const [],
    this.coverList = const [],
    this.rawDescription,
  });

  String? get previewImage => images.isEmpty ? null : images.first;

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
  final bool verified;
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
    this.about,
    this.languages = const [],
    this.representativeOf,
    this.independent = false,
  });

  bool get hasRating => ratingCount > 0 && ratingValue > 0;

  @override
  List<Object?> get props => [id, userId, name, slug, ratingValue, ratingCount];
}
