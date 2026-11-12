import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../domain/entities/account_entities.dart';
import '../bloc/lion_points/lion_points_bloc.dart';

/// Lịch sử Lion Points — số dư + giao dịch cộng/trừ (web `/buyer/lion-point/history`).
class LionPointsPage extends StatefulWidget {
  const LionPointsPage({super.key});

  @override
  State<LionPointsPage> createState() => _LionPointsPageState();
}

class _LionPointsPageState extends State<LionPointsPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final p = _scroll.position;
      if (p.pixels >= p.maxScrollExtent - 300) {
        context.read<LionPointsBloc>().add(const LionPointsLoadMore());
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Tiêu đề theo loại/nguồn như web `HistoryItemList`. Dòng khác loại: web lấy
  /// `idempotencyKey` (chuỗi kỹ thuật) → app giữ nhãn dễ đọc theo `type`.
  static String _title(LionLedgerItem item) => switch (item.kind) {
    LionLedgerKind.referral => LocaleKeys.accountPointsReferral.tr(),
    LionLedgerKind.purchase => LocaleKeys.accountPointsPurchase.tr(),
    LionLedgerKind.redemption => LocaleKeys.accountPointsSpent.tr(),
    LionLedgerKind.other =>
      item.type == LionLedgerType.expired
          ? LocaleKeys.accountPointsExpired.tr()
          : LocaleKeys.accountPointsEarned.tr(),
  };

  /// Mô tả như web: số điểm trong câu (redemption lấy trị tuyệt đối), khác loại = `reason`.
  static String _description(LionLedgerItem item, NumberFormat format) =>
      switch (item.kind) {
        LionLedgerKind.referral => LocaleKeys.accountPointsReferralDesc.tr(
          args: [format.format(item.amount)],
        ),
        LionLedgerKind.purchase => LocaleKeys.accountPointsPurchaseDesc.tr(
          args: [format.format(item.amount)],
        ),
        LionLedgerKind.redemption => LocaleKeys.accountPointsRedemptionDesc.tr(
          args: [format.format(item.amount.abs())],
        ),
        LionLedgerKind.other => item.reason,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.toString();
    return Scaffold(
      backgroundColor: theme.surface(context),
      appBar: AppBar(
        backgroundColor: theme.surface(context),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: AppIcon(AppSvg.arrowBack, size: 24.r),
        ),
        title: Text(
          LocaleKeys.accountPointsHistoryTitle.tr(),
          style: AppTextStyle.lightBodyXLargeBold,
        ),
      ),
      body: BlocBuilder<LionPointsBloc, LionPointsState>(
        builder: (context, state) {
          if (state.status == LionPointsStatus.loading) {
            return const Center(child: CupertinoActivityIndicator());
          }
          final format = NumberFormat.decimalPattern(locale);
          return RefreshIndicator(
            onRefresh: () async =>
                context.read<LionPointsBloc>().add(const LionPointsStarted()),
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16.r),
              children: [
                if (state.wallet != null)
                  Text(
                    LocaleKeys.accountPointsAvailable.tr(
                      args: [format.format(state.wallet!.points)],
                    ),
                    style: AppTextStyle.lightHeadingSmall.copyWith(
                      color: theme.textPrimary(context),
                    ),
                  ),
                if (state.wallet?.showsExpiry ?? false) ...[
                  Gap(4.h),
                  Text(
                    LocaleKeys.accountPointsExpiry.tr(
                      args: [
                        format.format(state.wallet!.expiringPoints),
                        DateFormat.yMMMd(
                          locale,
                        ).format(state.wallet!.expiresAt!),
                      ],
                    ),
                    style: AppTextStyle.lightBodyMediumRegular.copyWith(
                      color: theme.textSecondary(context),
                    ),
                  ),
                ],
                Gap(12.h),
                if (state.items.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 48.h),
                    child: Text(
                      state.status == LionPointsStatus.failure
                          ? LocaleKeys.accountPointsLoadError.tr()
                          : LocaleKeys.accountPointsEmpty.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyle.lightBodyMediumRegular.copyWith(
                        color: theme.textSecondary(context),
                      ),
                    ),
                  ),
                for (final item in state.items)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _title(item),
                                style: AppTextStyle.lightBodyMediumSemiBold
                                    .copyWith(
                                      color: theme.textPrimary(context),
                                    ),
                              ),
                              if (_description(item, format).isNotEmpty)
                                Text(
                                  _description(item, format),
                                  style: AppTextStyle.lightBodySmallRegular
                                      .copyWith(
                                        color: theme.textSecondary(context),
                                      ),
                                ),
                              if (item.at != null)
                                Text(
                                  DateFormat.yMMMd(
                                    locale,
                                  ).add_Hm().format(item.at!),
                                  style: AppTextStyle.lightBodySmallRegular
                                      .copyWith(
                                        color: theme.textTertiary(context),
                                      ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${item.amount > 0 ? '+' : ''}${format.format(item.amount)}',
                          style: AppTextStyle.lightBodyMediumBold.copyWith(
                            color: item.amount > 0
                                ? Colour.success
                                : theme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (state.isLoadingMore)
                  const Center(child: CupertinoActivityIndicator()),
              ],
            ),
          );
        },
      ),
    );
  }
}
