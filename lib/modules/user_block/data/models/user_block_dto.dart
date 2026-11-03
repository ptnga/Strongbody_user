import '../../domain/entities/user_block.dart';

abstract final class UserBlockDto {
  static UserBlock toEntity(Map<String, dynamic> json) => UserBlock(
    // `id` ở response Block là id BẢN GHI, `blocked_id` mới là user.
    blockRecordId: _int(json['id']),
    blockerId: _int(json['blocker_id']),
    blockedId: _int(json['blocked_id']),
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
  );

  static int _int(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}
