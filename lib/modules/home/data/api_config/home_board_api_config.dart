/// Endpoint các board trang chủ (web `(home-marketplace)/_lib/boardFeedApi.ts`,
/// `boardSearch.ts`). Base URL đã có `/v1`; đọc công khai bằng `x-api-key`.
class HomeBoardApiConfig {
  HomeBoardApiConfig._();

  /// Board Requests: `status=active&type=ldp&statuses=active,closed&offers_limit=1&feed=home`
  /// (+ `country_id`; tìm thì `ids=`).
  static const String requests = '/public/requests/with-offers';

  /// Nước có request → `data.list[{id, title, code, flag, count}]`.
  static const String requestCountries = '/public/requests/countries';

  /// Số liệu tuần này (`week_total`, `week_matched`) + `recent_matched` (web
  /// `getPublicRequestBoardStats`): `type=ldp&statuses=active,closed&feed=home&limit=8`.
  static const String requestBoardStats = '/public/requests/board-stats';

  /// `feed` của bảng Requests trang chủ (web `BOARD_REQUEST_FEED`): BE chỉ trả request của
  /// tài khoản seed — feed, chip nước, số liệu tuần và search v2 cùng bộ lọc này.
  static const String requestFeed = 'home';

  /// Lấy dư cho "Recently matched" (bỏ request chưa phân loại dịch vụ, hiện 3 dòng).
  static const int statsLimit = 8;

  /// Board Offers: `order_by=recommended` (+ `country_id`; tìm thì `ids=`).
  static const String services = '/public/services';

  /// Nước của seller có service.
  static const String serviceCountries = '/public/services/countries';

  /// Tìm / lọc (`kinds`, `q`, `filters`…) → id theo thứ tự, rồi tải thẻ bằng `ids`.
  static const String search = '/search/v2';

  /// Mỗi trang 10 item (web `BOARD_PAGE_SIZE`).
  static const int pageSize = 10;
}
