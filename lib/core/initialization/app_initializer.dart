import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../analytics/app_analytics.dart';
import '../config/environment.dart';
import '../domain/global_dependencies.dart';
import '../di/locator.dart';
import '../services/last_visit_service.dart';
import '../utils/app_logger.dart';

class AppInitializer {
  AppInitializer._();

  /// Critical path — phải xong trước `runApp`.
  static Future<void> initialize() async {
    await AppConfig.loadEnv();
    await Hive.initFlutter();
    await ServiceLocator().servicesLocator();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    AppLogger.i('App initialized (${AppConfig.environment.name})');
  }

  /// Chạy sau frame đầu tiên, không chặn UI (push, analytics, crash report...).
  /// Mỗi service bọc try/catch riêng để 1 service lỗi không ảnh hưởng app.
  static Future<void> initializeDeferredServices() async {
    // Web `BuyerLastVisitTracker`: báo BE người mua vừa vào app (không chờ PostHog).
    try {
      getIt<LastVisitService>().start();
    } catch (e, s) {
      AppLogger.e('Last visit tracker failed', e, s);
    }
    try {
      await AppAnalytics.init(gs);
    } catch (e, s) {
      AppLogger.e('PostHog init failed', e, s);
    }
  }
}
