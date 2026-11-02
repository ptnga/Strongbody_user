import 'package:equatable/equatable.dart';

/// Một khung giờ theo thứ: `("mon", "09:00–17:00")`.
typedef MarketScheduleSlot = ({String day, String times});

class MarketMedia extends Equatable {
  final String url;
  final String? name;
  final bool isVideo;

  const MarketMedia({required this.url, this.name, this.isVideo = false});

  @override
  List<Object?> get props => [url, name, isVideo];
}

/// Public Offer (`/public/public-offers`, web `OfferCard` + `slimOffer`).
class MarketOfferEntity extends Equatable {
  final int? id;

  /// User id người đăng — người nhận inquiry.
  final int? sellerUserId;

  /// Tên shop, không có thì họ tên; null → "A helper".
  final String? sellerName;
  final String? sellerAvatar;
  final String? profession;
  final String? country;
  final String? flag;
  final DateTime? createdAt;
  final String detail;
  final String currency;
  final String? pricingUnit;

  /// Giá theo hình thức đã nhập: `("remote", 40)`.
  final List<({String mode, double amount})> prices;
  final List<String> deliveryTypes;
  final num? durationValue;
  final String? durationUnit;
  final List<MarketScheduleSlot> schedule;
  final List<String> languages;

  /// jsonb tự do — cặp key/value (key `radius_km` dịch riêng).
  final List<({String key, String value})> serviceLocation;
  final List<({String key, String value})> coverageArea;
  final String? category;
  final bool acceptTravelingPatients;
  final String? additionalRequirements;
  final String? expectedResult;
  final String? stories;
  final List<String> hashtags;
  final List<MarketMedia> media;

  const MarketOfferEntity({
    required this.id,
    required this.sellerUserId,
    this.sellerName,
    this.sellerAvatar,
    this.profession,
    this.country,
    this.flag,
    this.createdAt,
    this.detail = '',
    this.currency = 'USD',
    this.pricingUnit,
    this.prices = const [],
    this.deliveryTypes = const [],
    this.durationValue,
    this.durationUnit,
    this.schedule = const [],
    this.languages = const [],
    this.serviceLocation = const [],
    this.coverageArea = const [],
    this.category,
    this.acceptTravelingPatients = false,
    this.additionalRequirements,
    this.expectedResult,
    this.stories,
    this.hashtags = const [],
    this.media = const [],
  });

  /// Giá thấp nhất trong các hình thức (web `headlinePrice`).
  double? get minPrice => prices.isEmpty
      ? null
      : prices.map((p) => p.amount).reduce((a, b) => a < b ? a : b);

  @override
  List<Object?> get props => [id, sellerUserId, detail, prices, createdAt];
}

/// Ngân sách request (web `formatBudget`): đã định dạng tiền theo `currency`.
sealed class MarketBudget {
  const MarketBudget();
}

class BudgetExact extends MarketBudget {
  final String amount;
  const BudgetExact(this.amount);
}

class BudgetRange extends MarketBudget {
  final String min;
  final String max;
  const BudgetRange(this.min, this.max);
}

class BudgetFrom extends MarketBudget {
  final String min;
  const BudgetFrom(this.min);
}

class BudgetUpTo extends MarketBudget {
  final String max;
  const BudgetUpTo(this.max);
}

/// Request công khai (`/public/requests/with-offers`, web `RequestCard`). Người
/// đăng ẩn danh: chỉ ký tự đầu + avatar mờ.
class MarketRequestEntity extends Equatable {
  final int? id;
  final int? userId;
  final String text;
  final String? authorFirstName;
  final String? avatar;
  final String? country;
  final DateTime? createdAt;
  final String? deliveryType;
  final DateTime? deadline;
  final List<MarketScheduleSlot> schedule;
  final List<String> sellerLanguages;
  final MarketBudget? budget;
  final List<String> categories;
  final String? voiceUrl;
  final List<MarketMedia> attachments;
  final int conversations;
  final int offers;
  final bool solved;

  const MarketRequestEntity({
    required this.id,
    required this.userId,
    required this.text,
    this.authorFirstName,
    this.avatar,
    this.country,
    this.createdAt,
    this.deliveryType,
    this.deadline,
    this.schedule = const [],
    this.sellerLanguages = const [],
    this.budget,
    this.categories = const [],
    this.voiceUrl,
    this.attachments = const [],
    this.conversations = 0,
    this.offers = 0,
    this.solved = false,
  });

  @override
  List<Object?> get props => [id, text, createdAt, offers, solved];
}

/// Health Solution Library (`/public/health-solution`).
class HealthSolutionEntity extends Equatable {
  final int id;
  final String title;
  final List<({int id, String name})> categories;
  final String? applicableWhen;
  final String? method;
  final String? expectedResult;
  final String? notes;
  final List<String> hashtags;

  /// Mô tả soạn sẵn cho form request ("I want a solution of this type").
  final String? requestTemplate;

  const HealthSolutionEntity({
    required this.id,
    required this.title,
    this.categories = const [],
    this.applicableWhen,
    this.method,
    this.expectedResult,
    this.notes,
    this.hashtags = const [],
    this.requestTemplate,
  });

  @override
  List<Object?> get props => [id, title];
}

/// Số like / save / contact + trạng thái của mình (`/user/engagement/summary`).
class EngagementState extends Equatable {
  final int likes;
  final int saves;
  final int contacts;
  final bool liked;
  final bool saved;

  const EngagementState({
    this.likes = 0,
    this.saves = 0,
    this.contacts = 0,
    this.liked = false,
    this.saved = false,
  });

  static const empty = EngagementState();

  EngagementState copyWith({
    int? likes,
    int? saves,
    int? contacts,
    bool? liked,
    bool? saved,
  }) => EngagementState(
    likes: likes ?? this.likes,
    saves: saves ?? this.saves,
    contacts: contacts ?? this.contacts,
    liked: liked ?? this.liked,
    saved: saved ?? this.saved,
  );

  @override
  List<Object?> get props => [likes, saves, contacts, liked, saved];
}

/// `target_type` của engagement — đúng giá trị web truyền.
enum EngagementTarget {
  service('service'),
  sellerProfile('seller_profile'),
  offer('offer');

  final String apiValue;

  const EngagementTarget(this.apiValue);
}

enum EngagementKind { like, save }
