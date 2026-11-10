/// Endpoint các board trang chủ (web `(home-marketplace)/_lib/boardFeedApi.ts`,
/// `boardSearch.ts`). Base URL đã có `/v1`; đọc công khai bằng `x-api-key`.
class HomeBoardApiConfig {
  HomeBoardApiConfig._();

  /// Board Requests: `status=active&type=ldp&statuses=active,closed&offers_limit=1`
  /// (+ `country_id`, `category_id`; tìm thì `ids=`).
  static const String requests = '/public/requests/with-offers';

  /// Nước có request → `data.list[{id, title, code, flag, count}]`.
  static const String requestCountries = '/public/requests/countries';

  /// Board Offers: `order_by=recommended` (+ `country_id`; tìm thì `ids=`).
  static const String services = '/public/services';

  /// Nước của seller có service.
  static const String serviceCountries = '/public/services/countries';

  /// Tìm / lọc (`kinds`, `q`, `filters`…) → id theo thứ tự, rồi tải thẻ bằng `ids`.
  static const String search = '/search/v2';

  /// Mỗi trang 10 item (web `BOARD_PAGE_SIZE`).
  static const int pageSize = 10;
}
