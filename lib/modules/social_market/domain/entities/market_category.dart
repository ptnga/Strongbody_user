import 'market_need.dart';

/// Trang con "Browse by need" — web `SOCIAL_MARKET_NAV` (`_category/config.ts`), đúng
/// thứ tự trên sidebar: Longevity · Mental Health · Personal Helper (Health Pro Advisory
/// đã bị thay bằng Mental Health); Medical Travel là [MarketPageScope.medicalTravel].
enum MarketCategory {
  longevity(route: 'longevity', slug: 'longevity-1'),
  mental(route: 'mental', slug: 'mental-wellness'),
  personalHelper(route: 'personal-helper', slug: 'personal-helper-1');

  /// Segment URL trên web (`/longevity`) — dùng làm tham số route của app.
  final String route;

  /// Slug category `provider_2026` cũ của trang.
  final String slug;

  const MarketCategory({required this.route, required this.slug});

  static MarketCategory? fromRoute(String? route) {
    for (final c in values) {
      if (c.route == route) return c;
    }
    return null;
  }
}

/// Trang của một nhãn "Browse by need" (web `CategoryPage` với `needByRoute`): 3 nhãn +
/// Medical Travel dùng CHUNG một bố cục (hero → [destinations] → mỗi category doanh nghiệp
/// một section service → experts) và listing "View all".
class MarketPageScope {
  /// null = Medical Travel.
  final MarketCategory? category;

  /// Segment URL (`longevity`, `medical-travel`).
  final String route;

  /// Slug category `provider_2026` cũ.
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

  /// Mapping category doanh nghiệp / profession của nhãn (mọi trang của app đều là nhãn).
  MarketNeed? get need => MarketNeed.byRoute(route);

  /// Phạm vi service (web `servicesScopeFor`): trang nhãn = service thuộc các category
  /// doanh nghiệp của nhãn ([sub] = chip đang chọn); dự phòng như cũ theo cờ / slug.
  Map<String, dynamic> servicesScopeFor([String? sub]) {
    final n = need;
    if (n != null) return {'provider_category_slugs': n.servicesScope(sub)};
    return isMedicalTravel
        ? const {'is_medical_travel': true}
        : {'category_slug': slug};
  }

  Map<String, dynamic> get servicesScope => servicesScopeFor();

  /// Phạm vi provider (web `providersQueryFor`): trang nhãn = doanh nghiệp theo category
  /// HOẶC expert theo profession.
  Map<String, dynamic> get providersScope =>
      need?.providersScope ??
      (isMedicalTravel
          ? {'category_slug': slug, 'is_medical_travel': true}
          : {'category_slug': slug});

  @override
  bool operator ==(Object other) =>
      other is MarketPageScope && other.route == route;

  @override
  int get hashCode => route.hashCode;
}
