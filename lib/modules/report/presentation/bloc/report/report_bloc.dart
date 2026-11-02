import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart' show Unit;

import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';

import '../../../domain/entities/report_reason.dart';
import '../../../domain/usecases/submit_report_use_case.dart';

part 'report_event.dart';
part 'report_state.dart';

/// Gửi báo cáo một người dùng (`POST /buyer/reports`).
class ReportBloc extends BlocWithApi<ReportEvent, ReportState> {
  final SubmitReportUseCase _submitReport;

  ReportBloc({required SubmitReportUseCase submitReport})
    : _submitReport = submitReport,
      super(const ReportState()) {
    on<ReportSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    ReportSubmitted event,
    Emitter<ReportState> emit,
  ) async {
    if (state.status == ReportStatus.submitting) return;
    emit(state.copyWith(status: ReportStatus.submitting));
    await callApi<Unit, SubmitReportParams>(
      useCase: _submitReport,
      param: SubmitReportParams(
        reportedUserId: event.reportedUserId,
        reason: event.reason,
        note: event.note,
        context: event.context,
      ),
      onSuccess: (_) async => emit(state.copyWith(status: ReportStatus.success)),
      onFailure: (message) =>
          emit(state.copyWith(status: ReportStatus.failure, error: message)),
    );
  }
}
