import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/streams/auth_event_bus.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../domain/usecases/chat_use_cases.dart';

/// Badge tab Messages = `total_unread_count` (Multime `ApplicationBloc`). Singleton:
/// tải khi đăng nhập / mở Messages / đọc tin; đăng xuất → 0.
class ChatBadgeNotifier extends ValueNotifier<int> {
  final GetChatUnreadTotalUseCase _getUnreadTotal;
  final GlobalStorage _storage;
  late final StreamSubscription<AuthEvent> _auth;
  Timer? _debounce;

  ChatBadgeNotifier({
    required GetChatUnreadTotalUseCase getUnreadTotal,
    required GlobalStorage storage,
  }) : _getUnreadTotal = getUnreadTotal,
       _storage = storage,
       super(0) {
    _auth = AuthEventBus.stream.listen((event) {
      if (event is UserLoggedOut) {
        value = 0;
      } else {
        refresh();
      }
    });
    refresh();
  }

  /// Gom nhiều lần gọi liên tiếp (400 ms như Multime).
  void refresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    if (!_storage.isLoggedIn) {
      value = 0;
      return;
    }
    final result = await _getUnreadTotal(const NoParams());
    result.fold((_) {}, (total) => value = total);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _auth.cancel();
    super.dispose();
  }
}
