import 'package:get_it/get_it.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/core/network/api.dart';

import '../data/datasources/remote/chat_remote_datasource.dart';
import '../data/repositories/chat_repository_impl.dart';
import '../data/services/chat_voice_recorder.dart';
import '../domain/repositories/chat_repository.dart';
import '../domain/usecases/chat_use_cases.dart';
import '../presentation/bloc/chat/chat_bloc.dart';
import '../presentation/bloc/conversations/conversations_bloc.dart';
import '../presentation/chat_badge_notifier.dart';
import '../presentation/chat_page_args.dart';
import '../presentation/chat_read_aloud.dart';

/// Datasource/repository/badge: `registerLazySingleton`; UseCase/Bloc: `registerFactory`.
void registerChatModule(GetIt getIt) {
  ChatRepository repo() => getIt<ChatRepository>();
  getIt
    ..registerLazySingleton<ChatRemoteDataSource>(
      () => ChatRemoteDataSourceImpl(getIt<ApiClient>()),
    )
    ..registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(
        getIt<ChatRemoteDataSource>(),
        getIt<GlobalStorage>(),
      ),
    )
    ..registerFactory(() => GetConversationsUseCase(repo()))
    ..registerFactory(() => GetChatUnreadTotalUseCase(repo()))
    ..registerFactory(() => SearchChatUsersUseCase(repo()))
    ..registerFactory(() => ConnectChatUpdatesUseCase(repo()))
    ..registerFactory(() => OpenChatSessionUseCase(repo()))
    ..registerFactory(() => RefreshChatSessionUseCase(repo()))
    ..registerFactory(() => ConnectChatUseCase(repo()))
    ..registerFactory(() => GetTranslationSettingsUseCase(repo()))
    ..registerFactory(() => SaveTranslationSettingsUseCase(repo()))
    ..registerFactory(() => GetChatTranslationsUseCase(repo()))
    ..registerFactory(() => TranslateChatTextUseCase(repo()))
    ..registerFactory(() => SendChatVoiceUseCase(repo()))
    ..registerFactory(() => MarkChatReadUseCase(repo()))
    ..registerFactory(() => GetChatOffersUseCase(repo()))
    ..registerFactory<ChatVoiceRecorder>(ChatVoiceRecorderImpl.new)
    ..registerLazySingleton(
      () => ChatBadgeNotifier(
        getUnreadTotal: getIt<GetChatUnreadTotalUseCase>(),
        storage: getIt<GlobalStorage>(),
      ),
    )
    ..registerFactory(
      () => ConversationsBloc(
        getConversations: getIt<GetConversationsUseCase>(),
        searchUsers: getIt<SearchChatUsersUseCase>(),
        connectUpdates: getIt<ConnectChatUpdatesUseCase>(),
        badge: getIt<ChatBadgeNotifier>(),
        storage: getIt<GlobalStorage>(),
      ),
    )
    ..registerFactoryParam<ChatBloc, ChatPageArgs, void>(
      (args, _) => ChatBloc(
        args: args,
        openSession: getIt<OpenChatSessionUseCase>(),
        refreshSession: getIt<RefreshChatSessionUseCase>(),
        connect: getIt<ConnectChatUseCase>(),
        getSettings: getIt<GetTranslationSettingsUseCase>(),
        saveSettings: getIt<SaveTranslationSettingsUseCase>(),
        getTranslations: getIt<GetChatTranslationsUseCase>(),
        translateText: getIt<TranslateChatTextUseCase>(),
        sendVoice: getIt<SendChatVoiceUseCase>(),
        markRead: getIt<MarkChatReadUseCase>(),
        getOffers: getIt<GetChatOffersUseCase>(),
        recorder: getIt<ChatVoiceRecorder>(),
        badge: getIt<ChatBadgeNotifier>(),
        storage: getIt<GlobalStorage>(),
        preferences: getIt<UserPreferences>(),
      ),
    )
    ..registerFactory<ChatReadAloud>(ChatReadAloud.new);
}
