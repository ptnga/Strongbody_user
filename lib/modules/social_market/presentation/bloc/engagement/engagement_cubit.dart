import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/streams/auth_event_bus.dart';

import '../../../domain/entities/market_feed_entities.dart';
import '../../../domain/usecases/social_market_use_cases.dart';

class EngagementCubitState extends Equatable {
  final Map<int, EngagementState> items;

  /// `"id:kind"` đang gọi API.
  final Set<String> pending;

  /// Toggle lỗi → màn hiện toast (đếm để mỗi lần lỗi là một sự kiện mới).
  final int errorCount;

  const EngagementCubitState({
    this.items = const {},
    this.pending = const {},
    this.errorCount = 0,
  });

  EngagementState of(int? id) =>
      id == null ? EngagementState.empty : items[id] ?? EngagementState.empty;

  bool isPending(int? id, EngagementKind kind) =>
      pending.contains('$id:${kind.name}');

  EngagementCubitState copyWith({
    Map<int, EngagementState>? items,
    Set<String>? pending,
    int? errorCount,
  }) => EngagementCubitState(
    items: items ?? this.items,
    pending: pending ?? this.pending,
    errorCount: errorCount ?? this.errorCount,
  );

  @override
  List<Object?> get props => [items, pending, errorCount];
}

/// Like / save + số đếm cho một nhóm card cùng loại — web `EngagementProvider`:
/// nạp summary 1 lần cho cả list, toggle optimistic, lỗi thì trả lại như cũ.
class EngagementCubit extends Cubit<EngagementCubitState> {
  final EngagementTarget target;
  final GetEngagementUseCase _getEngagement;
  final SetEngagementUseCase _setEngagement;
  final GlobalStorage _storage;
  StreamSubscription<AuthEvent>? _auth;
  List<int> _ids = const [];

  EngagementCubit({
    required this.target,
    required GetEngagementUseCase getEngagement,
    required SetEngagementUseCase setEngagement,
    required GlobalStorage storage,
  }) : _getEngagement = getEngagement,
       _setEngagement = setEngagement,
       _storage = storage,
       super(const EngagementCubitState()) {
    // Đăng nhập / đăng xuất → `my_state` (đã thích / đã lưu) đổi theo tài khoản.
    _auth = AuthEventBus.stream.listen((event) {
      if (event is UserLoggedIn || event is UserLoggedOut) _fetch(_ids);
    });
  }

  bool get isLoggedIn => _storage.isLoggedIn;

  /// Nạp số đếm cho [ids] (gộp với các id đã có — listing tải thêm trang).
  Future<void> load(Iterable<int?> ids) async {
    final next = {..._ids, ...ids.nonNulls}.toList();
    final fresh = next.where((id) => !state.items.containsKey(id)).toList();
    _ids = next;
    if (fresh.isNotEmpty) await _fetch(fresh);
  }

  Future<void> _fetch(List<int> ids) async {
    if (ids.isEmpty) return;
    final result = await _getEngagement((target: target, ids: ids));
    if (isClosed) return;
    // Số đếm là phần bổ trợ — lỗi thì im lặng.
    result.fold(
      (_) {},
      (items) => emit(state.copyWith(items: {...state.items, ...items})),
    );
  }

  /// Gọi khi đã đăng nhập (card tự mở popup đăng nhập cho khách).
  Future<void> toggle(int id, EngagementKind kind) async {
    final key = '$id:${kind.name}';
    if (state.pending.contains(key)) return;
    final prev = state.of(id);
    final like = kind == EngagementKind.like;
    final wasOn = like ? prev.liked : prev.saved;
    final delta = wasOn ? -1 : 1;
    final optimistic = like
        ? prev.copyWith(
            liked: !wasOn,
            likes: (prev.likes + delta).clamp(0, 1 << 30),
          )
        : prev.copyWith(
            saved: !wasOn,
            saves: (prev.saves + delta).clamp(0, 1 << 30),
          );
    emit(
      state.copyWith(
        items: {...state.items, id: optimistic},
        pending: {...state.pending, key},
      ),
    );

    final result = await _setEngagement((
      kind: kind,
      target: target,
      targetId: id,
      on: !wasOn,
    ));
    if (isClosed) return;
    final pending = {...state.pending}..remove(key);
    result.fold(
      (_) => emit(
        state.copyWith(
          items: {...state.items, id: prev},
          pending: pending,
          errorCount: state.errorCount + 1,
        ),
      ),
      (count) {
        final current = state.of(id);
        // Đồng bộ số đếm chính xác từ server.
        final synced = count == null
            ? current
            : like
            ? current.copyWith(likes: count)
            : current.copyWith(saves: count);
        emit(
          state.copyWith(items: {...state.items, id: synced}, pending: pending),
        );
      },
    );
  }

  @override
  Future<void> close() async {
    await _auth?.cancel();
    return super.close();
  }
}
