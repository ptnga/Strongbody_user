import '../../domain/entities/blocked_user.dart';

abstract final class BlockedUserDto {
  static BlockedUser toEntity(Map<String, dynamic> json) {
    final first = json['first_name']?.toString().trim() ?? '';
    final last = json['last_name']?.toString().trim() ?? '';
    final name = [first, last].where((part) => part.isNotEmpty).join(' ');

    return BlockedUser(
      blockRecordId: _int(json['id']),
      userId: _int(json['blocked_id']),
      // Tên rỗng thì lấy email; rỗng cả hai vẫn phải có gì đó để hiện.
      fullName: name.isNotEmpty
          ? name
          : (json['email']?.toString() ?? 'User'),
      email: _nullIfEmpty(json['email']),
      avatarUrl: _nullIfEmpty(json['profile_picture']),
      reason: _nullIfEmpty(json['reason']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  static int _int(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  static String? _nullIfEmpty(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
