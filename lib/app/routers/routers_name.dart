class RouteName {
  RouteName._();

  static const String rootScreen = '/';

  /// Con của `/` → mở từ bất kỳ đâu bằng `go` vẫn có Home phía dưới.
  static const String myRequests = '/myRequests';

  /// Offer của một request (con của My requests; `extra` = `RequestOffersPageArgs`).
  static const String requestOffers = '/myRequests/offers';

  //-----------------ACCOUNT---------------
  /// Tab Account (con của `/`).
  static const String account = '/account';
  static const String lionPoints = '/account/lionPoints';

  //-----------------CHAT---------------
  /// Tab Messages (con của `/`, giống My requests).
  static const String messages = '/messages';

  /// Chat 1:1 (`extra` = `ChatPageArgs`).
  static const String chat = '/chat';

  //-----------------POST REQUEST---------------
  /// Con của `/` → `go` từ trong luồng post request (ShellRoute) vẫn có Home phía dưới.
  static const String voiceRequest = '/voiceRequest';

  /// Các màn trong ShellRoute dùng chung `PostRequestFlowBloc`.
  static const String requestHeard = '/request/heard';
  static const String requestReview = '/request/review';
  static const String matchingProviders = '/request/providers';

  static const String requestPosted = '/requestPosted';
}
