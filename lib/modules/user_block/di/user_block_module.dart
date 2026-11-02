import 'package:get_it/get_it.dart';

import 'package:strongbody_buyer/core/network/api.dart';

import '../data/datasources/remote/user_block_remote_datasource.dart';
import '../data/repositories/user_block_repository_impl.dart';
import '../domain/block_action_service.dart';
import '../domain/repositories/user_block_repository.dart';
import '../domain/usecases/block_user_use_case.dart';
import '../domain/usecases/check_block_status_use_case.dart';
import '../domain/usecases/get_blocked_users_use_case.dart';
import '../domain/usecases/unblock_user_use_case.dart';
import '../presentation/bloc/blocked_users_bloc.dart';

void registerUserBlockModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<UserBlockRemoteDataSource>(
      () => UserBlockRemoteDataSourceImpl(getIt<ApiClient>()),
    )
    ..registerLazySingleton<UserBlockRepository>(
      () => UserBlockRepositoryImpl(getIt<UserBlockRemoteDataSource>()),
    )
    ..registerLazySingleton(() => BlockUserUseCase(getIt<UserBlockRepository>()))
    ..registerLazySingleton(
      () => UnblockUserUseCase(getIt<UserBlockRepository>()),
    )
    ..registerLazySingleton(
      () => GetBlockedUsersUseCase(getIt<UserBlockRepository>()),
    )
    ..registerLazySingleton(
      () => CheckBlockStatusUseCase(getIt<UserBlockRepository>()),
    )
    ..registerLazySingleton<BlockActionService>(
      () => BlockActionService(
        blockUser: getIt<BlockUserUseCase>(),
        unblockUser: getIt<UnblockUserUseCase>(),
        repository: getIt<UserBlockRepository>(),
      ),
    )
    ..registerFactory<BlockedUsersBloc>(
      () => BlockedUsersBloc(
        getBlockedUsers: getIt<GetBlockedUsersUseCase>(),
        blockAction: getIt<BlockActionService>(),
      ),
    );
}
