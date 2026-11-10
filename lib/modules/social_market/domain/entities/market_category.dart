/// Trang con của Social Market — web `SOCIAL_MARKET_NAV` (`_category/config.ts`),
/// đúng thứ tự trên sidebar. 3 trang đầu là bản sao trang marketplace lọc theo
/// category (`CategoryMarketplacePage`); Medical Travel là landing riêng.
enum MarketCategory {
  longevity(route: 'longevity', slug: 'longevity-1'),
  healthProAdvisory(
    route: 'health-pro-advisory',
    slug: 'health-pro-advisory-1',
  ),
  personalHelper(route: 'personal-helper', slug: 'personal-helper-1');

  /// Segment URL trên web (`/longevity`) — dùng làm tham số route của app.
  final String route;

  /// Slug category `provider_2026` mà API lọc service / seller theo.
  final String slug;

  const MarketCategory({required this.route, required this.slug});

  static MarketCategory? fromRoute(String? route) {
    for (final c in values) {
      if (c.route == route) return c;
    }
    return null;
  }
}

/// Trang category của web (`CategoryPageConfig` → `CategoryPage`): 3 marketplace +
/// Medical Travel dùng CHUNG một bố cục (hero → [destinations] → spotlight → services →
/// services theo ngôn ngữ → experts) và listing "View all".
class MarketPageScope {
  /// null = Medical Travel.
  final MarketCategory? category;

  /// Segment URL (`longevity`, `medical-travel`).
  final String route;

  /// Slug category `provider_2026`.
  final String slug;

  const MarketPageScope._(this.category, this.route, this.slug);

  MarketPageScope.of(MarketCategory c) : this._(c, c.route, c.slug);

  /// Web `MEDICAL_TRAVEL` (`/medical-travel`, slug `medical-travel-2`).
  static const medicalTravel = MarketPageScope._(
    null,
    'medical-travel',
    'medical-travel-2',
  );

  bool get isMedicalTravel => category == null;

  /// Phạm vi service (web `servicesScopeFor`): Medical Travel lọc theo cờ
  /// `is_medical_travel` (không còn là category của service), còn lại theo slug.
  Map<String, dynamic> get servicesScope => isMedicalTravel
      ? const {'is_medical_travel': true}
      : {'category_slug': slug};

  /// Phạm vi provider (web `providersQueryFor`): Medical Travel gửi cả slug cũ lẫn cờ.
  Map<String, dynamic> get providersScope => isMedicalTravel
      ? {'category_slug': slug, 'is_medical_travel': true}
      : {'category_slug': slug};

  @override
  bool operator ==(Object other) =>
      other is MarketPageScope && other.route == route;

  @override
  int get hashCode => route.hashCode;
}
