import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/streams/auth_event_bus.dart';
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

  /// Đang mở socket — `Started` chạy chồng (tab mở lại, kéo làm mới) dùng chung.
  Future<void>? _connecting;
  Timer? _reconnectTimer;
  Timer? _searchDebounce;
  late final StreamSubscription<AuthEvent> _auth;

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
    on<_ConversationsBackfillRequested>(_onBackfill);
    // Tab Messages được giữ sống: đổi tài khoản → bỏ dữ liệu + socket của người cũ.
    _auth = AuthEventBus.stream.listen((event) {
      if (event is UserProfileUpdated || isClosed) return;
      unawaited(_disconnect());
      add(const ConversationsStarted());
    });
  }

  Future<void> _onStarted(
    ConversationsStarted event,
    Emitter<ConversationsState> emit,
  ) async {
    if (!_storage.isLoggedIn) {
      await _disconnect();
      emit(const ConversationsState(status: ConversationsStatus.signedOut));
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

  Future<void> _listenUpdates() {
    if (_updates != null) return Future.value();
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    final result = await _connectUpdates(const NoParams());
    result.fold((_) {}, (connection) {
      if (isClosed || !_storage.isLoggedIn) {
        connection.dispose();
        return;
      }
      _updates = connection;
      _updatesSub = connection.updates.listen(
        (update) => add(_ConversationsUpdated(update)),
      );
    });
  }

  Future<void> _disconnect() async {
    _reconnectTimer?.cancel();
    final sub = _updatesSub;
    final connection = _updates;
    _updatesSub = null;
    _updates = null;
    await sub?.cancel();
    await connection?.dispose();
  }

  void _onUpdated(
    _ConversationsUpdated event,
    Emitter<ConversationsState> emit,
  ) {
    switch (event.update) {
      case UpdatesAccessDenied():
        // Token socket hết hạn: lấy token mới, thử lại sau một lúc (không lặp dồn).
        unawaited(_disconnect());
        _reconnectTimer = Timer(const Duration(seconds: 10), () {
          if (!isClosed && _storage.isLoggedIn) unawaited(_listenUpdates());
        });
      case UnreadChanged(:final total):
        // Web: `global_unread_update` mang sẵn `total_unread_count`.
        if (total != null) {
          _badge.value = total;
        } else {
          _badge.refresh();
        }
      case ConversationChanged(:final conversation):
        final items = [...state.items];
        final index = items.indexWhere(
          (c) => c.channelId == conversation.channelId,
        );
        if (index >= 0) {
          // Giữ ảnh / tên cũ nếu bản cập nhật thiếu.
          items[index] = conversation.copyWith(
            partnerAvatar:
                conversation.partnerAvatar ?? items[index].partnerAvatar,
            partnerName: conversation.partnerName.isEmpty
                ? items[index].partnerName
                : null,
          );
        } else {
          items.add(conversation);
          // Sự kiện realtime không kèm tên / ảnh partner → lấy lại từ REST (web
          // `backfillPartner`).
          if (conversation.partnerName.isEmpty ||
              conversation.partnerAvatar == null) {
            add(_ConversationsBackfillRequested(conversation.channelId));
          }
        }
        items.sort((a, b) => b.lastTimetoken.compareTo(a.lastTimetoken));
        emit(state.copyWith(items: items));
        _badge.refresh();
    }
  }

  Future<void> _onBackfill(
    _ConversationsBackfillRequested event,
    Emitter<ConversationsState> emit,
  ) => callApi(
    useCase: _getConversations,
    param: 1,
    onSuccess: (result) async {
      final fresh = result.items
          .where((c) => c.channelId == event.channelId)
          .firstOrNull;
      if (fresh == null) return;
      emit(
        state.copyWith(
          items: [
            for (final c in state.items)
              c.channelId == event.channelId
                  ? c.copyWith(
                      partnerName: fresh.partnerName.isEmpty
                          ? null
                          : fresh.partnerName,
                      partnerAvatar: fresh.partnerAvatar,
                    )
                  : c,
          ],
        ),
      );
    },
    onFailure: (_) {},
  );

  void _onQueryChanged(
    ConversationsQueryChanged event,
    Emitter<ConversationsState> emit,
  ) {
    // Web `MessageHeader`: tìm người với mọi chuỗi khác rỗng, debounce 500 ms.
    final query = event.query.trim();
    emit(
      state.copyWith(
        query: event.query,
        people: query.isEmpty ? const [] : null,
        isSearching: query.isNotEmpty,
      ),
    );
    _searchDebounce?.cancel();
    if (query.isEmpty) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 500),
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
    await _auth.cancel();
    await _disconnect();
    return super.close();
  }
}
