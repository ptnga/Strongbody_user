import 'package:get_it/get_it.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/core/network/api.dart';

import 'package:strongbody_buyer/modules/post_request/domain/usecases/search_providers_use_case.dart';

import '../data/datasources/remote/home_remote_datasource.dart';
import '../data/repositories/home_repository_impl.dart';
import '../domain/repositories/home_repository.dart';
import '../domain/usecases/get_new_offers_count_use_case.dart';
import 'package:strongbody_buyer/modules/account/domain/usecases/account_use_cases.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/get_my_requests_use_case.dart';

import '../presentation/bloc/home/home_bloc.dart';
import '../presentation/bloc/home_menu/home_menu_cubit.dart';
import '../presentation/new_offers_badge_notifier.dart';

/// Datasource/repository: `registerLazySingleton`; UseCase/Bloc: `registerFactory`.
void registerHomeModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<HomeRemoteDataSource>(
      () => HomeRemoteDataSourceImpl(getIt<ApiClient>()),
    )
    ..registerLazySingleton<HomeRepository>(
      () => HomeRepositoryImpl(getIt<HomeRemoteDataSource>()),
    )
    ..registerFactory(() => GetNewOffersCountUseCase(getIt<HomeRepository>()))
    ..registerFactory(
      () => HomeMenuCubit(
        getMyRequests: getIt<GetMyRequestsUseCase>(),
        getLionPoints: getIt<GetLionPointsUseCase>(),
        storage: getIt<GlobalStorage>(),
      ),
    )
    ..registerLazySingleton(
      () => NewOffersBadgeNotifier(
        getCount: getIt<GetNewOffersCountUseCase>(),
        storage: getIt<GlobalStorage>(),
      ),
    )
    ..registerFactory<HomeBloc>(
      () => HomeBloc(
        getNewOffersCount: getIt<GetNewOffersCountUseCase>(),
        searchProviders: getIt<SearchProvidersUseCase>(),
        storage: getIt<GlobalStorage>(),
        preferences: getIt<UserPreferences>(),
      ),
    );
}
