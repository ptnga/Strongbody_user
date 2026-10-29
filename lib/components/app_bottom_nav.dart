import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_badge_notifier.dart';
import 'package:strongbody_buyer/modules/home/presentation/new_offers_badge_notifier.dart';

enum AppTab { home, requests, messages, account }

/// Thanh dưới: Home · Requests · nút "Speak" nổi ở giữa · Messages · Account.
///
/// Home → `go('/')` (về trang đầu, bỏ hết màn phía trên). Speak → màn ghi âm, luồng
/// đăng request như từ Home. Messages / Account → tab tương ứng.
///
/// Badge: Requests = [NewOffersBadgeNotifier], Messages = [ChatBadgeNotifier] (tải lại mỗi
/// lần thanh hiện).
class AppBottomNav extends StatefulWidget {
  final AppTab current;

  const AppBottomNav({super.key, required this.current});

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  AppTab get current => widget.current;

  @override
  void initState() {
    super.initState();
    getIt<NewOffersBadgeNotifier>().refresh();
    getIt<ChatBadgeNotifier>().refresh();
  }

  void _select(BuildContext context, AppTab tab) {
    if (tab == current) return;
    switch (tab) {
      case AppTab.home:
        context.go(RouteName.rootScreen);
      case AppTab.requests:
        context.go(RouteName.myRequests);
      case AppTab.messages:
        context.go(RouteName.messages);
      case AppTab.account:
        context.go(RouteName.account);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.surface(context),
        border: Border(top: BorderSide(color: theme.border(context))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60.h,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                label: LocaleKeys.navHome.tr(),
                selected: current == AppTab.home,
                onTap: () => _select(context, AppTab.home),
              ),
              ValueListenableBuilder<int>(
                valueListenable: getIt<NewOffersBadgeNotifier>(),
                builder: (context, count, _) => _NavItem(
                  icon: Icons.move_to_inbox_outlined,
                  label: LocaleKeys.navRequests.tr(),
                  badge: count,
                  selected: current == AppTab.requests,
                  onTap: () => _select(context, AppTab.requests),
                ),
              ),
              Expanded(
                child: _SpeakButton(
                  onTap: () => context.push(RouteName.voiceRequest),
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: getIt<ChatBadgeNotifier>(),
                builder: (context, unread, _) => _NavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: LocaleKeys.navMessages.tr(),
                  badge: unread,
                  selected: current == AppTab.messages,
                  onTap: () => _select(context, AppTab.messages),
                ),
              ),
              _NavItem(
                icon: Icons.account_circle_outlined,
                label: LocaleKeys.navAccount.tr(),
                selected: current == AppTab.account,
                onTap: () => _select(context, AppTab.account),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.textPrimary(context)
        : theme.textSecondary(context);
    final count = badge ?? 0;
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 32.r,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 24.r, color: color),
                if (count > 0)
                  Positioned(
                    right: -8.w,
                    top: -5.h,
                    child: Container(
                      constraints: BoxConstraints(minWidth: 16.r),
                      height: 16.r,
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.textPrimary(context),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: theme.surface(context),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: TextStyle(
                          fontSize: 9.sp,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Gap(4.h),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút mic đỏ nổi lên trên thanh, viền trắng + quầng đỏ nhạt.
class _SpeakButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SpeakButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = 58.r;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: -26.h,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: theme.primary(context),
                shape: BoxShape.circle,
                border: Border.all(color: theme.surface(context), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: theme.primary(context).withValues(alpha: 0.28),
                    blurRadius: 0,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: theme.primary(context).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.mic_none_rounded,
                size: 26.r,
                color: Colors.white,
                semanticLabel: LocaleKeys.navSpeak.tr(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Text(
              LocaleKeys.navSpeak.tr(),
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: theme.primary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
