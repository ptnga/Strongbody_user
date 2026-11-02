import 'package:get_it/get_it.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/network/api.dart';

import '../data/datasources/remote/report_remote_datasource.dart';
import '../data/repositories/report_repository_impl.dart';
import '../domain/repositories/report_repository.dart';
import '../domain/usecases/submit_report_use_case.dart';
import '../presentation/bloc/report/report_bloc.dart';

/// Datasource/repository: `registerLazySingleton`; UseCase/Bloc: `registerFactory`.
void registerReportModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<ReportRemoteDataSource>(
      () => ReportRemoteDataSourceImpl(getIt<ApiClient>()),
    )
    ..registerLazySingleton<ReportRepository>(
      () => ReportRepositoryImpl(
        getIt<ReportRemoteDataSource>(),
        getIt<GlobalStorage>(),
      ),
    )
    ..registerFactory(() => SubmitReportUseCase(getIt<ReportRepository>()))
    ..registerFactory(
      () => ReportBloc(submitReport: getIt<SubmitReportUseCase>()),
    );
}
