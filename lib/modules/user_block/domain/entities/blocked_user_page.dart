import 'package:equatable/equatable.dart';

import 'blocked_user.dart';

class BlockedUserPage extends Equatable {
  const BlockedUserPage({
    required this.items,
    required this.total,
    required this.totalPage,
    required this.currentPage,
    required this.limit,
  });

  const BlockedUserPage.empty()
    : items = const [],
      total = 0,
      totalPage = 0,
      currentPage = 1,
      limit = 20;

  final List<BlockedUser> items;
  final int total;
  final int totalPage;
  final int currentPage;
  final int limit;

  bool get hasMore => currentPage < totalPage;

  @override
  List<Object?> get props => [items, total, totalPage, currentPage, limit];
}
