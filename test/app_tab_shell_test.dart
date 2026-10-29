import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/components/app_bottom_nav.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_badge_notifier.dart';
import 'package:strongbody_buyer/modules/home/presentation/new_offers_badge_notifier.dart';

class _Badge extends ValueNotifier<int>
    implements NewOffersBadgeNotifier, ChatBadgeNotifier {
  _Badge() : super(0);

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Trang tab đếm số lần được tạo + giữ một bộ đếm trong state.
class _TabPage extends StatefulWidget {
  final String name;
  static final created = <String, int>{};

  const _TabPage(this.name);

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage> {
  int taps = 0;

  @override
  void initState() {
    super.initState();
    _TabPage.created.update(widget.name, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => taps++),
      child: Text('${widget.name} $taps'),
    ),
  );
}

void main() {
  setUpAll(() {
    final badge = _Badge();
    GetIt.I
      ..registerSingleton<NewOffersBadgeNotifier>(badge)
      ..registerSingleton<ChatBadgeNotifier>(badge);
  });

  testWidgets('switching tabs keeps each tab state (no rebuild / reload)', (
    tester,
  ) async {
    final activations = <AppTab>[];
    GoRoute tab(AppTab t, String name) => GoRoute(
      path: t.location,
      builder: (_, _) => TabActivation(
        tab: t,
        onActivated: (_) => activations.add(t),
        child: _TabPage(name),
      ),
    );
    final router = GoRouter(
      initialLocation: AppTab.requests.location,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => AppTabShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [tab(AppTab.home, 'home')]),
            StatefulShellBranch(routes: [tab(AppTab.requests, 'requests')]),
            StatefulShellBranch(routes: [tab(AppTab.messages, 'messages')]),
            StatefulShellBranch(routes: [tab(AppTab.account, 'account')]),
          ],
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
    await tester.pump(const Duration(milliseconds: 100));

    // Bar hiện ở tab Requests; tăng bộ đếm.
    expect(find.byType(AppBottomNav), findsOneWidget);
    await tester.tap(find.text('requests 0'));
    await tester.pump();
    expect(find.text('requests 1'), findsOneWidget);

    // Sang Messages rồi quay lại Requests: state còn, trang không tạo lại.
    router.go(AppTab.messages.location);
    await tester.pump();
    await tester.pump();
    expect(find.text('messages 0'), findsOneWidget);
    router.go(AppTab.requests.location);
    await tester.pump();
    await tester.pump();
    expect(find.text('requests 1'), findsOneWidget);
    expect(_TabPage.created['requests'], 1);
    // Mở lần đầu không bắn (bloc tự tải); mở lại mới bắn đúng 1 lần.
    expect(activations, [AppTab.requests]);

    // Back (Android) ở tab khác Home → về Home, không thoát app.
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump();
    expect(find.text('home 0'), findsOneWidget);
    // Home: không có thanh dưới (prototype).
    expect(find.byType(AppBottomNav), findsNothing);

    // Bấm tab trên thanh: Account → bar đánh dấu đúng tab, nút Speak hiện.
    router.go(AppTab.messages.location);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('navAccount'));
    await tester.pump();
    await tester.pump();
    expect(find.text('account 0'), findsOneWidget);
    expect(
      tester.widget<AppBottomNav>(find.byType(AppBottomNav)).current,
      AppTab.account,
    );
    expect(find.text('navSpeak'), findsOneWidget);
  });
}
