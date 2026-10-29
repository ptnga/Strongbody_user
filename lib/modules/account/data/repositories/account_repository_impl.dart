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
    final data = await _remote.updateProfile({
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'city': city.trim(),
    });
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
    final wallet = AccountMapper.wallet(await _remote.getWallet(userId));
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
}
