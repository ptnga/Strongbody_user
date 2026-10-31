import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/modules/auth/presentation/widgets/auth_sheet.dart';

import '../../domain/entities/market_feed_entities.dart';
import '../bloc/engagement/engagement_cubit.dart';
import '../market_formatters.dart';
import 'market_ui.dart';

/// Like / save của một item, nối [EngagementCubit] gần nhất (web `IconToggle`).
/// Khách bấm → mở popup đăng nhập ngay trong trang (web `openAuth('login')`).
class MarketEngagementButtons extends StatelessWidget {
  final int? id;
  final bool showLike;
  final bool showSave;

  const MarketEngagementButtons({
    super.key,
    required this.id,
    this.showLike = false,
    this.showSave = true,
  });

  void _toggle(BuildContext context, EngagementKind kind) {
    final cubit = context.read<EngagementCubit>();
    final targetId = id;
    if (targetId == null) return;
    if (!cubit.isLoggedIn) {
      showAuthSheet(context, source: 'social_market_${kind.name}');
      return;
    }
    cubit.toggle(targetId, kind);
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<EngagementCubit, EngagementCubitState>(
        buildWhen: (a, b) =>
            a.of(id) != b.of(id) ||
            a.isPending(id, EngagementKind.like) !=
                b.isPending(id, EngagementKind.like) ||
            a.isPending(id, EngagementKind.save) !=
                b.isPending(id, EngagementKind.save),
        builder: (context, state) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLike)
              EngagementToggle(
                like: true,
                on: state.of(id).liked,
                busy: state.isPending(id, EngagementKind.like),
                onTap: () => _toggle(context, EngagementKind.like),
              ),
            if (showSave)
              EngagementToggle(
                like: false,
                on: state.of(id).saved,
                busy: state.isPending(id, EngagementKind.save),
                onTap: () => _toggle(context, EngagementKind.save),
              ),
          ],
        ),
      );
}

/// "N interested · N saved · N contacted"; chưa có số nào vẫn giữ chỗ 1 dòng
/// (web `EngagementCounts`) để lần lưu đầu không làm card cao thêm.
class MarketEngagementLine extends StatelessWidget {
  final int? id;
  final bool hideLikes;
  final TextStyle style;

  const MarketEngagementLine({
    super.key,
    required this.id,
    required this.style,
    this.hideLikes = false,
  });

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<EngagementCubit, EngagementCubitState>(
        buildWhen: (a, b) => a.of(id) != b.of(id),
        builder: (context, state) => Text(
          MarketFormatters.engagement(state.of(id), hideLikes: hideLikes),
          style: style,
        ),
      );
}
