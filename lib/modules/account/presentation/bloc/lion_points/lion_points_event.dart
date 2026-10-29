part of 'lion_points_bloc.dart';

sealed class LionPointsEvent extends Equatable {
  const LionPointsEvent();

  @override
  List<Object?> get props => [];
}

final class LionPointsStarted extends LionPointsEvent {
  const LionPointsStarted();
}

final class LionPointsLoadMore extends LionPointsEvent {
  const LionPointsLoadMore();
}
