import 'package:get_it/get_it.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/services/microphone_permission_service.dart';
import 'package:strongbody_buyer/core/services/speech_recognition_service.dart';
import 'package:strongbody_buyer/core/services/voice_note_recorder.dart';

import '../data/datasources/remote/post_request_remote_datasource.dart';
import '../data/repositories/post_request_repository_impl.dart';
import '../domain/repositories/post_request_repository.dart';
import '../domain/usecases/create_buyer_request_use_case.dart';
import '../domain/usecases/draft_request_use_case.dart';
import '../domain/usecases/get_my_requests_use_case.dart';
import '../domain/usecases/get_provider_extras_use_case.dart';
import '../domain/usecases/get_request_offers_use_case.dart';
import '../domain/usecases/search_providers_use_case.dart';
import '../domain/usecases/transcribe_audio_use_case.dart';
import '../presentation/bloc/matching_providers/matching_providers_bloc.dart';
import '../presentation/bloc/my_requests/my_requests_bloc.dart';
import '../presentation/bloc/post_request_flow/post_request_flow_bloc.dart';
import '../presentation/bloc/request_offers/request_offers_bloc.dart';
import '../presentation/bloc/voice_request/voice_request_bloc.dart';

/// Datasource/repository: `registerLazySingleton`; UseCase/Bloc: `registerFactory`.
void registerPostRequestModule(GetIt getIt) {
  getIt
    ..registerLazySingleton<PostRequestRemoteDataSource>(
      () => PostRequestRemoteDataSourceImpl(getIt<ApiClient>()),
    )
    ..registerLazySingleton<PostRequestRepository>(
      () => PostRequestRepositoryImpl(getIt<PostRequestRemoteDataSource>()),
    )
    ..registerFactory(
      () => TranscribeAudioUseCase(getIt<PostRequestRepository>()),
    )
    ..registerFactory(() => DraftRequestUseCase(getIt<PostRequestRepository>()))
    ..registerFactory(
      () => CreateBuyerRequestUseCase(getIt<PostRequestRepository>()),
    )
    ..registerFactory(
      () => SearchProvidersUseCase(getIt<PostRequestRepository>()),
    )
    ..registerFactory(
      () => GetMyRequestsUseCase(getIt<PostRequestRepository>()),
    )
    ..registerFactory(
      () => GetProviderExtrasUseCase(getIt<PostRequestRepository>()),
    )
    ..registerFactory(
      () => GetRequestOffersUseCase(getIt<PostRequestRepository>()),
    )
    ..registerFactory(
      () => PostRequestFlowBloc(
        transcribeAudio: getIt<TranscribeAudioUseCase>(),
        draftRequest: getIt<DraftRequestUseCase>(),
        searchProviders: getIt<SearchProvidersUseCase>(),
        createBuyerRequest: getIt<CreateBuyerRequestUseCase>(),
        storage: getIt<GlobalStorage>(),
      ),
    )
    ..registerFactory(
      () => MatchingProvidersBloc(
        searchProviders: getIt<SearchProvidersUseCase>(),
        getProviderExtras: getIt<GetProviderExtrasUseCase>(),
      ),
    )
    ..registerFactory(
      () => MyRequestsBloc(
        getMyRequests: getIt<GetMyRequestsUseCase>(),
        getRequestOffers: getIt<GetRequestOffersUseCase>(),
        storage: getIt<GlobalStorage>(),
      ),
    )
    ..registerFactory(
      () =>
          RequestOffersBloc(getRequestOffers: getIt<GetRequestOffersUseCase>()),
    )
    ..registerFactory(
      () => VoiceRequestBloc(
        speech: getIt<SpeechRecognitionService>(),
        recorder: getIt<VoiceNoteRecorder>(),
        permission: getIt<MicrophonePermissionService>(),
      ),
    );
}
