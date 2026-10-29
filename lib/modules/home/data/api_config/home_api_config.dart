class HomeApiConfig {
  HomeApiConfig._();

  /// Offer seller gửi cho các request của buyer (web: `getOffers(token, params, 'buyer')`).
  /// `status=pending` = offer mới chưa xử lý → số trên pill "N new offers".
  static const String sentOffersByMyRequests =
      '/buyer/offer/sent-offers-by-my-requests';
}
