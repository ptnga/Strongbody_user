class HomeApiConfig {
  HomeApiConfig._();

  /// Offer seller gửi cho các request của buyer (web: `getOffers(token, params, 'buyer')`).
  /// `status=pending&source=request,chat` (tab "Pending" của web Received offers) =
  /// offer mới chưa xử lý → số trên pill "N new offers" / badge tab Requests.
  static const String sentOffersByMyRequests =
      '/buyer/offer/sent-offers-by-my-requests';
}
