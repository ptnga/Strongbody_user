part of 'my_requests_bloc.dart';

sealed class MyRequestsEvent extends Equatable {
  const MyRequestsEvent();

  @override
  List<Object?> get props => [];
}

/// Tải trang đầu (cũng dùng cho kéo để làm mới).
final class MyRequestsStarted extends MyRequestsEvent {
  const MyRequestsStarted();
}

final class MyRequestsLoadMore extends MyRequestsEvent {
  const MyRequestsLoadMore();
}

/// Đổi tab Active / Closed.
final class MyRequestsTabChanged extends MyRequestsEvent {
  final MyRequestsTab tab;

  const MyRequestsTabChanged(this.tab);

  @override
  List<Object?> get props => [tab];
}
