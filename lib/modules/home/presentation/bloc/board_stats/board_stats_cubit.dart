import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../../../domain/entities/board_entities.dart';
import '../../../domain/usecases/home_board_use_cases.dart';

enum BoardStatsStatus { initial, loading, success, failure }

class BoardStatsState extends Equatable {
  final BoardStatsStatus status;

  /// null = chưa tải / API lỗi (bỏ hàng số liệu, không chen "Recently matched").
  final BoardStats? stats;

  const BoardStatsState({this.status = BoardStatsStatus.initial, this.stats});

  bool get isFirstLoad =>
      status == BoardStatsStatus.initial || status == BoardStatsStatus.loading;

  BoardStatsState copyWith({BoardStatsStatus? status, BoardStats? stats}) =>
      BoardStatsState(
        status: status ?? this.status,
        stats: stats ?? this.stats,
      );

  @override
  List<Object?> get props => [status, stats];
}

/// Số liệu tuần này + "Recently matched" của bảng Requests trang chủ (web
/// `getPublicRequestBoardStats` trong `HomeRequestsLoader`). Lỗi → giữ `stats` null.
class BoardStatsCubit extends Cubit<BoardStatsState> {
  final GetBoardStatsUseCase _getStats;

  BoardStatsCubit(this._getStats) : super(const BoardStatsState());

  Future<void> load() async {
    emit(state.copyWith(status: BoardStatsStatus.loading));
    final result = await _getStats(const NoParams());
    if (isClosed) return;
    result.match(
      (_) => emit(state.copyWith(status: BoardStatsStatus.failure)),
      (stats) =>
          emit(state.copyWith(status: BoardStatsStatus.success, stats: stats)),
    );
  }
}
