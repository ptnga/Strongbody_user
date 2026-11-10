import 'package:equatable/equatable.dart';

import 'package:strongbody_buyer/modules/social_market/domain/entities/market_listing_entities.dart';

/// Hai board của trang chủ (web `HomeBoardTabs`): request cộng đồng · dịch vụ.
enum BoardKind {
  requests('requests'),
  offers('services');

  /// `kinds` của search v2.
  final String searchKind;

  const BoardKind(this.searchKind);
}

/// File đính kèm của request (JSON `attachments`).
class BoardAttachment extends Equatable {
  final String url;
  final String? name;
  final bool isPhoto;

  const BoardAttachment({required this.url, this.name, this.isPhoto = false});

  @override
  List<Object?> get props => [url, name, isPhoto];
}

/// Thẻ request của board (web `BoardRequestCard`, dữ liệu `slimRequest`).
class BoardRequest extends Equatable {
  final int id;
  final int? userId;
  final String text;

  /// Ẩn danh → không có tên / ảnh (hiện "***").
  final bool anonymous;
  final String? firstName;
  final String? lastName;
  final String? avatar;
  final String? country;
  final String? flag;
  final DateTime? createdAt;
  final String? category;
  final bool closed;
  final bool solved;
  final num? minBudget;
  final num? maxBudget;
  final num? budget;
  final String currency;

  /// `remote` · `at_office` · `at_clinic` · `at_home` · `all`.
  final String? deliveryType;
  final List<String> languages;
  final List<BoardAttachment> attachments;

  const BoardRequest({
    required this.id,
    this.userId,
    required this.text,
    this.anonymous = true,
    this.firstName,
    this.lastName,
    this.avatar,
    this.country,
    this.flag,
    this.createdAt,
    this.category,
    this.closed = false,
    this.solved = false,
    this.minBudget,
    this.maxBudget,
    this.budget,
    this.currency = 'USD',
    this.deliveryType,
    this.languages = const [],
    this.attachments = const [],
  });

  String get authorName =>
      [firstName, lastName].whereType<String>().join(' ').trim();

  @override
  List<Object?> get props => [id, text, closed, solved];
}

/// Dòng offer của board (web `OfferRow`): service + vài cờ riêng của board.
class BoardOffer extends Equatable {
  final MarketServiceEntity service;

  /// "Free consult" (không áp cho Medical Travel).
  final bool freeConsultation;

  /// Số mục đã xác minh trong identity · phone · qualification.
  final int verifiedChecks;

  /// Giá của service (web `servicePrice`): không còn giá theo hình thức nhận.
  /// Tư vấn (`pricing_mode: consultation`) → khoảng [price] – [priceMax], chỉ inquiry.
  final num? price;
  final num? priceMax;
  final bool consultation;

  /// `remote` · `at_office` · `at_home` theo thứ tự hiển thị.
  final List<String> deliveryTypes;

  const BoardOffer({
    required this.service,
    this.freeConsultation = false,
    this.verifiedChecks = 0,
    this.price,
    this.priceMax,
    this.consultation = false,
    this.deliveryTypes = const [],
  });

  int? get id => service.id;

  @override
  List<Object?> get props => [
    service,
    freeConsultation,
    verifiedChecks,
    price,
    priceMax,
    consultation,
  ];
}

/// Nước có item (facet) — chọn để lọc board.
class BoardCountry extends Equatable {
  final int? id;
  final String title;
  final String? code;
  final String? flag;
  final int count;

  const BoardCountry({
    this.id,
    required this.title,
    this.code,
    this.flag,
    this.count = 0,
  });

  @override
  List<Object?> get props => [id, title, code, count];
}

/// Bộ lọc trong popup "Filters" — mỗi nhóm một giá trị (web `BoardFilterDialog`).
class BoardFilters extends Equatable {
  /// `newest` · `relevance` · `least_responses` · `soonest` · `price_desc` · `price_asc` ·
  /// `rating` · `popular`; null = mặc định (relevance khi có từ khoá, newest khi không).
  final String? sort;

  /// Đăng trong N ngày (1 · 7 · 30).
  final int? postedDays;
  final String? delivery;

  /// Khoảng giá USD (null = không giới hạn đầu đó).
  final ({int? min, int? max})? price;

  /// Request: chỉ request chưa ai trả lời.
  final bool noResponses;

  /// Offer: chỉ provider đã xác minh / có lựa chọn miễn phí.
  final bool verified;
  final bool free;

  /// Offer: ngôn ngữ provider nói.
  final String? language;
  final BoardCountry? country;

  const BoardFilters({
    this.sort,
    this.postedDays,
    this.delivery,
    this.price,
    this.noResponses = false,
    this.verified = false,
    this.free = false,
    this.language,
    this.country,
  });

  static const none = BoardFilters();

  /// Số nhóm đang lọc (badge của nút Filters), nước tính là một.
  int get activeCount => [
    sort != null,
    postedDays != null,
    delivery != null,
    price != null,
    noResponses,
    verified || free,
    language != null,
    country != null,
  ].where((on) => on).length;

  bool get isEmpty => activeCount == 0;

  /// Có bộ lọc ngoài nước → phải dùng search v2 (feed chỉ lọc được nước / chủ đề).
  bool get needsSearch => activeCount - (country != null ? 1 : 0) > 0;

  @override
  List<Object?> get props => [
    sort,
    postedDays,
    delivery,
    price,
    noResponses,
    verified,
    free,
    language,
    country,
  ];
}

/// Một lần tải board.
class BoardQuery extends Equatable {
  final int page;
  final String keyword;
  final BoardFilters filters;

  /// Chủ đề của board Requests (`category_id`).
  final int? topicId;

  /// Ngôn ngữ giao diện (search v2 `viewer_language`).
  final String locale;

  /// Seed luân phiên của feed Offers "recommended" (web `feedSeed`): sinh mới mỗi lần
  /// mở board, dùng chung cho mọi trang cuộn sau để thứ tự không lệch.
  final String? seed;

  const BoardQuery({
    this.page = 1,
    this.keyword = '',
    this.filters = BoardFilters.none,
    this.topicId,
    this.locale = 'en',
    this.seed,
  });

  bool get isSearch => keyword.trim().isNotEmpty || filters.needsSearch;

  BoardQuery copyWith({int? page}) => BoardQuery(
    page: page ?? this.page,
    keyword: keyword,
    filters: filters,
    topicId: topicId,
    locale: locale,
    seed: seed,
  );

  @override
  List<Object?> get props => [page, keyword, filters, topicId, locale, seed];
}

/// Một trang của board.
class BoardPage<T> extends Equatable {
  final List<T> items;
  final int totalPage;

  /// Tổng kết quả (chỉ khi tìm / lọc — dòng "{n} results").
  final int? total;

  /// Số item theo nước khi tìm (`facets.country_id`): id → count.
  final Map<int, int>? countryCounts;

  /// Offer: ngôn ngữ có kết quả (`facets.languages`).
  final List<String>? languages;

  const BoardPage({
    this.items = const [],
    this.totalPage = 0,
    this.total,
    this.countryCounts,
    this.languages,
  });

  @override
  List<Object?> get props => [items, totalPage, total];
}
