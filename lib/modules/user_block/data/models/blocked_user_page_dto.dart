import '../../domain/entities/blocked_user.dart';
import '../../domain/entities/blocked_user_page.dart';
import 'blocked_user_dto.dart';

abstract final class BlockedUserPageDto {
  static BlockedUserPage toEntity(Map<String, dynamic> json) {
    final rawItems = json['data'] ?? json['list'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) =>
                    BlockedUserDto.toEntity(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false)
        : const <BlockedUser>[];

    return BlockedUserPage(
      items: items,
      total: _int(json['total']),
      totalPage: _int(json['total_page']),
      currentPage: _int(json['current_page'], fallback: 1),
      limit: _int(json['limit'], fallback: 20),
    );
  }

  static int _int(Object? value, {int fallback = 0}) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;
}
