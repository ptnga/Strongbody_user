import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../../../domain/entities/conversation_entity.dart';
import '../../../domain/repositories/chat_connection.dart';
import '../../../domain/usecases/chat_use_cases.dart';
import '../../chat_badge_notifier.dart';

part 'conversations_event.dart';
part 'conversations_state.dart';

/// Tab Messages — Multime `ConversationsBloc`: `GET /user/chat-server/conversations`
/// (10/trang) + upsert realtime từ `user_{me}_updates`, sắp theo tin mới nhất.
class ConversationsBloc
    extends BlocWithApi<ConversationsEvent, ConversationsState> {
  final GetConversationsUseCase _getConversations;
  final SearchChatUsersUseCase _searchUsers;
  final ConnectChatUpdatesUseCase _connectUpdates;
  final ChatBadgeNotifier _badge;
  final GlobalStorage _storage;

  ChatUpdatesConnection? _updates;
  StreamSubscription<ConversationUpdate>? _updatesSub;
  Timer? _searchDebounce;

  ConversationsBloc({
    required GetConversationsUseCase getConversations,
    required SearchChatUsersUseCase searchUsers,
    required ConnectChatUpdatesUseCase connectUpdates,
    required ChatBadgeNotifier badge,
    required GlobalStorage storage,
  }) : _getConversations = getConversations,
       _searchUsers = searchUsers,
       _connectUpdates = connectUpdates,
       _badge = badge,
       _storage = storage,
       super(const ConversationsState()) {
    on<ConversationsStarted>(_onStarted);
    on<ConversationsLoadMore>(_onLoadMore);
    on<ConversationsQueryChanged>(_onQueryChanged);
    on<_ConversationsSearchRequested>(_onSearch);
    on<_ConversationsUpdated>(_onUpdated);
  }

  Future<void> _onStarted(
    ConversationsStarted event,
    Emitter<ConversationsState> emit,
  ) async {
    if (!_storage.isLoggedIn) {
      emit(state.copyWith(status: ConversationsStatus.signedOut));
      return;
    }
    if (state.items.isEmpty) {
      emit(state.copyWith(status: ConversationsStatus.loading));
    }
    _badge.refresh();
    await Future.wait([_load(emit, 1), _listenUpdates()]);
  }

  Future<void> _onLoadMore(
    ConversationsLoadMore event,
    Emitter<ConversationsState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));
    await _load(emit, state.page + 1);
  }

  Future<void> _load(Emitter<ConversationsState> emit, int page) => callApi(
    useCase: _getConversations,
    param: page,
    onSuccess: (result) async {
      final merged = page == 1
          ? result.items
          : [...state.items, ...result.items];
      // Trang sau có thể trùng dòng đã đẩy lên đầu nhờ realtime.
      final seen = <String>{};
      emit(
        state.copyWith(
          status: ConversationsStatus.success,
          items: merged.where((c) => seen.add(c.channelId)).toList(),
          page: page,
          hasMore: result.hasMore,
          isLoadingMore: false,
        ),
      );
    },
    onFailure: (_) => emit(
      state.copyWith(
        status: page == 1 && state.items.isEmpty
            ? ConversationsStatus.failure
            : null,
        isLoadingMore: false,
      ),
    ),
  );

  Future<void> _listenUpdates() async {
    if (_updates != null) return;
    final result = await _connectUpdates(const NoParams());
    result.fold((_) {}, (connection) {
      if (isClosed) {
        connection.dispose();
        return;
      }
      _updates = connection;
      _updatesSub = connection.updates.listen(
        (update) => add(_ConversationsUpdated(update)),
      );
    });
  }

  void _onUpdated(
    _ConversationsUpdated event,
    Emitter<ConversationsState> emit,
  ) {
    switch (event.update) {
      case UnreadChanged():
        _badge.refresh();
      case ConversationChanged(:final conversation):
        final items = [...state.items];
        final index = items.indexWhere(
          (c) => c.channelId == conversation.channelId,
        );
        if (index >= 0) {
          // Giữ ảnh cũ nếu bản cập nhật thiếu.
          items[index] = conversation.copyWith(
            partnerAvatar:
                conversation.partnerAvatar ?? items[index].partnerAvatar,
          );
        } else {
          items.add(conversation);
        }
        items.sort((a, b) => b.lastTimetoken.compareTo(a.lastTimetoken));
        emit(state.copyWith(items: items));
        _badge.refresh();
    }
  }

  void _onQueryChanged(
    ConversationsQueryChanged event,
    Emitter<ConversationsState> emit,
  ) {
    final query = event.query.trim();
    emit(
      state.copyWith(
        query: event.query,
        people: query.length < 2 ? const [] : null,
        isSearching: query.length >= 2,
      ),
    );
    _searchDebounce?.cancel();
    if (query.length < 2) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => add(_ConversationsSearchRequested(query)),
    );
  }

  Future<void> _onSearch(
    _ConversationsSearchRequested event,
    Emitter<ConversationsState> emit,
  ) => callApi(
    useCase: _searchUsers,
    param: event.query,
    onSuccess: (people) async {
      if (state.query.trim() != event.query) return;
      emit(state.copyWith(people: people, isSearching: false));
    },
    onFailure: (_) => emit(state.copyWith(isSearching: false)),
  );

  @override
  Future<void> close() async {
    _searchDebounce?.cancel();
    await _updatesSub?.cancel();
    await _updates?.dispose();
    return super.close();
  }
}
