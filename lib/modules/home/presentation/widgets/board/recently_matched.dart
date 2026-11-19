import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_ui.dart';

import '../../../domain/entities/board_entities.dart';

/// "Recently matched" (web `RecentlyMatched`): vài request công khai mới nhất đã có chuyên gia
/// phản hồi (API board-stats), chen giữa feed card gọn. Chỉ request đã phân loại dịch vụ
/// (nhãn = tên dịch vụ); không có → không hiện.
class RecentlyMatched extends StatelessWidget {
  final List<BoardMatchedItem> items;

  const RecentlyMatched({super.key, required this.items});

  /// Số dòng hiện trong khối.
  static const rows = 3;

  static List<BoardMatchedItem> visible(List<BoardMatchedItem> items) =>
      items.where((i) => i.service.trim().isNotEmpty).take(rows).toList();

  @override
  Widget build(BuildContext context) {
    final shown = visible(items);
    if (shown.isEmpty) return const SizedBox.shrink();
    return MarketCard(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.boardMatchedTitle.tr(),
            style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
              color: Colour.textPrimary,
            ),
          ),
          Gap(4.h),
          for (final (i, item) in shown.indexed) ...[
            if (i > 0) const Divider(height: 1, color: Colour.lineSubtle),
            Padding(
              padding: EdgeInsets.only(
                top: 12.h,
                bottom: i < shown.length - 1 ? 12.h : 0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.service,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.lightBodyMediumRegular.copyWith(
                            color: Colour.textPrimary,
                          ),
                        ),
                        if (item.country != null) ...[
                          Gap(2.h),
                          Row(
                            children: [
                              if (item.flag != null) ...[
                                CountryFlag(item.flag),
                                Gap(6.w),
                              ],
                              Flexible(
                                child: Text(
                                  item.country!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyle.lightBodySmallRegular
                                      .copyWith(color: Colour.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Gap(12.w),
                  Text(
                    LocaleKeys.boardMatchedLabel.tr(),
                    style: AppTextStyle.lightBodyMediumMedium.copyWith(
                      color: Colour.success,
                    ),
                  ),
                  Gap(4.w),
                  Icon(Icons.check_rounded, size: 16.r, color: Colour.success),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
