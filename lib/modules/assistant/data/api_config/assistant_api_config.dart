import 'package:strongbody_buyer/core/config/environment.dart';

class AssistantApiConfig {
  AssistantApiConfig._();

  /// Route proxy của web (`src/app/api/search/assistant/chat/route.ts`) sang BE
  /// `POST /v1/search/assistant/chat`, trả server-sent events. Web giữ API key của BE
  /// phía server nên app gọi qua web (như `/api/ai/request-draft`).
  static String get chat => '${AppConfig.webBaseUrl}/api/search/assistant/chat';
}
