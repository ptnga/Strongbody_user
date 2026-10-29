import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';

import '../../../domain/entities/my_request_entity.dart';
import '../../../domain/usecases/get_request_offers_use_case.dart';

part 'request_offers_event.dart';
part 'request_offers_state.dart';

/// Trang "Offers" của một request — cùng API offer với thẻ ở My requests (web `useOffers`
/// với `showAllOffers`), sắp xếp phía app.
class RequestOffersBloc
    extends BlocWithApi<RequestOffersEvent, RequestOffersState> {
  final GetRequestOffersUseCase _getRequestOffers;

  RequestOffersBloc({required GetRequestOffersUseCase getRequestOffers})
    : _getRequestOffers = getRequestOffers,
      super(const RequestOffersState()) {
    on<RequestOffersStarted>(_onStarted);
    on<RequestOffersSortChanged>(
      (event, emit) => emit(state.copyWith(sort: event.sort)),
    );
  }

  Future<void> _onStarted(
    RequestOffersStarted event,
    Emitter<RequestOffersState> emit,
  ) async {
    // Có sẵn offer từ My requests → hiện ngay, vẫn tải lại cho mới.
    final seeded = event.initialOffers;
    emit(
      state.copyWith(
        status: seeded == null && state.offers.isEmpty
            ? RequestOffersStatus.loading
            : RequestOffersStatus.success,
        offers: seeded,
      ),
    );
    await callApi(
      useCase: _getRequestOffers,
      param: event.requestId,
      onSuccess: (offers) async => emit(
        state.copyWith(status: RequestOffersStatus.success, offers: offers),
      ),
      onFailure: (_) {
        if (state.status != RequestOffersStatus.success) {
          emit(state.copyWith(status: RequestOffersStatus.failure));
        }
      },
    );
  }
}
