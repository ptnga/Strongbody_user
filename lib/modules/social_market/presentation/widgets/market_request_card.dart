import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/widgets/common/voice_note_player.dart';

import '../../domain/entities/market_feed_entities.dart';
import '../market_formatters.dart';
import 'market_image_viewer.dart';
import 'market_ui.dart';

/// Card request công khai (web `RequestCard`): người đăng ẩn danh ("A***", avatar
/// mờ), mô tả 2 dòng, badge hình thức / hạn; chạm để mở chi tiết + "I have similar
/// request". Nút "Send offer to user" là hành động của seller — app buyer ẩn.
class MarketRequestCard extends StatelessWidget {
  final MarketRequestEntity request;
  final ValueChanged<String> onSimilar;

  const MarketRequestCard({
    super.key,
    required this.request,
    required this.onSimilar,
  });

  @override
  Widget build(BuildContext context) {
    final r = request;
    final locale = context.locale.toString();
    final initial =
        (r.authorFirstName ?? LocaleKeys.marketRequestAnonymous.tr())
            .characters
            .first;
    final metaStyle = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );
    final footerMeta = [
      if (r.conversations > 0)
        LocaleKeys.marketRequestConversations.plural(r.conversations),
      if (r.offers > 0) LocaleKeys.marketRequestOffersSent.plural(r.offers),
    ].join(' · ');

    return MarketExpandableCard(
      borderColor: r.solved ? Colour.seller.withValues(alpha: 0.6) : null,
      builder: (context, open, toggle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: Container(
                  width: 40.r,
                  height: 40.r,
                  color: Colour.subtle,
                  child: r.avatar == null
                      ? null
                      : ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: 2.5,
                            sigmaY: 2.5,
                          ),
                          child: Transform.scale(
                            scale: 1.15,
                            child: Image.network(
                              r.avatar!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                ),
              ),
              Gap(10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$initial***',
                            style: AppTextStyle.lightBodyMediumMedium.copyWith(
                              color: Colour.textPrimary,
                            ),
                          ),
                          if (r.country != null)
                            TextSpan(text: ' · ${r.country}'),
                        ],
                      ),
                      style: metaStyle,
                    ),
                    if (r.createdAt != null) ...[
                      Gap(2.h),
                      Text(
                        MarketFormatters.timeAgo(r.createdAt),
                        style: metaStyle,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Gap(16.h),
          Text(
            r.text,
            maxLines: open ? null : 2,
            overflow: open ? null : TextOverflow.ellipsis,
            style: AppTextStyle.lightBodyMediumRegular.copyWith(
              color: Colour.textPrimary,
              height: 1.6,
            ),
          ),
          if (r.deliveryType != null || r.deadline != null) ...[
            Gap(12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                if (r.deliveryType != null)
                  MarketBadge(
                    MarketFormatters.requestDelivery(r.deliveryType!),
                  ),
                if (r.deadline != null)
                  MarketBadge(
                    LocaleKeys.marketRequestDue.tr(
                      namedArgs: {
                        'date': DateFormat.yMd(locale).format(r.deadline!),
                      },
                    ),
                    tone: MarketBadgeTone.warning,
                  ),
              ],
            ),
          ],
          if (!open)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: MarketButton(
                label: LocaleKeys.marketViewDetails.tr(),
                variant: MarketButtonVariant.more,
                onPressed: toggle,
              ),
            ),
          if (open) ...[Gap(16.h), _RequestDetails(request: r)],
          if (open || footerMeta.isNotEmpty || r.solved) ...[
            Gap(16.h),
            MarketCardFooter(
              leading: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8.w,
                children: [
                  if (footerMeta.isNotEmpty) Text(footerMeta, style: metaStyle),
                  if (r.solved)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16.r,
                          color: Colour.seller,
                        ),
                        Gap(4.w),
                        Text(
                          LocaleKeys.marketRequestSolved.tr(),
                          style: metaStyle.copyWith(color: Colour.seller),
                        ),
                      ],
                    ),
                ],
              ),
              trailing: open && r.text.isNotEmpty
                  ? MarketButton(
                      label: LocaleKeys.marketRequestSimilar.tr(),
                      variant: MarketButtonVariant.link,
                      onPressed: () => onSimilar(r.text),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestDetails extends StatelessWidget {
  final MarketRequestEntity request;

  const _RequestDetails({required this.request});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final locale = context.locale.toString();
    final images = [
      for (final a in r.attachments)
        if (RegExp(
          r'\.(png|jpe?g|gif|webp|heic)$',
          caseSensitive: false,
        ).hasMatch(a.name ?? a.url))
          a.url,
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colour.mutedWeb,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarketInfoRow(
            icon: Icons.local_shipping_outlined,
            label: LocaleKeys.marketRequestDelivery.tr(),
            value: r.deliveryType == null
                ? null
                : MarketFormatters.requestDelivery(r.deliveryType!),
          ),
          MarketInfoRow(
            icon: Icons.event_outlined,
            label: LocaleKeys.marketRequestDeadline.tr(),
            value: r.deadline == null
                ? null
                : DateFormat.yMd(locale).add_jms().format(r.deadline!),
          ),
          MarketInfoRow(
            icon: Icons.schedule,
            label: LocaleKeys.marketRequestSchedule.tr(),
            value: MarketFormatters.schedule(r.schedule),
          ),
          MarketInfoRow(
            icon: Icons.translate,
            label: LocaleKeys.marketRequestSellerLanguages.tr(),
            value: r.sellerLanguages
                .map(MarketFormatters.languageName)
                .join(', '),
          ),
          MarketInfoRow(
            icon: Icons.payments_outlined,
            label: LocaleKeys.marketRequestBudget.tr(),
            value: r.budget == null ? null : MarketFormatters.budget(r.budget!),
          ),
          MarketInfoRow(
            icon: Icons.category_outlined,
            label: LocaleKeys.marketRequestCategories.tr(),
            value: r.categories.join(', '),
          ),
          if (r.voiceUrl != null) ...[
            Gap(4.h),
            VoiceNotePlayer(path: r.voiceUrl!),
          ],
          if (r.attachments.isNotEmpty) ...[
            Gap(8.h),
            Text(
              LocaleKeys.marketRequestAttachments.tr(),
              style: AppTextStyle.lightBodyMediumMedium.copyWith(
                color: Colour.textPrimary,
              ),
            ),
            Gap(6.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                for (final (i, a) in r.attachments.indexed)
                  ActionChip(
                    avatar: Icon(Icons.attach_file, size: 14.r),
                    label: Text(
                      a.name ??
                          LocaleKeys.marketRequestAttachmentN.tr(
                            namedArgs: {'index': '${i + 1}'},
                          ),
                    ),
                    onPressed: images.contains(a.url)
                        ? () => showMarketImageViewer(
                            context,
                            images: images,
                            initialIndex: images.indexOf(a.url),
                          )
                        : null,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
