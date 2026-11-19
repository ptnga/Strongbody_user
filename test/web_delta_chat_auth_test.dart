import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/modules/chat/data/mappers/chat_mapper.dart';
import 'package:strongbody_buyer/modules/chat/domain/entities/chat_message_entity.dart';
import 'package:strongbody_buyer/modules/chat/domain/repositories/chat_repository.dart';
import 'package:strongbody_buyer/modules/chat/domain/usecases/chat_use_cases.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_badge_notifier.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_formatters.dart';
import 'package:strongbody_buyer/modules/chat/presentation/widgets/chat_card_view.dart';

/// Web live-v1 5141e6132..df3c3b780 — chat / nav shell deltas:
/// 8511e5f03 Messenger-style timestamps · acb552dcc request card action only for the
/// request owner · 15845e0f9 service card fallback image · 69d816b6c unread badge polling.

const _me = 7;

class _Storage implements GlobalStorage {
  bool loggedIn = true;
  @override
  bool get isLoggedIn => loggedIn;
  @override
  int? get userId => _me;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnreadRepo implements ChatRepository {
  int calls = 0;
  int total = 3;

  @override
  Future<Either<Failure, int>> getUnreadTotal() async {
    calls++;
    return Right(total);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  group('Messenger-style timestamps (web 8511e5f03)', () {
    final now = DateTime(2026, 11, 19, 15, 30); // Thursday

    test('a new cluster starts after >= 1 hour of silence', () {
      final t = DateTime(2026, 11, 19, 10);
      expect(ChatFormatters.startsCluster(null, t), isTrue);
      expect(
        ChatFormatters.startsCluster(t, t.add(const Duration(minutes: 59))),
        isFalse,
      );
      expect(
        ChatFormatters.startsCluster(t, t.add(const Duration(hours: 1))),
        isTrue,
      );
    });

    test('separator: today / within 7 days / same year / other year', () {
      String f(DateTime d) => ChatFormatters.separatorTime(d, 'en', now: now);
      expect(f(DateTime(2026, 11, 19, 10, 42)), '10:42');
      expect(f(DateTime(2026, 11, 16, 9, 5)), 'Mon 09:05');
      // 6 ngày trước vẫn là thứ; 7 ngày trước sang ngày tháng.
      expect(f(DateTime(2026, 11, 13, 8)), 'Fri 08:00');
      expect(f(DateTime(2026, 11, 12, 8)), '12 Nov, 08:00');
      expect(f(DateTime(2025, 3, 2, 21, 15)), '2 Mar 2025, 21:15');
    });

    test('full time shown when a bubble is tapped', () {
      expect(
        ChatFormatters.fullTime(DateTime(2026, 11, 17, 10, 42), 'en'),
        'Tuesday, November 17, 2026 10:42',
      );
    });
  });

  group('Request card action (web acb552dcc)', () {
    ChatCardEntity card({int? buyerId}) =>
        ChatCardEntity(kind: ChatCardKind.request, buyerId: buyerId);

    test('buyerId is read from the request payload', () {
      final message = ChatMapper.message(
        timetoken: '17300000000000010',
        publisher: '42',
        payload: {
          'type': 'request',
          'uuid': 42,
          'request': {'id': 5, 'description': 'Physio', 'buyerId': _me},
        },
        myUserId: _me,
      )!;
      expect(message.card!.buyerId, _me);
    });

    test('only the request owner (receiver) gets "Go to my requests"', () {
      bool shows(ChatCardEntity c, {bool mine = false}) =>
          ChatCardView.showsMyRequestsAction(c, mine: mine, myUserId: _me);
      expect(shows(card(buyerId: _me)), isTrue);
      // Tin cũ không có buyerId: provider → người đăng request.
      expect(shows(card()), isTrue);
      // Request của người khác gửi tới mình (phía provider): không có nút.
      expect(shows(card(buyerId: 99)), isFalse);
      expect(shows(card(buyerId: _me), mine: true), isFalse);
      expect(shows(const ChatCardEntity(kind: ChatCardKind.service)), isFalse);
    });
  });

  group('ChatCardView', () {
    Future<void> pump(WidgetTester tester, ChatCardEntity card) =>
        tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(375, 812),
            child: MaterialApp(
              home: Scaffold(
                body: ChatCardView(card: card, mine: false, myUserId: _me),
              ),
            ),
          ),
        );

    testWidgets('service without a photo shows the shared fallback image '
        '(web 15845e0f9)', (tester) async {
      await pump(
        tester,
        const ChatCardEntity(kind: ChatCardKind.service, title: 'Massage'),
      );
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('request from someone else: no my-requests button', (
      tester,
    ) async {
      await pump(
        tester,
        const ChatCardEntity(kind: ChatCardKind.request, buyerId: 99),
      );
      expect(find.text('chatCardOpenMyRequests'), findsNothing);
      await pump(
        tester,
        const ChatCardEntity(kind: ChatCardKind.request, buyerId: _me),
      );
      expect(find.text('chatCardOpenMyRequests'), findsOneWidget);
    });
  });

  group('Unread messages badge (web 69d816b6c MessagesBadge)', () {
    testWidgets('polls every 10 s while signed in', (tester) async {
      final repo = _UnreadRepo();
      final storage = _Storage();
      final badge = ChatBadgeNotifier(
        getUnreadTotal: GetChatUnreadTotalUseCase(repo),
        storage: storage,
        pollInterval: ChatBadgeNotifier.webPollInterval,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.calls, 1);
      expect(badge.value, 3);

      repo.total = 5;
      await tester.pump(const Duration(seconds: 10));
      expect(repo.calls, 2);
      expect(badge.value, 5);

      storage.loggedIn = false;
      await tester.pump(const Duration(seconds: 30));
      expect(repo.calls, 2);
      badge.dispose();
    });

    testWidgets('no polling unless asked (default)', (tester) async {
      final repo = _UnreadRepo();
      final badge = ChatBadgeNotifier(
        getUnreadTotal: GetChatUnreadTotalUseCase(repo),
        storage: _Storage(),
      );
      await tester.pump(const Duration(seconds: 30));
      expect(repo.calls, 1);
      badge.dispose();
    });
  });
}
