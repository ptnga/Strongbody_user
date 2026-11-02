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
