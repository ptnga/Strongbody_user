import 'package:strongbody_buyer/core/config/environment.dart';

class PostRequestApiConfig {
  PostRequestApiConfig._();

  /// strongbody-api (base URL đã có `/v1`). Envelope `{code, message, data}`, code 0 = OK.
  static const String speechToText = '/speech-to-text';

  /// Đăng request công khai cho mọi provider phù hợp (web + Multime cùng dùng).
  static const String buyerRequest = '/buyer/request';

  /// Gửi request riêng cho một seller (`seller_id`, `is_privated=true`) — web `sendRequestToSeller`.
  static const String buyerRequestToSeller = '/buyer/request/to-seller';

  /// Request của buyer (Multime `request_buyer_repository.dart`).
  static const String myRequests = '/user/requests';

  /// Offer provider gửi cho request của buyer (`?request_id=`) — web `useOffers`, Multime `FetchMyRequestBuyer`.
  static const String requestOffers = '/buyer/offer/sent-offers-by-my-requests';

  /// Danh sách expert theo từ khoá nghề — web `getExperts` (`src/api/experts`), header `x-api-key`.
  static const String expertsBalanced = '/user/strongbodyai/expert/balanced';

  /// Service của một seller (`?user_id=`) → giá "from" + cách cung cấp.
  static const String publicServices = '/public/services';

  /// Profile chi tiết của seller → `availabilities` (lịch rảnh hằng tuần).
  static String sellerProfileBySlug(String slug) =>
      '/seller/profile/slug/$slug';

  /// API route của web — LLM key nằm ở server web nên app gọi qua đây giống trình duyệt.
  static String get requestDraft =>
      '${AppConfig.webBaseUrl}/api/ai/request-draft';

  /// Route chuyển giọng nói cũ của web (dùng khi BE chưa có `/speech-to-text`).
  static String get legacyTranscription =>
      '${AppConfig.webBaseUrl}/api/audio/transcriptions';

  /// Mã lỗi trong envelope BE.
  static const int codeRateLimited = 42914;
  static const int codeNotFound = 65;
}
