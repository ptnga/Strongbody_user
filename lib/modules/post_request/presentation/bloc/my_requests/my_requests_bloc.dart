import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';

import '../../../domain/entities/my_request_entity.dart';
import '../../../domain/usecases/get_my_requests_use_case.dart';
import '../../../domain/usecases/get_request_offers_use_case.dart';

part 'my_requests_event.dart';
part 'my_requests_state.dart';

/// "My requests" — `GET /user/requests` của buyer đang đăng nhập (Multime `RequestBuyerBloc`),
/// kèm offer của từng request để hiện khoảng giá / provider / "Booked with".
class MyRequestsBloc extends BlocWithApi<MyRequestsEvent, MyRequestsState> {
  final GetMyRequestsUseCase _getMyRequests;
  final GetRequestOffersUseCase _getRequestOffers;
  final GlobalStorage _storage;

  static const _pageSize = 20;

  MyRequestsBloc({
    required GetMyRequestsUseCase getMyRequests,
    required GetRequestOffersUseCase getRequestOffers,
    required GlobalStorage storage,
  }) : _getMyRequests = getMyRequests,
       _getRequestOffers = getRequestOffers,
       _storage = storage,
       super(const MyRequestsState()) {
    on<MyRequestsStarted>(_onStarted);
    on<MyRequestsLoadMore>(_onLoadMore);
    on<MyRequestsTabChanged>(_onTabChanged);
  }

  Future<void> _onStarted(
    MyRequestsStarted event,
    Emitter<MyRequestsState> emit,
  ) async {
    final userId = _storage.userId;
    if (!_storage.isLoggedIn || userId == null) {
      emit(state.copyWith(status: MyRequestsStatus.signedOut));
      return;
    }
    if (state.items.isEmpty) {
      emit(state.copyWith(status: MyRequestsStatus.loading));
    }
    await _load(emit, userId: userId, page: 1);
  }

  Future<void> _onLoadMore(
    MyRequestsLoadMore event,
    Emitter<MyRequestsState> emit,
  ) async {
    final userId = _storage.userId;
    if (userId == null || !state.hasMore || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));
    await _load(emit, userId: userId, page: state.page + 1);
  }

  void _onTabChanged(
    MyRequestsTabChanged event,
    Emitter<MyRequestsState> emit,
  ) {
    emit(state.copyWith(tab: event.tab));
    // Một trang có thể toàn request của tab kia → tải tiếp để tab mới không trống oan.
    if (state.visibleItems.isEmpty && state.hasMore) {
      add(const MyRequestsLoadMore());
    }
  }

  Future<void> _load(
    Emitter<MyRequestsState> emit, {
    required int userId,
    required int page,
  }) async {
    List<MyRequestEntity>? loaded;
    await callApi(
      useCase: _getMyRequests,
      param: GetMyRequestsParams(userId: userId, page: page, limit: _pageSize),
      onSuccess: (result) async {
        loaded = result.items;
        emit(
          state.copyWith(
            status: MyRequestsStatus.success,
            items: page == 1 ? result.items : [...state.items, ...result.items],
            offers: page == 1 ? const {} : null,
            page: page,
            hasMore: page < result.totalPage,
            isLoadingMore: false,
          ),
        );
      },
      onFailure: (message) => emit(
        state.copyWith(
          status: page == 1 ? MyRequestsStatus.failure : state.status,
          errorMessage: message,
          isLoadingMore: false,
        ),
      ),
    );
    final requests = loaded;
    if (requests == null) return;
    if (state.hasMore && state.visibleItems.isEmpty) {
      add(const MyRequestsLoadMore());
    }
    // Offer từng request (song song); lỗi thì thẻ chỉ hiện số offer từ `offers_count`.
    await Future.wait([
      for (final request in requests)
        if (request.offersCount > 0) _loadOffers(emit, request.id),
    ]);
  }

  Future<void> _loadOffers(Emitter<MyRequestsState> emit, int requestId) =>
      callApi(
        useCase: _getRequestOffers,
        param: requestId,
        onSuccess: (offers) async {
          if (emit.isDone) return;
          emit(state.copyWith(offers: {...state.offers, requestId: offers}));
        },
        onFailure: (_) {},
      );
}
