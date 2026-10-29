/// Endpoint chat — strongbody-api (base đã có `/v1`, header `Scope: strongbody-ai`).
/// chat-server (WS / history / publish) đi qua SDK `strongbody_chat_client`.
class ChatApiConfig {
  ChatApiConfig._();

  static const String conversations = '/user/chat-server/conversations';
  static const String createChannel = '/user/chat-server/create';
  static const String refreshToken = '/user/chat-server/refresh-token';
  static const String sendVoice = '/user/chat-server/voice';
  static const String unreadCounts = '/user/unread-counts';
  static const String personalUpdateToken =
      '/user/conversation/personal-update-token';
  static const String searchUsers = '/buyer/auth/users/search';
  static const String markRead = '/user/mark-read-and-status';
  static const String aiConsents = '/user/ai-consents';
  static const String voiceTranslationBatch =
      '/user/vertex-ai/v2/voice-translation/batch';

  /// Offer provider gửi cho request của mình (như My requests / web `useOffers`).
  static const String requestOffers = '/buyer/offer/sent-offers-by-my-requests';

  static String translationSettings(String channelId) =>
      '/user/conversations/$channelId/translation/settings';

  static String translatedMessages(String channelId) =>
      '/user/v2/conversations/$channelId/messages/translated';

  static String translateMessage(String channelId, String messageId) =>
      '/user/conversations/$channelId/messages/$messageId/translate';

  static String conversationOffers(String channelId) =>
      '/user/offer/conversation/$channelId';

  /// Kênh phụ trên cùng JWT của hội thoại.
  static String textTranslationChannel(String channelId) =>
      '${channelId}_translation';
  static String voiceTranslationChannel(String channelId) =>
      '${channelId}_voice_translation';
  static String updatesChannel(int userId) => 'user_${userId}_updates';
}
