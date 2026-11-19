import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_feed_entities.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/engagement/engagement_cubit.dart';

import '../../domain/entities/board_entities.dart';
import '../bloc/board/board_cubit.dart';
import '../bloc/board_stats/board_stats_cubit.dart';
import '../bloc/home_menu/home_menu_cubit.dart';
import '../widgets/board/home_requests_feed.dart';
import '../widgets/home_menu_drawer.dart';
import '../widgets/home_top_bar.dart';

/// Trang chủ (web `MarketplacePage` mobile): hero ảnh đội ngũ chuyên gia → số liệu tuần này
/// → feed "Typical requests" (Me too / Save). Không còn tab Requests · Offers: bảng Offers ở
/// trang riêng (menu ☰ → Offers); đăng yêu cầu bằng nút "Get help" ở thanh dưới.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<HomeMenuCubit>()),
        BlocProvider(
          create: (_) =>
              getIt<BoardCubit<BoardRequest>>()..start(locale: locale),
        ),
        BlocProvider(create: (_) => getIt<BoardStatsCubit>()..load()),
        BlocProvider(
          create: (_) =>
              getIt<EngagementCubit>(param1: EngagementTarget.request),
        ),
      ],
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colour.mutedWeb,
          drawer: const HomeMenuDrawer(),
          onDrawerChanged: (open) {
            if (open) context.read<HomeMenuCubit>().load();
          },
          body: const SafeArea(
            bottom: false,
            child: Column(
              children: [
                ColoredBox(color: Colour.surface, child: HomeTopBar()),
                Divider(height: 1, color: Colour.border),
                Expanded(child: HomeRequestsFeed()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
