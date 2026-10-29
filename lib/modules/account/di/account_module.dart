import 'package:get_it/get_it.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/core/network/api.dart';

import '../data/datasources/remote/account_remote_datasource.dart';
import '../data/repositories/account_repository_impl.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/usecases/account_use_cases.dart';
import '../presentation/bloc/account/account_bloc.dart';
import '../presentation/bloc/lion_points/lion_points_bloc.dart';

/// Datasource/repository: `registerLazySingleton`; UseCase/Bloc: `registerFactory`.
void registerAccountModule(GetIt getIt) {
  AccountRepository repo() => getIt<AccountRepository>();
  getIt
    ..registerLazySingleton<AccountRemoteDataSource>(
      () => AccountRemoteDataSourceImpl(
        getIt<ApiClient>(),
        getIt<GlobalStorage>(),
      ),
    )
    ..registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(
        getIt<AccountRemoteDataSource>(),
        getIt<GlobalStorage>(),
      ),
    )
    ..registerFactory(() => GetAccountProfileUseCase(repo()))
    ..registerFactory(() => UpdateAccountProfileUseCase(repo()))
    ..registerFactory(() => GetLionPointsUseCase(repo()))
    ..registerFactory(() => GetLionLedgerUseCase(repo()))
    ..registerFactory(() => LogoutUseCase(repo()))
    ..registerFactory(
      () => AccountBloc(
        getProfile: getIt<GetAccountProfileUseCase>(),
        updateProfile: getIt<UpdateAccountProfileUseCase>(),
        getLionPoints: getIt<GetLionPointsUseCase>(),
        logout: getIt<LogoutUseCase>(),
        storage: getIt<GlobalStorage>(),
        preferences: getIt<UserPreferences>(),
      ),
    )
    ..registerFactory(
      () => LionPointsBloc(
        getLionPoints: getIt<GetLionPointsUseCase>(),
        getLedger: getIt<GetLionLedgerUseCase>(),
      ),
    );
}
