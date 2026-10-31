import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../../../domain/entities/medical_travel_entities.dart';
import '../../../domain/usecases/social_market_use_cases.dart';

enum AppointmentStatus { idle, sending, sent, failure }

class AppointmentState extends Equatable {
  final List<PhoneCodeOption> phoneCodes;

  /// Chi tiết service tải nền (cơ sở, nước, ngôn ngữ) — mở từ card chỉ có dữ liệu card.
  final MarketServiceDetail? detail;
  final AppointmentStatus status;
  final String? error;

  const AppointmentState({
    this.phoneCodes = const [],
    this.detail,
    this.status = AppointmentStatus.idle,
    this.error,
  });

  AppointmentState copyWith({
    List<PhoneCodeOption>? phoneCodes,
    MarketServiceDetail? detail,
    AppointmentStatus? status,
    String? Function()? error,
  }) => AppointmentState(
    phoneCodes: phoneCodes ?? this.phoneCodes,
    detail: detail ?? this.detail,
    status: status ?? this.status,
    error: error != null ? error() : this.error,
  );

  @override
  List<Object?> get props => [phoneCodes, detail, status, error];
}

/// Form "Request an appointment" (web `RequestAppointmentModal` + `MedicalTravelBookButton`).
class AppointmentCubit extends Cubit<AppointmentState> {
  final GetPhoneCodesUseCase _getPhoneCodes;
  final GetServiceDetailUseCase _getDetail;
  final SendAppointmentRequestUseCase _send;

  AppointmentCubit({
    required GetPhoneCodesUseCase getPhoneCodes,
    required GetServiceDetailUseCase getDetail,
    required SendAppointmentRequestUseCase send,
  }) : _getPhoneCodes = getPhoneCodes,
       _getDetail = getDetail,
       _send = send,
       super(const AppointmentState());

  /// [detail] có sẵn (trang chi tiết) thì không tải lại; không thì tải nền theo [serviceId].
  Future<void> init({
    required int serviceId,
    MarketServiceDetail? detail,
  }) async {
    if (detail != null) emit(state.copyWith(detail: detail));
    await Future.wait([
      _getPhoneCodes(const NoParams()).then((r) {
        if (isClosed) return;
        r.fold((_) {}, (c) => emit(state.copyWith(phoneCodes: c)));
      }),
      if (detail == null)
        _getDetail(serviceId).then((r) {
          // Không tải được thì form vẫn gửi được với dữ liệu của card.
          if (!isClosed) r.fold((_) {}, (d) => emit(state.copyWith(detail: d)));
        }),
    ]);
  }

  Future<void> submit(AppointmentRequest request) async {
    if (state.status == AppointmentStatus.sending) return;
    emit(state.copyWith(status: AppointmentStatus.sending, error: () => null));
    final result = await _send(request);
    if (isClosed) return;
    result.fold(
      (f) => emit(
        state.copyWith(
          status: AppointmentStatus.failure,
          error: () => f.message,
        ),
      ),
      (_) => emit(state.copyWith(status: AppointmentStatus.sent)),
    );
  }

  /// Quay lại bước 1 sau khi gửi lỗi.
  void reset() =>
      emit(state.copyWith(status: AppointmentStatus.idle, error: () => null));
}
