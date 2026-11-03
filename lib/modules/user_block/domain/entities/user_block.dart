import 'package:equatable/equatable.dart';

/// Kết quả của một lần chặn.
class UserBlock extends Equatable {
  const UserBlock({
    required this.blockRecordId,
    required this.blockerId,
    required this.blockedId,
    this.createdAt,
  });

  /// Field `id` của API — **id bản ghi block**, không phải user id.
  /// DELETE `/user_blocks/{id}` nhận đúng giá trị này.
  final int blockRecordId;

  final int blockerId;
  final int blockedId;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [blockRecordId, blockerId, blockedId, createdAt];
}
