import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/storages/global_storage.dart';
import '../network/api.dart';
import '../network/api_type.dart';
import '../streams/auth_event_bus.dart';
import '../utils/app_logger.dart';

/// Báo BE người mua vừa dùng app — web `BuyerLastVisitTracker` (`components/providers`):
/// đã đăng nhập thì mỗi lần đổi trang gọi `POST /v1/buyer/auth/last-visit`, lỗi bỏ qua.
///
/// App gọi khi mở app, đăng nhập, quay lại app (resume) và đổi tab; giãn tối thiểu
/// [minInterval] để chuyển tab liên tục không bắn hàng loạt request.
class LastVisitService {
  final ApiClient _api;
  final GlobalStorage _storage;
  final DateTime Function() _now;

  static const path = '/buyer/auth/last-visit';
  static const minInterval = Duration(minutes: 1);

  DateTime? _lastSent;
  StreamSubscription<AuthEvent>? _auth;
  AppLifecycleListener? _lifecycle;

  LastVisitService(this._api, this._storage, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Nghe đăng nhập / resume và báo lượt đầu. Gọi một lần sau frame đầu.
  void start() {
    _auth ??= AuthEventBus.stream.listen((event) {
      switch (event) {
        case UserLoggedIn():
          touch(force: true);
        case UserLoggedOut():
          _lastSent = null;
        case UserProfileUpdated():
          break;
      }
    });
    _lifecycle ??= AppLifecycleListener(onResume: touch);
    touch();
  }

  /// Gửi last-visit nếu đã đăng nhập và lần trước đã cách [minInterval] (hoặc [force]).
  Future<void> touch({bool force = false}) async {
    if (!_storage.isLoggedIn) return;
    final now = _now();
    final last = _lastSent;
    if (!force && last != null && now.difference(last) < minInterval) return;
    _lastSent = now;
    try {
      await _api.request(
        path: path,
        method: ApiType.post,
        headers: const {'Accept': 'application/json'},
      );
    } catch (e) {
      AppLogger.w('Update buyer last visit failed', e);
    }
  }

  void dispose() {
    _auth?.cancel();
    _auth = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}
