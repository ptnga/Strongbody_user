part of 'blocked_users_bloc.dart';

enum BlockedUsersStatus { loading, ready, failure }

enum BlockedUsersNotice { unblockFailed }

class BlockedUsersState extends Equatable {
  final BlockedUsersStatus status;
  final List<BlockedUser> items;

  /// Id người đang được bỏ chặn (hiện spinner trên dòng đó).
  final int? busyUserId;
  final BlockedUsersNotice? notice;
  final int noticeId;

  const BlockedUsersState({
    this.status = BlockedUsersStatus.loading,
    this.items = const [],
    this.busyUserId,
    this.notice,
    this.noticeId = 0,
  });

  BlockedUsersState copyWith({
    BlockedUsersStatus? status,
    List<BlockedUser>? items,
    int? busyUserId,
    bool clearBusy = false,
    BlockedUsersNotice? notice,
  }) {
    return BlockedUsersState(
      status: status ?? this.status,
      items: items ?? this.items,
      busyUserId: clearBusy ? null : (busyUserId ?? this.busyUserId),
      notice: notice ?? this.notice,
      noticeId: notice != null ? noticeId + 1 : noticeId,
    );
  }

  @override
  List<Object?> get props => [status, items, busyUserId, notice, noticeId];
}
