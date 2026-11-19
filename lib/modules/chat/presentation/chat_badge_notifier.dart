import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/streams/auth_event_bus.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../domain/usecases/chat_use_cases.dart';

/// Badge tab Messages = `total_unread_count` (Multime `ApplicationBloc`). Singleton:
/// tải khi đăng nhập / mở Messages / đọc tin; đăng xuất → 0.
///
/// [pollInterval]: như web `MessagesBadge` (SWR `refreshInterval: 10000`) — tải lại định
/// kỳ khi đã đăng nhập và app đang mở, để badge có tin mới cả khi chưa mở Messages.
class ChatBadgeNotifier extends ValueNotifier<int> {
  /// Chu kỳ tải lại của web `MessagesBadge`.
  static const webPollInterval = Duration(seconds: 10);

  final GetChatUnreadTotalUseCase _getUnreadTotal;
  final GlobalStorage _storage;
  late final StreamSubscription<AuthEvent> _auth;
  Timer? _debounce;
  Timer? _poll;

  ChatBadgeNotifier({
    required GetChatUnreadTotalUseCase getUnreadTotal,
    required GlobalStorage storage,
    Duration? pollInterval,
  }) : _getUnreadTotal = getUnreadTotal,
       _storage = storage,
       super(0) {
    if (pollInterval != null) {
      _poll = Timer.periodic(pollInterval, (_) => _onPoll());
    }
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

  void _onPoll() {
    if (!_storage.isLoggedIn) return;
    // App ở nền: không gọi API (tải lại khi mở Messages / đổi tab).
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    _load();
  }

  Future<void> _load() async {
    if (!_storage.isLoggedIn) {
      value = 0;
      return;
    }
    final userId = _storage.userId;
    final result = await _getUnreadTotal(const NoParams());
    // Đăng xuất / đổi tài khoản trong lúc chờ → không ghi số của người cũ.
    if (!_storage.isLoggedIn || _storage.userId != userId) return;
    result.fold((_) {}, (total) => value = total);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _poll?.cancel();
    _auth.cancel();
    super.dispose();
  }
}
