part of 'market_listing_bloc.dart';

sealed class MarketListingEvent extends Equatable {
  const MarketListingEvent();

  @override
  List<Object?> get props => [];
}

class MarketListingStarted extends MarketListingEvent {
  const MarketListingStarted();
}

class MarketListingRefreshed extends MarketListingEvent {
  const MarketListingRefreshed();
}

/// Chọn tab service classification ([filter] = slug; null = "All").
class MarketListingFilterChanged extends MarketListingEvent {
  final String? filter;

  const MarketListingFilterChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}

/// Cuộn gần cuối (tự động) hoặc bấm "Try again" sau lỗi (`retry`).
class MarketListingNextPageRequested extends MarketListingEvent {
  final bool retry;

  const MarketListingNextPageRequested({this.retry = false});

  @override
  List<Object?> get props => [retry];
}
