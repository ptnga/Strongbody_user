import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/components/strongbody_logo.dart';
import 'package:strongbody_buyer/modules/splash/presentation/screens/splash_page.dart';

void main() {
  testWidgets('splash shows logo then goes Home after min duration', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: RouteName.splash,
      routes: [
        GoRoute(path: RouteName.splash, builder: (_, _) => const SplashPage()),
        GoRoute(
          path: RouteName.rootScreen,
          builder: (_, _) => const Text('home'),
        ),
      ],
    );
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    expect(find.byType(StrongBodyLogo), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.pump(
      SplashPage.minDuration - const Duration(milliseconds: 100),
    );
    expect(find.text('home'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.byType(SplashPage), findsNothing);
  });
}
