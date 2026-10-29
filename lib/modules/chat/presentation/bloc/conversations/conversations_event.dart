part of 'conversations_bloc.dart';

sealed class ConversationsEvent extends Equatable {
  const ConversationsEvent();

  @override
  List<Object?> get props => [];
}

/// Tải trang đầu + nghe `user_{me}_updates` (cũng dùng cho kéo để làm mới).
final class ConversationsStarted extends ConversationsEvent {
  const ConversationsStarted();
}

final class ConversationsLoadMore extends ConversationsEvent {
  const ConversationsLoadMore();
}

/// Ô "Search providers": lọc hội thoại + tìm người mới (debounce).
final class ConversationsQueryChanged extends ConversationsEvent {
  final String query;

  const ConversationsQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

final class _ConversationsSearchRequested extends ConversationsEvent {
  final String query;

  const _ConversationsSearchRequested(this.query);

  @override
  List<Object?> get props => [query];
}

final class _ConversationsUpdated extends ConversationsEvent {
  final ConversationUpdate update;

  const _ConversationsUpdated(this.update);

  @override
  List<Object?> get props => [update];
}
