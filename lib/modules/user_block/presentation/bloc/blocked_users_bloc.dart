import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';
import 'package:strongbody_buyer/core/streams/user_block_event_bus.dart';

import '../../domain/block_action_service.dart';
import '../../domain/entities/blocked_user.dart';
import '../../domain/usecases/get_blocked_users_use_case.dart';

part 'blocked_users_event.dart';
part 'blocked_users_state.dart';

class BlockedUsersBloc
    extends BlocWithApi<BlockedUsersEvent, BlockedUsersState> {
  final GetBlockedUsersUseCase _getBlockedUsers;
  final BlockActionService _blockAction;
  late final StreamSubscription<UserBlockEvent> _sub;

  BlockedUsersBloc({
    required GetBlockedUsersUseCase getBlockedUsers,
    required BlockActionService blockAction,
  }) : _getBlockedUsers = getBlockedUsers,
       _blockAction = blockAction,
       super(const BlockedUsersState()) {
    on<BlockedUsersStarted>(_onStarted);
    on<BlockedUsersUnblockRequested>(_onUnblock);
    on<BlockedUsersRemoved>(_onRemoved);
    // Bỏ chặn ở màn chat → gỡ dòng ở đây.
    _sub = UserBlockEventBus.stream.listen((event) {
      if (event is UserUnblocked && !isClosed) {
        add(BlockedUsersRemoved(event.userId));
      }
    });
  }

  Future<void> _onStarted(
    BlockedUsersStarted event,
    Emitter<BlockedUsersState> emit,
  ) async {
    emit(state.copyWith(status: BlockedUsersStatus.loading));
    await callApi(
      useCase: _getBlockedUsers,
      param: const BlockedUsersParams(page: 1, limit: 50),
      onSuccess: (page) async => emit(
        state.copyWith(status: BlockedUsersStatus.ready, items: page.items),
      ),
      onFailure: (_) =>
          emit(state.copyWith(status: BlockedUsersStatus.failure)),
    );
  }

  Future<void> _onUnblock(
    BlockedUsersUnblockRequested event,
    Emitter<BlockedUsersState> emit,
  ) async {
    emit(state.copyWith(busyUserId: event.user.userId));
    final ok = await _blockAction.unblock(
      userId: event.user.userId,
      blockRecordId: event.user.blockRecordId,
    );
    if (isClosed) return;
    if (ok) {
      emit(
        state.copyWith(
          items: state.items
              .where((u) => u.userId != event.user.userId)
              .toList(),
          clearBusy: true,
        ),
      );
    } else {
      emit(state.copyWith(clearBusy: true, notice: BlockedUsersNotice.unblockFailed));
    }
  }

  void _onRemoved(
    BlockedUsersRemoved event,
    Emitter<BlockedUsersState> emit,
  ) {
    emit(
      state.copyWith(
        items: state.items.where((u) => u.userId != event.userId).toList(),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
