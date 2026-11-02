part of 'report_bloc.dart';

enum ReportStatus { initial, submitting, success, failure }

class ReportState extends Equatable {
  final ReportStatus status;
  final String? error;

  const ReportState({this.status = ReportStatus.initial, this.error});

  bool get isSubmitting => status == ReportStatus.submitting;

  ReportState copyWith({ReportStatus? status, String? error}) => ReportState(
    status: status ?? this.status,
    error: error ?? this.error,
  );

  @override
  List<Object?> get props => [status, error];
}
