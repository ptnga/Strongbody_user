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
}
