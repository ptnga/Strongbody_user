import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/network/exception.dart';
import 'package:strongbody_buyer/core/services/social_auth_service.dart';
import 'package:strongbody_buyer/core/streams/auth_event_bus.dart';

import '../../domain/entities/auth_entities.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../models/response/login_response_dto.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final GlobalStorage _storage;
  final SocialAuthService _social;

  AuthRepositoryImpl(this._remote, this._storage, this._social);

  @override
  Future<Either<Failure, Unit>> signUp({
    required String email,
    required String password,
  }) => _guard(() async {
    // Giống body web gửi `/v1/public/auth/sign-up` (form chỉ có email + mật khẩu → tên rỗng).
    await _remote.signUp({
      'email': email,
      'password': password,
      'username': '',
      'full_name': '',
      'language_code': _storage.locale,
      'referral_code': _storage.referralCode ?? '',
      'ip_address': await _remote.publicIp() ?? 'Not Available',
      'attribution': const <String, dynamic>{},
    });
    return unit;
  });

  @override
  Future<Either<Failure, AuthSession>> login({
    required String email,
    required String password,
  }) => _guard(
    () async => _persist(await _remote.login(email: email, password: password)),
  );

  @override
  Future<Either<Failure, Unit>> verifyEmail({
    required String email,
    required String otp,
  }) => _guard(() async {
    await _remote.verifyEmail(
      email: email,
      otp: otp,
      referralCode: _storage.referralCode,
    );
    // Web gọi tiếp để nhận offer đã gửi tới email lúc còn là khách — lỗi thì bỏ qua.
    _remote.claimOffer(email).ignore();
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> resendVerifyEmail(String email) =>
      _guard(() async => _remote.resendVerifyEmail(email).then((_) => unit));

  @override
  Future<Either<Failure, Unit>> requestPasswordReset(String email) =>
      _guard(() async => _remote.requestPasswordReset(email).then((_) => unit));

  @override
  Future<Either<Failure, String>> verifyPasswordReset({
    required String email,
    required String otp,
  }) => _guard(() => _remote.verifyPasswordReset(email: email, otp: otp));

  @override
  Future<Either<Failure, Unit>> resetPassword({
    required String secretToken,
    required String newPassword,
  }) => _guard(
    () async => _remote
        .resetPassword(secretToken: secretToken, newPassword: newPassword)
        .then((_) => unit),
  );

  @override
  Future<Either<Failure, AuthSession>> loginWithGoogle() => _guard(() async {
    final idToken = await _social.googleIdToken();
    return _persist(await _remote.loginGoogle(idToken));
  });

  @override
  Future<Either<Failure, AuthSession>> loginWithApple() => _guard(() async {
    final code = await _social.appleAuthorizationCode();
    return _persist(await _remote.loginApple(code));
  });

  /// Lưu token + user vào storage (giống session next-auth của web) rồi báo cho các màn khác.
  Future<AuthSession> _persist(Map<String, dynamic> data) async {
    final dto = LoginResponseDto.fromData(data);
    final accessToken = dto.accessToken;
    final userId = dto.userId;
    if (accessToken == null || accessToken.isEmpty || userId == null) {
      throw AuthApiException('Login failed');
    }
    final name = [
      dto.firstName,
      dto.lastName,
    ].where((p) => p != null && p.trim().isNotEmpty).join(' ').trim();
    await _storage.saveTokens(
      accessToken: accessToken,
      refreshToken: dto.refreshToken,
    );
    await _storage.saveUser(
      id: userId,
      name: name.isEmpty ? null : name,
      email: dto.email,
    );
    AuthEventBus.emit(const UserLoggedIn());
    return AuthSession(
      userId: userId,
      name: name.isEmpty ? null : name,
      email: dto.email,
    );
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on SocialAuthCancelled {
      return Left(AuthFailure('', reason: AuthFailureReason.cancelled));
    } on SocialAuthNotConfigured {
      return Left(AuthFailure('', reason: AuthFailureReason.notConfigured));
    } on AuthApiException catch (e) {
      return Left(
        AuthFailure(
          e.message,
          reason: AuthFailure.reasonFor(e.message),
          statusCode: e.statusCode,
        ),
      );
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(Failure(e.toString()));
    }
  }
}
