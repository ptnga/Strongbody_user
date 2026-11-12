import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/network/api_type.dart';
import 'package:strongbody_buyer/modules/account/data/datasources/remote/account_remote_datasource.dart';
import 'package:strongbody_buyer/modules/account/data/mappers/account_mapper.dart';
import 'package:strongbody_buyer/modules/account/data/repositories/account_repository_impl.dart';
import 'package:strongbody_buyer/modules/account/domain/entities/account_entities.dart';
import 'package:strongbody_buyer/modules/auth/data/datasources/remote/auth_remote_datasource.dart';
import 'package:strongbody_buyer/modules/auth/domain/entities/auth_entities.dart';
import 'package:strongbody_buyer/modules/auth/domain/repositories/auth_repository.dart';
import 'package:strongbody_buyer/modules/auth/domain/usecases/auth_use_cases.dart';
import 'package:strongbody_buyer/modules/auth/presentation/bloc/auth/auth_bloc.dart';

/// Ghi lại request gửi đi để so với web (path, method, body, header).
class _Call {
  final String path;
  final ApiType method;
  final dynamic data;
  final Map<String, dynamic>? headers;
  final Map<String, dynamic>? query;
  final bool skipAuth;

  _Call(
    this.path,
    this.method,
    this.data,
    this.headers,
    this.query,
    this.skipAuth,
  );
}

class _RecordingApi implements ApiClient {
  final calls = <_Call>[];
  dynamic Function(String path)? respond;

  @override
  Future<dynamic> request({
    required String path,
    required ApiType method,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    Duration? timeout,
    bool skipAuth = false,
    ResponseType? responseType,
  }) async {
    calls.add(_Call(path, method, data, headers, queryParameters, skipAuth));
    return respond?.call(path) ?? {'code': 0, 'message': 'ok', 'data': {}};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements GlobalStorage {
  bool loggedIn = true;

  @override
  bool get isLoggedIn => loggedIn;
  @override
  int? get userId => 7;
  @override
  String? get userEmail => 'sarah@mail.com';
  @override
  String? get userName => 'Sarah';
  @override
  String? get accessToken => 'token';
  @override
  Future<void> clearUser() async => loggedIn = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Datasource giả cho repository: ví trả 404 như point service khi chưa có ví.
class _WalletRemote implements AccountRemoteDataSource {
  @override
  Future<Map<String, dynamic>> getWallet(int userId) async {
    final options = RequestOptions(path: '/v1/wallets/customer/$userId');
    throw DioException(
      requestOptions: options,
      response: Response(
        requestOptions: options,
        statusCode: 404,
        data: {'message': 'Customer not found'},
      ),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthRepo implements AuthRepository {
  @override
  Future<Either<Failure, Unit>> signUp({
    required String email,
    required String password,
  }) async => const Right(unit);

  @override
  Future<Either<Failure, AuthSession>> login({
    required String email,
    required String password,
  }) async => email == 'new@mail.com' && !verified
      ? Left(
          AuthFailure(
            'Account not verified',
            reason: AuthFailureReason.notVerified,
          ),
        )
      : const Right(AuthSession(userId: 7, email: 'sarah@mail.com'));

  bool verified = false;

  @override
  Future<Either<Failure, Unit>> verifyEmail({
    required String email,
    required String otp,
  }) async {
    if (otp != '1234') return Left(AuthFailure('Otp is invalid'));
    verified = true;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> requestPasswordReset(String email) async =>
      const Right(unit);

  @override
  Future<Either<Failure, String>> verifyPasswordReset({
    required String email,
    required String otp,
  }) async => Left(AuthFailure(''));

  @override
  Future<({bool? valid, String? error})> verifyEmailDomain(String email) async {
    domainChecks.add(email);
    return email.endsWith('@nomx.test')
        ? (valid: false, error: null)
        : (valid: true, error: null);
  }

  final domainChecks = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthBloc _authBloc(AuthRepository repo) => AuthBloc(
  signUp: SignUpUseCase(repo),
  login: LoginUseCase(repo),
  socialLogin: SocialLoginUseCase(repo),
  verifyEmail: VerifyEmailUseCase(repo),
  resendVerifyEmail: ResendVerifyEmailUseCase(repo),
  requestPasswordReset: RequestPasswordResetUseCase(repo),
  verifyPasswordReset: VerifyPasswordResetUseCase(repo),
  resetPassword: ResetPasswordUseCase(repo),
  verifyEmailDomain: VerifyEmailDomainUseCase(repo),
);

Future<AuthState> _until(AuthBloc bloc, bool Function(AuthState) test) =>
    test(bloc.state) ? Future.value(bloc.state) : bloc.stream.firstWhere(test);

void main() {
  setUpAll(
    () => dotenv.loadFromString(
      envString: 'PUBLIC_API_KEY=test-key\nWEB_BASE_URL=https://web.test',
    ),
  );

  group('auth validation (web ForgotPasswordDialog)', () {
    test('forgot email: required + format only (no character rule)', () {
      expect(
        AuthBloc.validateForgotEmail('')?.key,
        LocaleKeys.authEmailRequired,
      );
      expect(
        AuthBloc.validateForgotEmail('abc')?.key,
        LocaleKeys.authEmailInvalid,
      );
      expect(AuthBloc.validateForgotEmail('a+b@mail.com'), isNull);
    });

    test('new password: only min 8 characters', () {
      expect(AuthBloc.validateNewPassword('')?.key, LocaleKeys.authPasswordMin);
      expect(
        AuthBloc.validateNewPassword('short')?.key,
        LocaleKeys.authPasswordMin,
      );
      expect(AuthBloc.validateNewPassword('a' * 70), isNull);
    });
  });

  group('auth bloc toasts + messages (web)', () {
    test(
      'sign up → "Registration successful", login → "Login successful"',
      () async {
        final bloc = _authBloc(_AuthRepo())
          ..add(
            const AuthSignUpSubmitted(
              email: 'sarah@mail.com',
              password: 'secret123',
            ),
          );
        final signedUp = await _until(
          bloc,
          (s) => s.status == AuthStatus.success,
        );
        expect(signedUp.notice?.message.key, LocaleKeys.authRegisterSuccess);
        await bloc.close();

        final login = _authBloc(_AuthRepo())
          ..add(const AuthStarted(screen: AuthScreen.login))
          ..add(
            const AuthLoginSubmitted(
              email: 'sarah@mail.com',
              password: 'secret123',
            ),
          );
        final done = await _until(login, (s) => s.status == AuthStatus.success);
        expect(done.notice?.message.key, LocaleKeys.authLoginSuccess);
        expect(done.notice?.info, isFalse);
        await login.close();
      },
    );

    test(
      'verify email OTP: generic failure, then "OTP verification successful"',
      () async {
        final bloc = _authBloc(_AuthRepo())
          ..add(const AuthStarted(screen: AuthScreen.login))
          ..add(
            const AuthLoginSubmitted(
              email: 'new@mail.com',
              password: 'secret123',
            ),
          );
        await _until(bloc, (s) => s.screen == AuthScreen.verifyOtp);
        bloc.add(const AuthOtpSubmitted('0000'));
        final failed = await _until(bloc, (s) => s.otpError != null);
        // Web không hiện message server ("Otp is invalid").
        expect(failed.otpError?.key, LocaleKeys.authOtpFailed);
        bloc.add(const AuthOtpSubmitted('1234'));
        final done = await _until(bloc, (s) => s.status == AuthStatus.success);
        expect(done.notice?.message.key, LocaleKeys.authOtpVerified);
        await bloc.close();
      },
    );

    test('forgot OTP without secret token → "request a new code"', () async {
      final bloc = _authBloc(_AuthRepo())
        ..add(const AuthScreenChanged(AuthScreen.forgotEmail))
        ..add(const AuthForgotEmailSubmitted('a+b@mail.com'));
      await _until(bloc, (s) => s.screen == AuthScreen.forgotOtp);
      bloc.add(const AuthOtpSubmitted('1234'));
      final s = await _until(bloc, (s) => s.otpError != null);
      expect(s.otpError?.key, LocaleKeys.authTokenMissing);
      await bloc.close();
    });

    test(
      'email domain without MX → warning on sign up only (debounced)',
      () async {
        final repo = _AuthRepo();
        final bloc = _authBloc(repo)
          ..add(const AuthStarted(screen: AuthScreen.signup))
          ..add(const AuthEmailChanged('sarah@nomx'))
          ..add(const AuthEmailChanged('sarah@nomx.test'));
        final warned = await _until(bloc, (s) => s.emailDomainError != null);
        expect(warned.emailDomainError?.key, LocaleKeys.authEmailDomainInvalid);
        // Debounce: chỉ email cuối được kiểm tra.
        expect(repo.domainChecks, ['sarah@nomx.test']);

        bloc.add(const AuthScreenChanged(AuthScreen.login));
        final login = await _until(bloc, (s) => s.screen == AuthScreen.login);
        expect(login.emailDomainError, isNull);
        bloc.add(const AuthEmailChanged('other@nomx.test'));
        await Future<void>.delayed(
          AuthBloc.domainDebounce + const Duration(milliseconds: 100),
        );
        expect(repo.domainChecks, ['sarah@nomx.test']);
        await bloc.close();
      },
    );
  });

  group('auth remote (web api/auth)', () {
    test('sign up body, resend + claim headers, social attribution', () async {
      final api = _RecordingApi();
      final remote = AuthRemoteDataSourceImpl(api);
      await remote.signUp({'email': 'a@b.co', 'password': 'secret123'});
      await remote.resendVerifyEmail('a@b.co');
      await remote.claimOffer('a@b.co');
      api.respond = (_) => {
        'code': 0,
        'data': {
          'token': {'accessToken': 'x'},
          'user': {
            'user': {'id': 1},
          },
        },
      };
      await remote.loginGoogle('id-token');

      final signUp = api.calls[0];
      expect(signUp.path, '/public/auth/sign-up');
      expect((signUp.data as Map).containsKey('platform'), isTrue);
      expect(api.calls[1].headers?['x-api-key'], 'test-key');
      expect(api.calls[2].path, '/public/offer/claim');
      expect(api.calls[2].headers?['x-api-key'], 'test-key');
      expect((api.calls[3].data as Map)['attribution'], isEmpty);
    });

    test('applyjob lead body matches web sendApplyJob', () async {
      final api = _RecordingApi();
      await AuthRemoteDataSourceImpl(api).applyJob('a@b.co');
      final call = api.calls.single;
      expect(call.path, '/admin/ldp/applyjob');
      expect(call.method, ApiType.post);
      expect(call.skipAuth, isTrue);
      final body = call.data as Map;
      expect(body['email'], 'a@b.co');
      expect(body['fullName'], '');
      expect(jsonDecode(body['contactRequest'] as String), {
        'contact': '',
        'url': '',
        'http_refer': '',
        'start_page': '',
      });
    });

    test(
      'email domain route: valid false → error, other shapes → unknown',
      () async {
        final api = _RecordingApi()
          ..respond = (_) => {'valid': false, 'error': 'No MX'};
        final remote = AuthRemoteDataSourceImpl(api);
        final bad = await remote.verifyEmailDomain('a@nomx.test');
        expect(bad.valid, isFalse);
        expect(bad.error, 'No MX');
        expect(
          api.calls.single.path,
          'https://web.test/api/verify-email-domain',
        );

        api.respond = (_) => {'valid': null, 'error': null};
        expect((await remote.verifyEmailDomain('a@b.co')).valid, isNull);
      },
    );
  });

  group('account remote (web api/user + api/auth)', () {
    test('delete account: JSON body {email, password}, not query', () async {
      final api = _RecordingApi();
      final remote = AccountRemoteDataSourceImpl(api, _Storage());
      await remote.requestAccountDeletion(
        userId: 7,
        email: 'sarah@mail.com',
        password: 'secret123',
      );
      final call = api.calls.single;
      expect(call.path, '/buyer/auth/user/7');
      expect(call.method, ApiType.delete);
      expect(call.data, {'email': 'sarah@mail.com', 'password': 'secret123'});
      expect(call.query, isNull);
    });

    test('verify deletion sends x-api-key', () async {
      final api = _RecordingApi();
      await AccountRemoteDataSourceImpl(
        api,
        _Storage(),
      ).verifyAccountDeletion(email: 'sarah@mail.com', otp: '1234');
      expect(api.calls.single.path, '/verify-account-deletion');
      expect(api.calls.single.headers?['x-api-key'], 'test-key');
    });

    test('update profile: multipart FormData, empty names omitted', () async {
      final api = _RecordingApi();
      await AccountRemoteDataSourceImpl(api, _Storage()).updateProfile(
        AccountMapper.profileForm(firstName: ' ', lastName: 'Nguyen', city: ''),
      );
      final call = api.calls.single;
      expect(call.method, ApiType.put);
      expect(call.headers, isNull);
      final form = call.data as FormData;
      expect(Map.fromEntries(form.fields), {'last_name': 'Nguyen', 'city': ''});
    });
  });

  group('Lion Points (web lion-point pages)', () {
    test(
      'wallet 404 "Customer not found" → empty wallet, not an error',
      () async {
        final repo = AccountRepositoryImpl(_WalletRemote(), _Storage());
        final wallet = (await repo.getWallet()).getOrElse(
          (_) => throw 'failed',
        );
        expect(wallet, LionWallet.empty);
        expect(wallet.exists, isFalse);
      },
    );

    test('expiry shown only with a real date and expiring points', () {
      final wallet = AccountMapper.wallet({
        'id': 3,
        'balanceCents': 120,
        'expiredCents': 20,
        'expiresAt': '2026-12-31T00:00:00Z',
      })!;
      expect(wallet.expiresAt, isNotNull);
      expect(wallet.showsExpiry, isTrue);
      expect(
        AccountMapper.wallet({'id': 3, 'expiredCents': 20})!.showsExpiry,
        isFalse,
      );
    });

    test('ledger kinds follow web HistoryItemList', () {
      LionLedgerKind kind(String type, String source) =>
          AccountMapper.ledgerItem({
            'id': 1,
            'type': type,
            'source': source,
            'amountCents': 10,
            'idempotencyKey': 'k-1',
          })!.kind;
      expect(kind('earn', 'invite'), LionLedgerKind.referral);
      expect(kind('earn', 'purchase'), LionLedgerKind.purchase);
      expect(kind('spend', 'purchase'), LionLedgerKind.redemption);
      expect(kind('earn', 'survey'), LionLedgerKind.other);
      expect(kind('expired', ''), LionLedgerKind.other);
      expect(
        AccountMapper.ledgerItem({
          'id': 1,
          'idempotencyKey': 'k-1',
        })!.idempotencyKey,
        'k-1',
      );
    });
  });
}
