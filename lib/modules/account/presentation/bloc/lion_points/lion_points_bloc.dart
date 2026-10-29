import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../../../domain/entities/account_entities.dart';
import '../../../domain/usecases/account_use_cases.dart';

part 'lion_points_event.dart';
part 'lion_points_state.dart';

/// "History" của Lion Points — web `/buyer/lion-point/history` (ví → ledger, 20/trang).
class LionPointsBloc extends BlocWithApi<LionPointsEvent, LionPointsState> {
  final GetLionPointsUseCase _getLionPoints;
  final GetLionLedgerUseCase _getLedger;

  LionPointsBloc({
    required GetLionPointsUseCase getLionPoints,
    required GetLionLedgerUseCase getLedger,
  }) : _getLionPoints = getLionPoints,
       _getLedger = getLedger,
       super(const LionPointsState()) {
    on<LionPointsStarted>(_onStarted);
    on<LionPointsLoadMore>(_onLoadMore);
  }

  Future<void> _onStarted(
    LionPointsStarted event,
    Emitter<LionPointsState> emit,
  ) async {
    await callApi(
      useCase: _getLionPoints,
      param: const NoParams(),
      onSuccess: (result) async {
        emit(state.copyWith(wallet: result.wallet));
        await _load(emit, 1);
      },
      onFailure: (_) => emit(state.copyWith(status: LionPointsStatus.failure)),
    );
  }

  Future<void> _onLoadMore(
    LionPointsLoadMore event,
    Emitter<LionPointsState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore || state.wallet == null) return;
    emit(state.copyWith(isLoadingMore: true));
    await _load(emit, state.page + 1);
  }

  Future<void> _load(Emitter<LionPointsState> emit, int page) => callApi(
    useCase: _getLedger,
    param: (walletId: state.wallet!.id, page: page),
    onSuccess: (result) async => emit(
      state.copyWith(
        status: LionPointsStatus.success,
        items: page == 1 ? result.items : [...state.items, ...result.items],
        page: page,
        hasMore: result.hasMore,
        isLoadingMore: false,
      ),
    ),
    onFailure: (_) => emit(
      state.copyWith(
        status: page == 1 ? LionPointsStatus.failure : null,
        isLoadingMore: false,
      ),
    ),
  );
}
