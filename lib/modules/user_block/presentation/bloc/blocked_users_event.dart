part of 'blocked_users_bloc.dart';

sealed class BlockedUsersEvent extends Equatable {
  const BlockedUsersEvent();

  @override
  List<Object?> get props => [];
}

final class BlockedUsersStarted extends BlockedUsersEvent {
  const BlockedUsersStarted();
}

final class BlockedUsersUnblockRequested extends BlockedUsersEvent {
  final BlockedUser user;

  const BlockedUsersUnblockRequested(this.user);

  @override
  List<Object?> get props => [user];
}

final class BlockedUsersRemoved extends BlockedUsersEvent {
  final int userId;

  const BlockedUsersRemoved(this.userId);

  @override
  List<Object?> get props => [userId];
}
