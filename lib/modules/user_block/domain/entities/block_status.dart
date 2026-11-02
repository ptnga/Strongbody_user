import 'package:equatable/equatable.dart';

/// Quan hệ chặn hai chiều với một người.
class BlockStatus extends Equatable {
  const BlockStatus({required this.isBlocked, required this.isBlockedByThem});

  const BlockStatus.none() : isBlocked = false, isBlockedByThem = false;

  /// Mình đã chặn họ.
  final bool isBlocked;

  /// Họ đã chặn mình.
  final bool isBlockedByThem;

  @override
  List<Object?> get props => [isBlocked, isBlockedByThem];
}
