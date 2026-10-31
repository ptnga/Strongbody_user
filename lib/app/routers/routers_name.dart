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

  //-----------------CHAT---------------
  static const String messages = '/messages';

  /// Chat 1:1 (`extra` = `ChatPageArgs`).
  static const String chat = '/chat';

  //-----------------POST REQUEST---------------
  /// Màn nói — đè lên mọi tab (root navigator).
  static const String voiceRequest = '/voiceRequest';

  /// Các màn trong ShellRoute dùng chung `PostRequestFlowBloc`.
  static const String requestHeard = '/request/heard';
  static const String requestReview = '/request/review';
  static const String matchingProviders = '/request/providers';

  static const String requestPosted = '/requestPosted';

  //-----------------SOCIAL MARKET---------------
  /// `/socialMarket/:category` (`longevity`, `health-pro-advisory`, `personal-helper`)
  /// + con `services` / `providers` — đè lên tab.
  static const String socialMarket = '/socialMarket';
}
