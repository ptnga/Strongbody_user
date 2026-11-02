import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/constants/app_spacings.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/modules/home/presentation/widgets/home_request_composer.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/post_request_flow_args.dart';

/// Gửi từ Hero / khối cuối mục Requests → trợ lý AI soạn request ("Here's what I
/// heard"), như web gửi sang `/request-assistant`.
void openMarketRequest(BuildContext context, String text, List<String> files) {
  context.push(
    RouteName.requestHeard,
    extra: PostRequestFlowArgs(text: text, attachmentPaths: files),
  );
}

/// Thanh trên như `HomeTopBar`: back · tên marketplace đậm ở giữa (không kẻ dưới).
class MarketTopBar extends StatelessWidget {
  final String title;

  const MarketTopBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52.h,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Row(
          children: [
            SizedBox(
              width: 48.r,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20.r,
                  color: Colour.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.lightBodyXLargeBold.copyWith(
                  color: Colour.textPrimary,
                ),
              ),
            ),
            // Cân với nút back để tiêu đề nằm chính giữa.
            SizedBox(width: 48.r),
          ],
        ),
      ),
    );
  }
}

/// Tagline nhỏ + câu hỏi (cỡ chữ "What do you need today?" của Home) + dòng phụ.
class MarketAskHeading extends StatelessWidget {
  final String tagline;
  final String title;
  final String? subtitle;

  const MarketAskHeading({
    super.key,
    required this.tagline,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tagline, textAlign: TextAlign.center, style: secondary),
          Gap(6.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyle.lightHeadingMedium.copyWith(
              height: 1.25,
              color: Colour.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            Gap(6.h),
            Text(subtitle!, textAlign: TextAlign.center, style: secondary),
          ],
          Gap(8.h),
        ],
      ),
    );
  }
}

/// Ô nhập yêu cầu (text / giọng nói) — composer của Home.
class MarketHeroComposer extends StatelessWidget {
  final Color? background;

  const MarketHeroComposer({super.key, this.background});

  @override
  Widget build(BuildContext context) => HomeRequestComposer(
    hintText: LocaleKeys.marketHeroPlaceholder.tr(),
    source: 'social_market',
    background: background,
    onSend: (text, files) => openMarketRequest(context, text, files),
  );
}
