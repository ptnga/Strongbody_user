import 'package:get_it/get_it.dart';

import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/core/network/api.dart';

import '../data/datasources/remote/assistant_remote_datasource.dart';
import '../data/repositories/assistant_repository_impl.dart';
import '../domain/repositories/assistant_repository.dart';
import '../domain/usecases/assistant_use_cases.dart';
import '../presentation/bloc/assistant_chat_cubit.dart';

/// Datasource/repository: `registerLazySingleton`; UseCase/Cubit: `registerFactory`.
void registerAssistantModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<AssistantRemoteDataSource>(
      () => AssistantRemoteDataSourceImpl(getIt<ApiClient>()),
    )
    ..registerLazySingleton<AssistantRepository>(
      () => AssistantRepositoryImpl(
        getIt<AssistantRemoteDataSource>(),
        getIt<UserPreferences>(),
      ),
    )
    ..registerFactory(
      () => StreamAssistantChatUseCase(getIt<AssistantRepository>()),
    )
    ..registerFactory(
      () => AssistantHistoryUseCase(getIt<AssistantRepository>()),
    )
    ..registerFactory(
      () => AssistantChatCubit(
        chat: getIt<StreamAssistantChatUseCase>(),
        history: getIt<AssistantHistoryUseCase>(),
      ),
    );
}
