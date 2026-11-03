import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';

import '../entities/report_reason.dart';

abstract class ReportRepository {
  /// Báo cáo một người dùng (`POST /buyer/reports`).
  Future<Either<Failure, Unit>> reportUser({
    required int reportedUserId,
    required ReportReason reason,
    String? note,
    String context,
  });
}
