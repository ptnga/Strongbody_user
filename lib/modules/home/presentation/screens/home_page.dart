import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_feed_entities.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/engagement/engagement_cubit.dart';

import '../../domain/entities/board_entities.dart';
import '../bloc/board/board_cubit.dart';
import '../bloc/home_menu/home_menu_cubit.dart';
import '../widgets/board/board_offer_row.dart';
import '../widgets/board/board_request_card.dart';
import '../widgets/board/board_view.dart';
import '../widgets/home_menu_drawer.dart';
import '../widgets/home_top_bar.dart';

/// Trang chủ (web `MarketplacePage`): không còn hero chatbot — mở đầu bằng thanh tab
/// Requests · Offers (mobile). Request cộng đồng (Me too / Like / Save) và dịch vụ
/// (Book / Free consult); đăng yêu cầu bằng nút "Get help" ở thanh dưới.
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
        BlocProvider(
          create: (_) => getIt<BoardCubit<BoardOffer>>()..start(locale: locale),
        ),
        BlocProvider(
          create: (_) =>
              getIt<EngagementCubit>(param1: EngagementTarget.request),
        ),
      ],
      child: DefaultTabController(
        length: 2,
        child: Builder(
          builder: (context) => GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Scaffold(
              backgroundColor: Colour.mutedWeb,
              drawer: const HomeMenuDrawer(),
              onDrawerChanged: (open) {
                if (open) context.read<HomeMenuCubit>().load();
              },
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const ColoredBox(
                      color: Colour.surface,
                      child: HomeTopBar(),
                    ),
                    ColoredBox(
                      color: Colour.surface,
                      child: TabBar(
                        labelColor: Colour.textPrimary,
                        unselectedLabelColor: Colour.textSecondary,
                        labelStyle: AppTextStyle.lightBodyMediumSemiBold,
                        unselectedLabelStyle:
                            AppTextStyle.lightBodyMediumMedium,
                        indicatorColor: Colour.textPrimary,
                        indicatorSize: TabBarIndicatorSize.label,
                        dividerColor: Colour.border,
                        tabs: [
                          Tab(
                            height: 44.h,
                            text: LocaleKeys.boardTabRequests.tr(),
                          ),
                          Tab(
                            height: 44.h,
                            text: LocaleKeys.boardTabOffers.tr(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          BoardView<BoardRequest>(
                            kind: BoardKind.requests,
                            onItems: (items) => context
                                .read<EngagementCubit>()
                                .load(items.map((r) => r.id)),
                            itemBuilder: (context, r) =>
                                BoardRequestCard(request: r),
                          ),
                          BoardView<BoardOffer>(
                            kind: BoardKind.offers,
                            itemBuilder: (context, o) =>
                                BoardOfferRow(offer: o),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
