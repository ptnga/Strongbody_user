class RouteName {
  RouteName._();

  static const String rootScreen = '/';

  /// Màn splash khi mở app → tự `go(rootScreen)`.
  static const String splash = '/splash';

  /// Tab (branch của `StatefulShellRoute`): Home `/` · Requests · Messages · Account.
  static const String myRequests = '/myRequests';

  /// Offer của một request (đè lên tab; `extra` = `RequestOffersPageArgs`).
  static const String requestOffers = '/requestOffers';

  //-----------------ACCOUNT---------------
  static const String account = '/account';
  static const String lionPoints = '/lionPoints';
  static const String blockedUsers = '/blockedUsers';

  //-----------------CHAT---------------
  static const String messages = '/messages';

  /// Chat 1:1 (`extra` = `ChatPageArgs`).
  static const String chat = '/chat';

  //-----------------POST REQUEST---------------
  /// Màn nói — đè lên mọi tab (root navigator).
  static const String voiceRequest = '/voiceRequest';

  /// "Post a request" (web `/request-assistant`): AI soạn form rồi đăng
  /// (`extra` = `PostRequestFlowArgs`).
  static const String postRequest = '/postRequest';

  /// "Providers for your request" sau khi đăng (web `/buyer/request/matches/{id}`).
  static const String requestMatches = '/request/matches/:id';
  static String requestMatchesPath(int id) => '/request/matches/$id';

  /// Duyệt provider theo nghề (menu / Account; `extra` = `MatchingProvidersPageArgs`).
  static const String matchingProviders = '/request/providers';

  //-----------------ASSISTANT---------------
  /// Chat trợ lý AI (web `/ai-assistant`) — ô nhập ở Home / hero Social Market; đè lên tab.
  /// `extra` = `AssistantPageArgs`.
  static const String assistant = '/assistant';

  //-----------------SOCIAL MARKET---------------
  /// `/socialMarket/:category` (`longevity`, `health-pro-advisory`, `personal-helper`)
  /// + con `services` / `providers` — đè lên tab.
  static const String socialMarket = '/socialMarket';
}
