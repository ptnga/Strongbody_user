import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';

import '../entities/account_entities.dart';

abstract class AccountRepository {
  Future<Either<Failure, AccountProfile>> getProfile();

  /// `PUT /buyer/auth/profile` rồi lưu tên mới vào phiên.
  Future<Either<Failure, AccountProfile>> updateProfile({
    required String firstName,
    required String lastName,
    required String city,
  });

  Future<Either<Failure, LionWallet>> getWallet();

  /// USD của 1 điểm (`/admin/app-settings` → `value_of_1_point`); null = chưa cấu hình.
  Future<Either<Failure, double?>> getPointValue();

  Future<Either<Failure, ({List<LionLedgerItem> items, bool hasMore})>>
  getLedger({required int walletId, required int page, int limit = 20});

  /// Đăng xuất server (lỗi vẫn xoá phiên trên máy, như web/Multime).
  Future<Either<Failure, Unit>> logout();

  /// Bước 1 xoá tài khoản: xác minh mật khẩu → BE gửi mã OTP tới email. Không
  /// đụng vào phiên đăng nhập.
  Future<Either<Failure, Unit>> requestAccountDeletion({
    required String password,
  });

  /// Bước 2: gửi mã OTP để xác nhận xoá; chỉ khi BE xác nhận mới xoá phiên trên máy.
  Future<Either<Failure, Unit>> verifyAccountDeletion({required String otp});
}
