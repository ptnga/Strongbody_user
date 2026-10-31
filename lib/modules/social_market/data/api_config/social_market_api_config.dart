/// Endpoint của Social Market — đúng các API trang marketplace theo category của web
/// (`src/app/[locale]/(HOME_CATEGORY)`, nhánh live-v1). Base URL đã có `/v1`.
class SocialMarketApiConfig {
  SocialMarketApiConfig._();

  /// Mục Selling + listing service (web `getServices`, header `x-api-key`) → `data.list`.
  static const String publicServices = '/public/services';

  /// Mục Profiles + listing provider (web `getExperts`) → `data.list`.
  static const String expertsBalanced = '/user/strongbodyai/expert/balanced';

  /// Mục Provider's Offers (web `getPublicOffers`, mặc định `status=active`).
  static const String publicOffers = '/public/public-offers';

  /// Mục Social Market Requests (web `getPublicRequestsWithOffers`, `type=ldp`).
  static const String publicRequestsWithOffers = '/public/requests/with-offers';

  /// Mục Health Solution Library (web `getHealthSolutions`).
  static const String healthSolutions = '/public/health-solution';

  /// Like / save: summary dùng optional JWT (khách vẫn lấy được số đếm).
  static const String engagementSummary = '/user/engagement/summary';

  static String engagement(String kind, String targetType, int targetId) =>
      '/user/engagement/$kind/$targetType/$targetId';

  /// Inquiry (service / offer): backend tạo kèm request private cho seller.
  static const String inquiries = '/user/inquiries';

  /// Bookkeeping "đã gửi service vào kênh" (web `checkMessageProduct` / `sendMessageService`).
  static const String messageServiceCheck = '/user/message-service/check';
  static const String messageService = '/user/message-service';

  /// "I want a solution of this type" → báo các provider phù hợp.
  static String healthSolutionMatching(int id) =>
      '/user/health-solution/$id/matching';

  //-----------------MEDICAL TRAVEL---------------
  /// Hàng coordinator (web `fetchExpertsPage`: `sort=score|random`, `org_owner`, `seed`).
  static const String expertsFeatured = '/user/strongbodyai/expert/featured';

  /// Nước có service / seller Medical Travel (`?is_medical_travel=true`) → `data.data`.
  static const String countryDestinations = '/buyer/countries/destinations';

  /// Chi tiết service (web `getBuyerServiceById`).
  static String buyerService(int id) => '/buyer/service/$id';

  /// Form "Request an appointment" — khách gửi được (optional JWT).
  static const String appointmentRequest = '/buyer/appointment-request';

  /// Một nước theo mã ISO (trang destination).
  static const String countryByCode = '/country';

  /// Danh sách nước (mã vùng điện thoại của form appointment).
  static const String activeCountries = '/countries/active';
}
