import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/report_reason.dart';
import '../repositories/report_repository.dart';

class SubmitReportParams extends Equatable {
  const SubmitReportParams({
    required this.reportedUserId,
    required this.reason,
    this.note,
    this.context = 'chat',
  });

  final int reportedUserId;
  final ReportReason reason;
  final String? note;
  final String context;

  @override
  List<Object?> get props => [reportedUserId, reason, note, context];
}

class SubmitReportUseCase implements UseCase<Unit, SubmitReportParams> {
  const SubmitReportUseCase(this._repository);

  final ReportRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SubmitReportParams params) =>
      _repository.reportUser(
        reportedUserId: params.reportedUserId,
        reason: params.reason,
        note: params.note,
        context: params.context,
      );
}
