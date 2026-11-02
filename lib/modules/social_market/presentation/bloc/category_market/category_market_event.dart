part of 'category_market_bloc.dart';

sealed class CategoryMarketEvent extends Equatable {
  const CategoryMarketEvent();

  @override
  List<Object?> get props => [];
}

class CategoryMarketStarted extends CategoryMarketEvent {
  final MarketCategory category;

  const CategoryMarketStarted(this.category);

  @override
  List<Object?> get props => [category];
}

/// Kéo để làm mới.
class CategoryMarketRefreshed extends CategoryMarketEvent {
  const CategoryMarketRefreshed();
}

/// "Try again" ở khối lỗi của một mục.
class CategoryMarketSectionRetried extends CategoryMarketEvent {
  final MarketSectionKind section;

  const CategoryMarketSectionRetried(this.section);

  @override
  List<Object?> get props => [section];
}
