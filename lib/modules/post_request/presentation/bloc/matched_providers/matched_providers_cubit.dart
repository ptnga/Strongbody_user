import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/my_request_entity.dart';
import '../../../domain/usecases/get_matched_providers_use_case.dart';

enum MatchedProvidersStatus { initial, loading, success, failure }

class MatchedProvidersState extends Equatable {
  final MatchedProvidersStatus status;
  final List<MatchedProviderEntity> items;
  final int total;

  /// Trang đã tải (0 = chưa tải).
  final int page;

  const MatchedProvidersState({
    this.status = MatchedProvidersStatus.initial,
    this.items = const [],
    this.total = 0,
    this.page = 0,
  });

  bool get isFirstLoad =>
      page == 0 &&
      (status == MatchedProvidersStatus.initial ||
          status == MatchedProvidersStatus.loading);

  bool get hasMore =>
      status == MatchedProvidersStatus.success && items.length < total;

  MatchedProvidersState copyWith({
    MatchedProvidersStatus? status,
    List<MatchedProviderEntity>? items,
    int? total,
    int? page,
  }) => MatchedProvidersState(
    status: status ?? this.status,
    items: items ?? this.items,
    total: total ?? this.total,
    page: page ?? this.page,
  );

  @override
  List<Object?> get props => [status, items, total, page];
}

/// Chuyên gia request đã được gửi thẳng tới (web `MatchedProviders`): chỉ tải lần đầu mở,
/// "Show more" tải trang kế (20 / trang); lỗi → "Try again" tải lại trang kế.
class MatchedProvidersCubit extends Cubit<MatchedProvidersState> {
  final GetMatchedProvidersUseCase _getMatched;

  static const pageSize = 20;

  MatchedProvidersCubit(this._getMatched)
    : super(const MatchedProvidersState());

  int? _requestId;

  /// Lần đầu mở danh sách (gọi lại khi đã tải thì bỏ qua).
  Future<void> open(int requestId) async {
    if (_requestId == requestId && state.page > 0) return;
    if (state.status == MatchedProvidersStatus.loading) return;
    _requestId = requestId;
    await _load(1);
  }

  /// "Show more" / "Try again": trang kế.
  Future<void> loadMore() async {
    if (_requestId == null || state.status == MatchedProvidersStatus.loading) {
      return;
    }
    await _load(state.page + 1);
  }

  Future<void> _load(int page) async {
    emit(state.copyWith(status: MatchedProvidersStatus.loading));
    final result = await _getMatched(
      GetMatchedProvidersParams(
        requestId: _requestId!,
        page: page,
        limit: pageSize,
      ),
    );
    if (isClosed) return;
    result.match(
      (_) => emit(state.copyWith(status: MatchedProvidersStatus.failure)),
      (res) => emit(
        state.copyWith(
          status: MatchedProvidersStatus.success,
          items: page == 1 ? res.items : [...state.items, ...res.items],
          total: res.total,
          page: page,
        ),
      ),
    );
  }
}
