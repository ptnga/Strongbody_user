import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/core/network/api.dart';
import 'package:strongbody_buyer/core/services/microphone_permission_service.dart';
import 'package:strongbody_buyer/core/services/speech_recognition_service.dart';
import 'package:strongbody_buyer/core/services/voice_note_recorder.dart';
import 'package:strongbody_buyer/modules/account/di/account_module.dart';
import 'package:strongbody_buyer/modules/auth/di/auth_module.dart';
import 'package:strongbody_buyer/modules/chat/di/chat_module.dart';
import 'package:strongbody_buyer/modules/checkout/di/checkout_module.dart';
import 'package:strongbody_buyer/modules/home/di/home_module.dart';
import 'package:strongbody_buyer/modules/post_request/di/post_request_module.dart';
import 'package:strongbody_buyer/modules/social_market/di/social_market_module.dart';

final GetIt getIt = GetIt.instance;

class ServiceLocator {
  Future<void> servicesLocator() async {
    //-----------------CORE---------------
    final storage = GlobalStorageImpl();
    await storage.init();
    getIt.registerSingleton<GlobalStorage>(storage);
    getIt.registerSingleton<ApiClient>(ApiClient(Dio(), storage));
    final preferences = UserPreferencesImpl();
    await preferences.init();
    getIt.registerSingleton<UserPreferences>(preferences);
    getIt.registerLazySingleton<SpeechRecognitionService>(
      SpeechRecognitionServiceImpl.new,
    );
    getIt.registerFactory<VoiceNoteRecorder>(VoiceNoteRecorderImpl.new);
    getIt.registerLazySingleton<MicrophonePermissionService>(
      MicrophonePermissionServiceImpl.new,
    );

    //-----------------MODULES---------------
    // Mỗi module có `di/<module>_module.dart` với hàm `registerXModule(getIt)`.
    registerAuthModule(getIt);
    registerHomeModule(getIt);
    registerPostRequestModule(getIt);
    registerChatModule(getIt);
    registerSocialMarketModule(getIt);
    registerAccountModule(getIt);
    registerCheckoutModule(getIt);
  }
}
