import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:strongbody_buyer/app.dart';
import 'package:strongbody_buyer/core/config/environment.dart';
import 'package:strongbody_buyer/core/domain/global_dependencies.dart';
import 'package:strongbody_buyer/core/initialization/app_initializer.dart';
import 'package:strongbody_buyer/core/utils/app_logger.dart';

const List<Locale> supportedLocales = [Locale('en'), Locale('vi')];

/// Entry duy nhất — môi trường lấy từ `--flavor dev|prod`.
Future<void> main() async {
  AppConfig.setEnvironment(Environment.fromFlavor(appFlavor));
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await EasyLocalization.ensureInitialized();
    // Tên thứ / tháng theo ngôn ngữ cho DateFormat ("Sat 24 – Sun 25 Oct").
    await initializeDateFormatting();
    await AppInitializer.initialize();

    runApp(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        ),
        child: EasyLocalization(
          supportedLocales: supportedLocales,
          path: 'assets/translations',
          fallbackLocale: const Locale('en'),
          useFallbackTranslations: true,
          startLocale: Locale(gs.locale),
          child: const MyApp(),
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppInitializer.initializeDeferredServices();
    });
  }, (error, stackTrace) => AppLogger.e('Uncaught error', error, stackTrace));
}
