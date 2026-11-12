import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/network/exception.dart';
import 'package:strongbody_buyer/core/streams/auth_event_bus.dart';

import '../../domain/entities/account_entities.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/remote/account_remote_datasource.dart';
import '../mappers/account_mapper.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AccountRemoteDataSource _remote;
  final GlobalStorage _storage;

  AccountRepositoryImpl(this._remote, this._storage);

  Future<Either<Failure, T>> _guard<T>(
    Future<T> Function() run,
    String fallback,
  ) async {
    try {
      return Right(await run());
    } on AccountApiException catch (e) {
      return Left(ServerFailure(e.message));
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['message']?.toString() : null;
      return Left(
        ServerFailure(message ?? fallback, statusCode: e.response?.statusCode),
      );
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(Failure(fallback));
    }
  }

  @override
  Future<Either<Failure, AccountProfile>> getProfile() => _guard(() async {
    final profile = AccountMapper.profile(await _remote.getMe());
    if (profile == null) throw Exception('No profile');
    await _syncSession(profile);
    return profile;
  }, 'Cannot load your profile');

  @override
  Future<Either<Failure, AccountProfile>> updateProfile({
    required String firstName,
    required String lastName,
    required String city,
  }) => _guard(() async {
    final data = await _remote.updateProfile(
      AccountMapper.profileForm(
        firstName: firstName,
        lastName: lastName,
        city: city,
      ),
    );
    // PUT có thể không trả user → đọc lại.
    final profile =
        AccountMapper.profile(
          data['user'] is Map ? Map.from(data['user']) : data,
        ) ??
        AccountMapper.profile(await _remote.getMe());
    if (profile == null) throw Exception('No profile');
    await _syncSession(profile);
    AuthEventBus.emit(const UserProfileUpdated());
    return profile;
  }, 'Cannot update your profile');

  /// Tên trong phiên (Home "Hi …", avatar) theo profile mới nhất.
  Future<void> _syncSession(AccountProfile profile) async {
    final name = profile.fullName;
    if (name.isEmpty || name == _storage.userName) return;
    await _storage.saveUser(
      id: profile.id,
      name: name,
      email: profile.email ?? _storage.userEmail,
    );
  }

  @override
  Future<Either<Failure, LionWallet>> getWallet() => _guard(() async {
    final userId = _storage.userId;
    if (userId == null) throw Exception('Signed out');
    final Map<String, dynamic> json;
    try {
      json = await _remote.getWallet(userId);
    } on DioException catch (e) {
      // Web: 404 "Customer not found" = chưa có ví → 0 điểm là số thật, không phải lỗi.
      if (e.response?.statusCode == 404) return LionWallet.empty;
      rethrow;
    }
    final wallet = AccountMapper.wallet(json);
    if (wallet == null) throw Exception('No wallet');
    return wallet;
  }, 'Cannot load Lion Points');

  @override
  Future<Either<Failure, double?>> getPointValue() => _guard(
    () async => AccountMapper.pointValue(await _remote.getAppSettings()),
    'Cannot load point value',
  );

  @override
  Future<Either<Failure, ({List<LionLedgerItem> items, bool hasMore})>>
  getLedger({required int walletId, required int page, int limit = 20}) =>
      _guard(() async {
        final raw = await _remote.getLedger(walletId, page: page, limit: limit);
        return (
          items: raw.map(AccountMapper.ledgerItem).nonNulls.toList(),
          hasMore: raw.length >= limit,
        );
      }, 'Cannot load history');

  @override
  Future<Either<Failure, Unit>> logout() async {
    try {
      await _remote.logout();
    } catch (_) {
      // Như web: server lỗi vẫn đăng xuất trên máy.
    }
    // Gọi logout có thể đã làm hỏng refresh → ApiClient tự xoá phiên + báo rồi.
    if (_storage.isLoggedIn) {
      await _storage.clearUser();
      AuthEventBus.emit(const UserLoggedOut());
    }
    return const Right(unit);
  }

  /// Bước 1: BE gửi mã OTP. Giữ nguyên phiên (chưa xoá gì cả).
  @override
  Future<Either<Failure, Unit>> requestAccountDeletion({
    required String password,
  }) => _guard(() async {
    final userId = _storage.userId;
    final email = _storage.userEmail;
    if (userId == null || email == null || email.isEmpty) {
      throw Exception('Signed out');
    }
    await _remote.requestAccountDeletion(
      userId: userId,
      email: email,
      password: password,
    );
    return unit;
  }, 'Cannot delete your account');

  /// Bước 2: chỉ xoá phiên khi server xác nhận đã xoá tài khoản.
  @override
  Future<Either<Failure, Unit>> verifyAccountDeletion({
    required String otp,
  }) => _guard(() async {
    final email = _storage.userEmail;
    if (email == null || email.isEmpty) throw Exception('Signed out');
    await _remote.verifyAccountDeletion(email: email, otp: otp);
    // Web `signOutAndClearSubscriptionCookie`: gọi logout (lỗi bỏ qua) rồi xoá phiên.
    try {
      await _remote.logout();
    } catch (_) {}
    if (_storage.isLoggedIn) {
      await _storage.clearUser();
      AuthEventBus.emit(const UserLoggedOut());
    }
    return unit;
  }, 'Cannot delete your account');
}
