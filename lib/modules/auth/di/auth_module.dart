import 'package:get_it/get_it.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/services/social_auth_service.dart';

import '../data/datasources/remote/auth_remote_datasource.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/auth_use_cases.dart';
import '../presentation/bloc/auth/auth_bloc.dart';

/// Datasource/repository: `registerLazySingleton`; UseCase/Bloc: `registerFactory`.
void registerAuthModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<SocialAuthService>(SocialAuthServiceImpl.new)
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(getIt<ApiClient>()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        getIt<AuthRemoteDataSource>(),
        getIt<GlobalStorage>(),
        getIt<SocialAuthService>(),
      ),
    )
    ..registerFactory(() => SignUpUseCase(getIt<AuthRepository>()))
    ..registerFactory(() => LoginUseCase(getIt<AuthRepository>()))
    ..registerFactory(() => SocialLoginUseCase(getIt<AuthRepository>()))
    ..registerFactory(() => VerifyEmailUseCase(getIt<AuthRepository>()))
    ..registerFactory(() => ResendVerifyEmailUseCase(getIt<AuthRepository>()))
    ..registerFactory(
      () => RequestPasswordResetUseCase(getIt<AuthRepository>()),
    )
    ..registerFactory(() => VerifyPasswordResetUseCase(getIt<AuthRepository>()))
    ..registerFactory(() => ResetPasswordUseCase(getIt<AuthRepository>()))
    ..registerFactory(
      () => AuthBloc(
        signUp: getIt<SignUpUseCase>(),
        login: getIt<LoginUseCase>(),
        socialLogin: getIt<SocialLoginUseCase>(),
        verifyEmail: getIt<VerifyEmailUseCase>(),
        resendVerifyEmail: getIt<ResendVerifyEmailUseCase>(),
        requestPasswordReset: getIt<RequestPasswordResetUseCase>(),
        verifyPasswordReset: getIt<VerifyPasswordResetUseCase>(),
        resetPassword: getIt<ResetPasswordUseCase>(),
      ),
    );
}
