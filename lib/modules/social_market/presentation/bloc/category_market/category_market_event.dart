part of 'category_market_bloc.dart';

sealed class CategoryMarketEvent extends Equatable {
  const CategoryMarketEvent();

  @override
  List<Object?> get props => [];
}

class CategoryMarketStarted extends CategoryMarketEvent {
  final MarketPageScope scope;

  /// Ngôn ngữ giao diện ("en" / "vi") — section "Care that speaks your language".
  final String language;

  const CategoryMarketStarted(this.scope, {required this.language});

  @override
  List<Object?> get props => [scope.route, language];
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
