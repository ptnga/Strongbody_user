import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';
import 'package:strongbody_buyer/modules/account/domain/usecases/account_use_cases.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/my_request_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/get_my_requests_use_case.dart';

class HomeMenuState extends Equatable {
  final bool loggedIn;

  /// Chủ của [recent] / [points] — đổi tài khoản thì bỏ dữ liệu cũ.
  final int? userId;
  final String? name;

  /// 3 request gần nhất ("Recent" trong menu).
  final List<MyRequestEntity> recent;
  final int? points;

  const HomeMenuState({
    this.loggedIn = false,
    this.userId,
    this.name,
    this.recent = const [],
    this.points,
  });

  @override
  List<Object?> get props => [loggedIn, userId, name, recent, points];
}

/// Menu bên ở Home (prototype): tải request gần nhất + Lion Points khi mở.
class HomeMenuCubit extends Cubit<HomeMenuState> {
  final GetMyRequestsUseCase _getMyRequests;
  final GetLionPointsUseCase _getLionPoints;
  final GlobalStorage _storage;

  HomeMenuCubit({
    required GetMyRequestsUseCase getMyRequests,
    required GetLionPointsUseCase getLionPoints,
    required GlobalStorage storage,
  }) : _getMyRequests = getMyRequests,
       _getLionPoints = getLionPoints,
       _storage = storage,
       super(const HomeMenuState());

  Future<void> load() async {
    final userId = _storage.userId;
    if (!_storage.isLoggedIn || userId == null) {
      emit(const HomeMenuState());
      return;
    }
    // Tab Home được giữ sống: chỉ dùng lại dữ liệu cũ nếu cùng tài khoản.
    final previous = state.userId == userId ? state : const HomeMenuState();
    emit(
      HomeMenuState(
        loggedIn: true,
        userId: userId,
        name: _storage.userName,
        recent: previous.recent,
        points: previous.points,
      ),
    );
    final requests = _getMyRequests(
      GetMyRequestsParams(userId: userId, page: 1, limit: 3),
    );
    final points = _getLionPoints(const NoParams());
    final recent = (await requests).fold(
      (_) => state.recent,
      (page) => page.items.take(3).toList(),
    );
    final wallet = (await points).fold((_) => null, (r) => r.wallet.points);
    if (isClosed || _storage.userId != userId) return;
    emit(
      HomeMenuState(
        loggedIn: true,
        userId: userId,
        name: _storage.userName,
        recent: recent,
        points: wallet ?? state.points,
      ),
    );
  }
}
