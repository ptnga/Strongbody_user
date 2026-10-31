import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/medical_travel_entities.dart';
import '../../../domain/usecases/social_market_use_cases.dart';
import '../category_market/category_market_bloc.dart' show SectionStatus;

class ServiceDetailState extends Equatable {
  final SectionStatus status;
  final MarketServiceDetail? detail;

  const ServiceDetailState({this.status = SectionStatus.initial, this.detail});

  @override
  List<Object?> get props => [status, detail];
}

/// Trang chi tiết service Medical Travel (web `/medical-travel/service/...`).
class ServiceDetailCubit extends Cubit<ServiceDetailState> {
  final GetServiceDetailUseCase _getDetail;

  ServiceDetailCubit({required GetServiceDetailUseCase getDetail})
    : _getDetail = getDetail,
      super(const ServiceDetailState());

  Future<void> load(int id) async {
    emit(
      ServiceDetailState(status: SectionStatus.loading, detail: state.detail),
    );
    final result = await _getDetail(id);
    if (isClosed) return;
    result.fold(
      (_) => emit(
        ServiceDetailState(status: SectionStatus.failure, detail: state.detail),
      ),
      (detail) => emit(
        ServiceDetailState(status: SectionStatus.success, detail: detail),
      ),
    );
  }
}
