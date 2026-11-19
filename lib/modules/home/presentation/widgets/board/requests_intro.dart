import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../../domain/entities/board_entities.dart';

/// Một ô số liệu tuần này (số lớn + nhãn bên dưới).
typedef BoardStatTile = ({String key, String display, String label});

/// Đầu bảng Requests trang chủ mobile (web `RequestsIntro`): MỘT card tràn hết bề ngang —
/// số liệu tuần này (API board-stats; lỗi / chưa có request tuần này → bỏ hàng số) + cam kết
/// tin cậy — rồi tiêu đề "Typical requests" ngay trên danh sách. Đăng request qua nút
/// "Get help" ở thanh dưới (không còn nút đăng ở đây).
class RequestsIntro extends StatelessWidget {
  final BoardStats? stats;

  const RequestsIntro({super.key, required this.stats});

  /// Web `useStatTiles`: request tuần này; thêm ô "đã kết nối" khi có request được phản hồi.
  static List<BoardStatTile> tiles(BoardStats? stats, String locale) {
    if (stats == null || stats.weekTotal <= 0) return const [];
    final format = NumberFormat.decimalPattern(locale);
    return [
      (
        key: 'week',
        display: format.format(stats.weekTotal),
        label: stats.weekTotal == 1
            ? LocaleKeys.boardIntroStatWeekOne.tr()
            : LocaleKeys.boardIntroStatWeekOther.tr(),
      ),
      if (stats.weekMatched > 0)
        (
          key: 'matched',
          display: format.format(stats.weekMatched),
          label: LocaleKeys.boardIntroStatMatched.tr(),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tiles = RequestsIntro.tiles(stats, context.locale.toString());
    final trust = [
      LocaleKeys.boardIntroTrustRealPeople.tr(),
      LocaleKeys.boardIntroTrustVerifiedExperts.tr(),
      LocaleKeys.boardIntroTrustPayOnAccept.tr(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: Colour.surface,
            border: Border(bottom: BorderSide(color: Colour.border)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (tiles.isNotEmpty) ...[
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, tile) in tiles.indexed)
                          Expanded(
                            child: Container(
                              padding: EdgeInsetsDirectional.only(
                                start: i > 0 ? 16.w : 0,
                              ),
                              decoration: i > 0
                                  ? const BoxDecoration(
                                      border: BorderDirectional(
                                        start: BorderSide(
                                          color: Colour.lineSubtle,
                                        ),
                                      ),
                                    )
                                  : null,
                              child: _StatTile(tile: tile, trending: i == 0),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Gap(12.h),
                  const Divider(height: 1, color: Colour.lineSubtle),
                  Gap(12.h),
                ],
                Wrap(
                  spacing: 16.w,
                  runSpacing: 6.h,
                  children: [
                    for (final text in trust)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16.r,
                            color: Colour.success,
                          ),
                          Gap(6.w),
                          Flexible(
                            child: Text(
                              text,
                              style: AppTextStyle.lightBodyMediumRegular
                                  .copyWith(color: Colour.textSecondary),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 0),
          child: Semantics(
            header: true,
            child: Text(
              LocaleKeys.boardIntroTitle.tr(),
              style: AppTextStyle.lightHeadingSmall.copyWith(
                color: Colour.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final BoardStatTile tile;

  /// Ô đầu: kèm icon xu hướng tăng.
  final bool trending;

  const _StatTile({required this.tile, required this.trending});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            tile.display,
            style: AppTextStyle.lightHeadingMedium.copyWith(
              height: 1.2,
              color: Colour.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (trending) ...[
            Gap(6.w),
            Icon(Icons.trending_up_rounded, size: 18.r, color: Colour.primary),
          ],
        ],
      ),
      Gap(2.h),
      Text(
        tile.label,
        style: AppTextStyle.lightBodyMediumRegular.copyWith(
          height: 1.3,
          color: Colour.textSecondary,
        ),
      ),
    ],
  );
}
