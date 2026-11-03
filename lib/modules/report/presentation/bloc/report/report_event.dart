part of 'report_bloc.dart';

sealed class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

final class ReportSubmitted extends ReportEvent {
  final int reportedUserId;
  final ReportReason reason;
  final String? note;
  final String context;

  const ReportSubmitted({
    required this.reportedUserId,
    required this.reason,
    this.note,
    this.context = 'chat',
  });

  @override
  List<Object?> get props => [reportedUserId, reason, note, context];
}
