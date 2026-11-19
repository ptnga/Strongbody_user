import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/widgets/voice/get_help_sheet.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/engagement/engagement_cubit.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_ui.dart';

import '../../../domain/entities/board_entities.dart';
import '../../bloc/board/board_cubit.dart';
import '../../bloc/board_stats/board_stats_cubit.dart';
import 'board_request_card.dart';
import 'home_hero.dart';
import 'recently_matched.dart';
import 'requests_intro.dart';

/// Trang chủ mobile (web `MarketplacePage` + `HomeRequestsLoader`): hero ảnh → card số liệu
/// tuần này + cam kết → "Typical requests" → feed card request gọn (cuộn tự tải 10 / lần),
/// khối "Recently matched" chen sau card thứ 3. Không ô tìm kiếm / Filters / chủ đề; bảng
/// Offers ở trang riêng (menu ☰ → Offers).
class HomeRequestsFeed extends StatefulWidget {
  const HomeRequestsFeed({super.key});

  /// Card gọn: khối "Recently matched" chen sau card thứ mấy (ít hơn → cuối danh sách).
  static const matchedAfter = 3;

  @override
  State<HomeRequestsFeed> createState() => _HomeRequestsFeedState();
}

class _HomeRequestsFeedState extends State<HomeRequestsFeed> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final p = _scroll.position;
      // Như web: tải trước khi chạm đáy (~800px).
      if (p.pixels >= p.maxScrollExtent - 800) {
        context.read<BoardCubit<BoardRequest>>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() => Future.wait([
    context.read<BoardCubit<BoardRequest>>().retry(),
    context.read<BoardStatsCubit>().load(),
  ]);

  @override
  Widget build(BuildContext context) {
    return BlocListener<BoardCubit<BoardRequest>, BoardState<BoardRequest>>(
      listenWhen: (a, b) => a.items != b.items,
      // Engagement (đếm + trạng thái + người vừa đề xuất) nạp theo lô cho id mới tải.
      listener: (context, state) =>
          context.read<EngagementCubit>().load(state.items.map((r) => r.id)),
      child: BlocBuilder<BoardCubit<BoardRequest>, BoardState<BoardRequest>>(
        builder: (context, state) {
          final stats = context.watch<BoardStatsCubit>().state.stats;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: 96.h),
              children: [
                const HomeHero(),
                Gap(8.h),
                RequestsIntro(stats: stats),
                Gap(16.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _content(state, stats),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _content(BoardState<BoardRequest> state, BoardStats? stats) {
    final cubit = context.read<BoardCubit<BoardRequest>>();
    if (state.isFirstLoad) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32.h),
          child: const Center(child: CupertinoActivityIndicator()),
        ),
      ];
    }
    if (state.status == BoardStatus.failure) {
      return [
        MarketSectionError(
          title: LocaleKeys.boardSectionError.tr(),
          onRetry: cubit.retry,
        ),
      ];
    }
    if (state.items.isEmpty) return const [_EmptyRequests()];
    final items = state.items;
    final matchedAt =
        (items.length < HomeRequestsFeed.matchedAfter
            ? items.length
            : HomeRequestsFeed.matchedAfter) -
        1;
    final matched = RecentlyMatched.visible(stats?.recentMatched ?? const []);
    return [
      for (final (i, r) in items.indexed) ...[
        if (i > 0) Gap(12.h),
        // Key theo id: lô mới nối thêm không dựng lại card cũ (giữ trạng thái mở rộng).
        BoardRequestCard(key: ValueKey(r.id), request: r),
        if (i == matchedAt && matched.isNotEmpty && !state.isSearching) ...[
          Gap(12.h),
          RecentlyMatched(items: matched),
        ],
      ],
      if (state.loadingMore)
        Padding(
          padding: EdgeInsets.only(top: 16.h),
          child: const Center(child: CupertinoActivityIndicator()),
        )
      else if (state.loadMoreFailed)
        Padding(
          padding: EdgeInsets.only(top: 16.h),
          child: Column(
            children: [
              Text(
                LocaleKeys.boardFeedError.tr(),
                style: AppTextStyle.lightBodySmallRegular.copyWith(
                  color: Colour.textSecondary,
                ),
              ),
              Gap(8.h),
              OutlinedButton(
                onPressed: cubit.loadMore,
                child: Text(LocaleKeys.boardFeedRetry.tr()),
              ),
            ],
          ),
        ),
    ];
  }
}

/// Chưa có request nào (web `BoardEmpty`): mời đăng nhu cầu của mình.
class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(20.r),
    decoration: BoxDecoration(
      color: Colour.surface,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(color: Colour.border),
    ),
    child: Column(
      children: [
        Icon(
          Icons.travel_explore_rounded,
          size: 32.r,
          color: Colour.textTertiary,
        ),
        Gap(10.h),
        Text(
          LocaleKeys.boardEmptyRequestsAll.tr(),
          textAlign: TextAlign.center,
          style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
            color: Colour.textPrimary,
          ),
        ),
        Gap(6.h),
        Text(
          LocaleKeys.boardEmptyHint.tr(),
          textAlign: TextAlign.center,
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            color: Colour.textSecondary,
          ),
        ),
        Gap(16.h),
        MarketButton(
          label: '+ ${LocaleKeys.boardRequestsPost.tr()}',
          onPressed: () => showGetHelpSheet(context, source: 'home_board'),
        ),
      ],
    ),
  );
}
