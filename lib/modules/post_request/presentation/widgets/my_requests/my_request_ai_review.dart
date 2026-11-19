import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../../domain/entities/my_request_entity.dart';

/// Vì sao request chưa được duyệt (web `AIReview` / `AISuggestionNote singleLanguage`):
/// - AI đang chấm lại (người đăng vừa sửa) → khung xám "Your updated request is under review".
/// - Chờ duyệt / bị từ chối mà AI chấm dưới điểm duyệt → khung vàng: tiêu đề (bị từ chối:
///   "Please review and update your request") + gợi ý của AI (một bản, theo ngôn ngữ app).
/// - Request khác AI chấm 0 điểm → chỉ khung gợi ý.
///
/// Nút "Edit request" (sửa & gửi chấm lại) của web chưa có trên app.
/// Chỉ dựng khi [MyRequestEntity.showsAiReview].
class MyRequestAiReview extends StatelessWidget {
  final MyRequestEntity request;

  const MyRequestAiReview({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final refine = request.aiRefine;
    if (refine == null) return const SizedBox.shrink();
    if (request.isRescoring) {
      return _Box(
        background: Colour.muted,
        border: Colour.lineSubtle,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome, size: 18.r, color: Colour.amber700),
            Gap(8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleKeys.myRequestsAiRescoringTitle.tr(),
                    style: AppTextStyle.lightBodyMediumMedium.copyWith(
                      color: Colour.textPrimary,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    LocaleKeys.myRequestsAiRescoringBody.tr(),
                    style: AppTextStyle.lightBodySmallRegular.copyWith(
                      height: 1.4,
                      color: Colour.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final suggestion = refine.suggestionFor(context.locale.languageCode);
    if (suggestion.isEmpty) return const SizedBox.shrink();
    return _Box(
      background: Colour.amber50,
      border: Colour.amber.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, size: 16.r, color: Colour.amber700),
              Gap(6.w),
              Expanded(
                child: Text(
                  request.status == 'rejected'
                      ? LocaleKeys.myRequestsAiRejectedTitle.tr()
                      : LocaleKeys.myRequestsAiSuggestionTitle.tr(),
                  style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                    color: Colour.amber700,
                  ),
                ),
              ),
            ],
          ),
          Gap(4.h),
          Text(
            suggestion,
            style: AppTextStyle.lightBodyMediumRegular.copyWith(
              height: 1.4,
              color: Colour.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  final Color background;
  final Color border;
  final Widget child;

  const _Box({
    required this.background,
    required this.border,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(12.r),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: border),
    ),
    child: child,
  );
}
