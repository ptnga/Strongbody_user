import 'package:strongbody_buyer/core/base/failure.dart';

/// Lỗi nghiệp vụ của bộ API user block.
///
/// Server trả **HTTP 200 kèm `code` nghiệp vụ** cho lỗi, `message` là câu tiếng
/// Anh gốc. Phân loại ở đây để UI xử lý riêng (vd "đã chặn rồi").
enum UserBlockError {
  cannotBlockSelf,
  alreadyBlocked,
  blockNotFound,
  notMyBlock,
  unauthorized,
  network,
  unknown,
}

class UserBlockFailure extends Failure {
  UserBlockFailure(this.kind, super.message);

  final UserBlockError kind;
}
