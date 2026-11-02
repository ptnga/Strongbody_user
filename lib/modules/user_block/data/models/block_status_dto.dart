import '../../domain/entities/block_status.dart';

abstract final class BlockStatusDto {
  static BlockStatus toEntity(Map<String, dynamic> json) => BlockStatus(
    isBlocked: _bool(json['is_blocked']),
    isBlockedByThem: _bool(json['is_blocked_by_them']),
  );

  static bool _bool(Object? value) =>
      value is bool ? value : value?.toString().toLowerCase() == 'true';
}
