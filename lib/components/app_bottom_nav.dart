import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_badge_notifier.dart';
import 'package:strongbody_buyer/modules/home/presentation/new_offers_badge_notifier.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/voice_request_page_args.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import 'app_nav_icons.dart';

/// Thứ tự = thứ tự branch của `StatefulShellRoute` trong router.
enum AppTab {
  home(RouteName.rootScreen),
  requests(RouteName.myRequests),
  messages(RouteName.messages),
  account(RouteName.account);

  const AppTab(this.location);

  final String location;
}

/// Khung tab (như Multime `ApplicationPage` + `LazyIndexedStack`): mỗi tab một navigator
/// riêng, mở lần đầu mới build, sau đó giữ nguyên bloc / vị trí cuộn khi chuyển tab.
///
/// Prototype: Home không có thanh dưới; Requests · Messages · Account có. Back ở tab
/// khác Home → về Home.
class AppTabShell extends StatefulWidget {
  final StatefulNavigationShell shell;

  const AppTabShell({super.key, required this.shell});

  /// Tab đang mở — trang nghe để làm mới khi được mở lại ([TabActivation]).
  static final active = ValueNotifier<AppTab>(AppTab.home);

  @override
  State<AppTabShell> createState() => _AppTabShellState();
}

class _AppTabShellState extends State<AppTabShell> {
  AppTab get _tab => AppTab.values[widget.shell.currentIndex];

  /// Nền lộ ra ở chỗ cong quanh nút Speak = nền trang của tab.
  static const _tabBackground = {
    AppTab.requests: Color(0xFFF4F6F9),
    AppTab.account: Color(0xFFF4F6F9),
  };

  @override
  void initState() {
    super.initState();
    _activate(_tab);
  }

  @override
  void didUpdateWidget(covariant AppTabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shell.currentIndex != widget.shell.currentIndex) {
      _activate(_tab);
    }
  }

  void _activate(AppTab tab) {
    // Không báo listener giữa lúc build.
    scheduleMicrotask(() => AppTabShell.active.value = tab);
    AppAnalytics.screen(tab == AppTab.home ? 'home' : tab.location);
    if (tab != AppTab.home) {
      getIt<NewOffersBadgeNotifier>().refresh();
      getIt<ChatBadgeNotifier>().refresh();
    }
  }

  void _select(AppTab tab) => widget.shell.goBranch(tab.index);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tab = _tab;
    final showBar = tab != AppTab.home;
    return PopScope(
      canPop: !showBar,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(AppTab.home);
      },
      child: Scaffold(
        backgroundColor: _tabBackground[tab] ?? theme.surface(context),
        resizeToAvoidBottomInset: false,
        body: widget.shell,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: showBar
            ? _SpeakButton(
                onTap: () => context.push(
                  RouteName.voiceRequest,
                  extra: const VoiceRequestPageArgs(source: 'bottom_nav'),
                ),
              )
            : null,
        bottomNavigationBar: showBar
            ? AppBottomNav(current: tab, onSelect: _select)
            : null,
      ),
    );
  }
}

/// Chạy [onActivated] mỗi lần tab [tab] được mở lại (không chạy lần build đầu — bloc đã
/// tự tải khi tạo). Dùng để làm mới ngầm dữ liệu của tab đang được giữ.
class TabActivation extends StatefulWidget {
  final AppTab tab;
  final void Function(BuildContext context) onActivated;
  final Widget child;

  const TabActivation({
    super.key,
    required this.tab,
    required this.onActivated,
    required this.child,
  });

  @override
  State<TabActivation> createState() => _TabActivationState();
}

class _TabActivationState extends State<TabActivation> {
  // Lần build đầu = đang mở tab này (bloc vừa tự tải) → không bắn lại khi `active` cập nhật.
  late AppTab _last = widget.tab;

  @override
  void initState() {
    super.initState();
    AppTabShell.active.addListener(_onTab);
  }

  @override
  void dispose() {
    AppTabShell.active.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    final tab = AppTabShell.active.value;
    if (tab == widget.tab && _last != widget.tab && mounted) {
      widget.onActivated(context);
    }
    _last = tab;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Thanh dưới: Home · Requests · [chỗ cong cho nút Speak] · Messages · Account.
/// Kiểu Multime `ApplicationBottomBar` (chỗ cong ôm nút giữa, splash đỏ, đổ bóng); icon,
/// màu, badge theo prototype.
class AppBottomNav extends StatelessWidget {
  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  const AppBottomNav({
    super.key,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      color: theme.surface(context),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      padding: EdgeInsets.zero,
      height: 64.h,
      child: Row(
        children: [
          _NavItem(
            icon: AppNavIcon.home,
            label: LocaleKeys.navHome.tr(),
            selected: current == AppTab.home,
            onTap: () => onSelect(AppTab.home),
          ),
          ValueListenableBuilder<int>(
            valueListenable: getIt<NewOffersBadgeNotifier>(),
            builder: (context, count, _) => _NavItem(
              icon: AppNavIcon.inbox,
              label: LocaleKeys.navRequests.tr(),
              badge: count,
              selected: current == AppTab.requests,
              onTap: () => onSelect(AppTab.requests),
            ),
          ),
          // Chỗ của nút Speak (nổi trong chỗ cong) + nhãn bên dưới.
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 9.h),
                child: Text(
                  LocaleKeys.navSpeak.tr(),
                  maxLines: 1,
                  style: AppTextStyle.lightBodyXSmallSemiBold.copyWith(
                    color: _SpeakButton.labelColor,
                  ),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: getIt<ChatBadgeNotifier>(),
            builder: (context, unread, _) => _NavItem(
              icon: AppNavIcon.chat,
              label: LocaleKeys.navMessages.tr(),
              badge: unread,
              selected: current == AppTab.messages,
              onTap: () => onSelect(AppTab.messages),
            ),
          ),
          _NavItem(
            icon: AppNavIcon.user,
            label: LocaleKeys.navAccount.tr(),
            selected: current == AppTab.account,
            onTap: () => onSelect(AppTab.account),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final AppNavIcon icon;
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
    // Prototype: đang chọn #1F2C43 / nét 2 / chữ 600; còn lại #667085 / nét 1.6 / chữ 500.
    final color = selected
        ? theme.secondary(context)
        : theme.textSecondary(context);
    final count = badge ?? 0;
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 30.r,
        splashColor: theme.primary(context).withValues(alpha: 0.1),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: selected ? 1.08 : 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: AppNavIconView(
                    icon,
                    size: 24.r,
                    color: color,
                    strokeWidth: selected ? 2 : 1.6,
                  ),
                ),
                if (count > 0)
                  Positioned(
                    left: 14.r,
                    top: -6.r,
                    child: Container(
                      constraints: BoxConstraints(minWidth: 18.r),
                      height: 18.r,
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.secondary(context),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: theme.surface(context),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: AppTextStyle.lightBodyXSmallSemiBold.copyWith(
                          height: 1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 3.h),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTextStyle.lightBodyXSmallRegular.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút mic đỏ trong chỗ cong, có vòng sóng lan ra (Multime `PulsingCenterButton`).
class _SpeakButton extends StatefulWidget {
  final VoidCallback onTap;

  const _SpeakButton({required this.onTap});

  static const labelColor = Color(0xFFBF0013);

  @override
  State<_SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<_SpeakButton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final red = Theme.of(context).primary(context);
    final size = 56.r;
    // Kích thước widget = nút (chỗ cong ôm vừa); sóng vẽ tràn ra ngoài.
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [for (var i = 0; i < 3; i++) _ring(red, size, i)],
              ),
            ),
          ),
          Material(
            color: red,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: red.withValues(alpha: 0.45),
            child: InkWell(
              customBorder: const CircleBorder(),
              splashColor: Colors.white.withValues(alpha: 0.2),
              onTap: widget.onTap,
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  child: AppNavIconView(
                    AppNavIcon.mic,
                    size: 26.r,
                    color: Colors.white,
                    strokeWidth: 1.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(Color red, double size, int i) {
    final t = (_pulse.value + i / 3) % 1;
    final opacity = (1 - t) * (1 - t) * 0.4;
    final ring = size + 20.r * t;
    return OverflowBox(
      maxWidth: ring,
      maxHeight: ring,
      child: Container(
        width: ring,
        height: ring,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: red.withValues(alpha: opacity * 0.35),
          border: Border.all(color: red.withValues(alpha: opacity), width: 1.5),
        ),
      ),
    );
  }
}
