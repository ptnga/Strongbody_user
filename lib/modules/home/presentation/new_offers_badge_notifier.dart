import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/streams/auth_event_bus.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../domain/usecases/get_new_offers_count_use_case.dart';

/// Badge tab Requests = số offer mới (cùng số với pill "N new offers" ở Home).
/// Singleton: tải khi đăng nhập và mỗi lần thanh dưới hiện; đăng xuất → 0.
class NewOffersBadgeNotifier extends ValueNotifier<int> {
  final GetNewOffersCountUseCase _getCount;
  final GlobalStorage _storage;
  late final StreamSubscription<AuthEvent> _auth;
  Timer? _debounce;

  NewOffersBadgeNotifier({
    required GetNewOffersCountUseCase getCount,
    required GlobalStorage storage,
  }) : _getCount = getCount,
       _storage = storage,
       super(0) {
    _auth = AuthEventBus.stream.listen((event) {
      if (event is UserLoggedOut) {
        value = 0;
      } else {
        refresh();
      }
    });
  }

  void refresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    if (!_storage.isLoggedIn) {
      value = 0;
      return;
    }
    final userId = _storage.userId;
    final result = await _getCount(const NoParams());
    // Đăng xuất / đổi tài khoản trong lúc chờ → không ghi số của người cũ.
    if (!_storage.isLoggedIn || _storage.userId != userId) return;
    result.fold((_) {}, (count) => value = count);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _auth.cancel();
    super.dispose();
  }
}
