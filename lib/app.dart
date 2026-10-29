import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:strongbody_buyer/app/routers/app_router.dart';
import 'package:strongbody_buyer/core/config/environment.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Bloc dùng chung toàn app (theme, language, global...) bọc MultiBlocProvider tại đây.
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: AppConfig.isDev,
      theme: AppThemeClass.lightTheme,
      routerConfig: AppRoutes.router,
      scaffoldMessengerKey: scaffoldMessengerKey,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
