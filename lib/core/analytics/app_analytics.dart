import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../config/environment.dart';
import '../domain/storages/global_storage.dart';
import '../streams/auth_event_bus.dart';
import '../utils/app_logger.dart';
import 'analytics_events.dart';

/// PostHog (như Multime `AppAnalytics`). `POSTHOG_API_KEY` rỗng → tắt, mọi lệnh no-op.
///
/// Bắn event: `AppAnalytics.capture(AnalyticsEvents.x, {'prop': value})`.
/// Danh tính user tự gắn theo `AuthEventBus` (login → identify, logout → reset).
abstract final class AppAnalytics {
  static bool _enabled = false;
  static StreamSubscription<AuthEvent>? _authSubscription;

  static bool get enabled => _enabled;

  static Future<void> init(GlobalStorage storage) async {
    final key = AppConfig.posthogApiKey;
    if (key.isEmpty) {
      AppLogger.i('PostHog disabled (POSTHOG_API_KEY empty)');
      return;
    }
    final config = PostHogConfig(key)
      ..host = AppConfig.posthogHost
      ..captureApplicationLifecycleEvents = false
      ..debug = AppConfig.isDev;
    await Posthog().setup(config);
    _enabled = true;
    // Lọc dev/prod trong cùng một project PostHog.
    await Posthog().register('environment', AppConfig.environment.name);

    if (storage.isLoggedIn) await _identify(storage);
    _authSubscription ??= AuthEventBus.stream.listen(
      (event) => _onAuthEvent(event, storage),
    );
    await capture(AnalyticsEvents.appOpen);
  }

  static Future<void> capture(
    String eventName, [
    Map<String, Object?> properties = const {},
  ]) async {
    if (!_enabled) return;
    try {
      await Posthog().capture(
        eventName: eventName,
        properties: _clean(properties),
      );
    } catch (e) {
      AppLogger.w('PostHog capture failed: $eventName', e);
    }
  }

  /// Screen view thủ công (vd. đổi tab — các tab giữ navigator riêng, không có route mới).
  static Future<void> screen(String name) async {
    if (!_enabled) return;
    try {
      await Posthog().screen(screenName: name);
    } catch (e) {
      AppLogger.w('PostHog screen failed: $name', e);
    }
  }

  /// Screen view tự động cho mọi `GoRoute` (tên = path, `/` → `home`).
  static NavigatorObserver observer() => PosthogObserver(
    nameExtractor: (settings) => settings.name == '/' ? 'home' : settings.name,
    routeFilter: (route) => _enabled && defaultPostHogRouteFilter(route),
  );

  static Future<void> _onAuthEvent(AuthEvent event, GlobalStorage storage) =>
      switch (event) {
        // `login_completed` (kèm method) do AuthBloc bắn.
        UserLoggedIn() || UserProfileUpdated() => _identify(storage),
        UserLoggedOut() => capture(
          AnalyticsEvents.userLoggedOut,
        ).then((_) => _guard(Posthog().reset)),
      };

  static Future<void> _identify(GlobalStorage storage) async {
    final id = storage.userId;
    if (id == null) return;
    await _guard(
      () => Posthog().identify(
        userId: id.toString(),
        userProperties: _clean({
          'name': storage.userName,
          'email': storage.userEmail,
        }),
      ),
    );
  }

  static Future<void> _guard(Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      AppLogger.w('PostHog call failed', e);
    }
  }

  /// PostHog không nhận `null` / chuỗi rỗng.
  static Map<String, Object> _clean(Map<String, Object?> properties) => {
    for (final e in properties.entries)
      if (e.value != null && e.value != '') e.key: e.value!,
  };
}
