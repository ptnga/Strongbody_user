import 'package:equatable/equatable.dart';

/// Một dòng trong danh sách "đã chặn".
class BlockedUser extends Equatable {
  const BlockedUser({
    required this.blockRecordId,
    required this.userId,
    required this.fullName,
    this.email,
    this.avatarUrl,
    this.reason,
    this.createdAt,
  });

  /// `id` của item — id bản ghi block, dùng để bỏ chặn.
  final int blockRecordId;

  /// `blocked_id` — id người bị chặn.
  final int userId;

  final String fullName;
  final String? email;
  final String? avatarUrl;
  final String? reason;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [blockRecordId, userId, fullName, avatarUrl];
}
