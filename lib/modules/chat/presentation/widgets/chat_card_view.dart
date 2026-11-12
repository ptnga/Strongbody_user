import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/request_formatters.dart';

import '../../domain/entities/chat_message_entity.dart';

/// Thẻ request / service / product / public offer trong chat — web `MessageRequest`,
/// `MessageService`, `MessageProduct`, `MessagePublicOffer` (+ `ChatBudget`,
/// `DetailsToggle`, `CardAction`). Chỉ trích dẫn: không thanh toán.
class ChatCardView extends StatefulWidget {
  final ChatCardEntity card;

  /// Tin do chính mình gửi — nút "Go to my requests" chỉ dành cho người nhận.
  final bool mine;

  const ChatCardView({super.key, required this.card, required this.mine});

  /// "$100–200" / "100 VND"; tin cũ chỉ có chuỗi `budget`.
  static String? budget(ChatCardEntity c) {
    final min = c.budgetMin;
    final max = c.budgetMax;
    if (min == null && max == null) return c.budgetText;
    final currency = c.budgetCurrency ?? 'USD';
    if (min != null && max != null && min != max) {
      return '${RequestFormatters.money(min, currency)}–'
          '${RequestFormatters.money(max, currency)}';
    }
    return RequestFormatters.money(max ?? min!, currency);
  }

  /// Giá của service / product / public offer (web `Money` / `price_text`).
  static String? price(ChatCardEntity c) {
    final amount = c.price;
    final unit = c.priceUnit ?? '';
    if (amount != null && amount > 0) {
      final currency = c.currency ?? 'USD';
      final max = c.priceMax;
      final text = max != null && max > amount
          ? '${RequestFormatters.money(amount, currency)}–'
                '${RequestFormatters.money(max, currency)}'
          : RequestFormatters.money(amount, currency);
      return '$text$unit';
    }
    return c.priceText;
  }

  /// Mô tả service / product là HTML (web `dangerouslySetInnerHTML`) → chữ thuần.
  static String plain(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  @override
  State<ChatCardView> createState() => _ChatCardViewState();
}

class _ChatCardViewState extends State<ChatCardView> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.card;
    final primary = theme.textPrimary(context);
    final secondary = theme.textSecondary(context);
    final isItem =
        c.kind == ChatCardKind.service || c.kind == ChatCardKind.product;
    final heading = switch (c.kind) {
      ChatCardKind.request => LocaleKeys.chatCardRequest.tr(),
      ChatCardKind.service => LocaleKeys.chatCardService.tr(),
      ChatCardKind.product => LocaleKeys.chatCardProduct.tr(),
      ChatCardKind.publicOffer => LocaleKeys.chatCardPublicOffer.tr(),
    };
    final description = isItem
        ? ChatCardView.plain(c.description)
        : c.description.trim();
    // Public offer: `title` chỉ là 80 ký tự đầu của mô tả → hiện mô tả một lần.
    final title = switch (c.kind) {
      ChatCardKind.publicOffer => null,
      _ when c.title.isEmpty || c.title == c.description => null,
      _ => c.title,
    };
    final body = c.kind == ChatCardKind.publicOffer
        ? (description.isNotEmpty ? description : c.title.trim())
        : description;
    final hasMore = switch (c.kind) {
      ChatCardKind.request =>
        body.length > 100 || c.categoryName != null || c.country != null,
      ChatCardKind.publicOffer => body.length > 120,
      _ => body.length > 100,
    };
    final budget = ChatCardView.budget(c);
    final price = c.kind == ChatCardKind.request ? null : ChatCardView.price(c);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: theme.surface(context),
        border: Border.all(color: theme.border(context)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isItem)
            Text(
              LocaleKeys.chatCardRelatedTo.tr(),
              style: AppTextStyle.lightBodySmallRegular.copyWith(
                color: secondary,
              ),
            ),
          Text(
            heading,
            style: AppTextStyle.lightBodyMediumBold.copyWith(color: primary),
          ),
          Gap(8.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.image case final image?) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: Image.network(
                    image,
                    width: 56.r,
                    height: 56.r,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => SizedBox(width: 56.r),
                  ),
                ),
                Gap(10.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title,
                        maxLines: _open ? null : (isItem ? 2 : 1),
                        overflow: _open ? null : TextOverflow.ellipsis,
                        style: AppTextStyle.lightBodyMediumMedium.copyWith(
                          color: primary,
                        ),
                      ),
                    if (body.isNotEmpty)
                      Text(
                        body,
                        maxLines: _open
                            ? null
                            : (c.kind == ChatCardKind.publicOffer ? 3 : 2),
                        overflow: _open ? null : TextOverflow.ellipsis,
                        style: AppTextStyle.lightBodyMediumRegular.copyWith(
                          color: c.kind == ChatCardKind.publicOffer
                              ? primary
                              : secondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_open && c.kind == ChatCardKind.request) ...[
            if (c.categoryName case final category?) ...[
              Gap(6.h),
              Text(
                LocaleKeys.chatCardCategory.tr(args: [category]),
                style: AppTextStyle.lightBodyMediumRegular.copyWith(
                  color: secondary,
                ),
              ),
            ],
            if (c.country case final country?)
              Text(
                LocaleKeys.chatCardCountry.tr(args: [country]),
                style: AppTextStyle.lightBodyMediumRegular.copyWith(
                  color: secondary,
                ),
              ),
          ],
          if (price != null) ...[
            Gap(10.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: theme.muted(context),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleKeys.chatCardPrice.tr(),
                    style: AppTextStyle.lightBodySmallRegular.copyWith(
                      color: secondary,
                    ),
                  ),
                  Text(
                    price,
                    style: AppTextStyle.lightBodyLargeBold.copyWith(
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (budget != null && budget.isNotEmpty) ...[
            Gap(8.h),
            Text(
              LocaleKeys.chatCardMyBudget.tr(args: [budget]),
              style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                color: secondary,
              ),
            ),
          ],
          if (hasMore) ...[
            Gap(4.h),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _open
                          ? LocaleKeys.chatCardHideDetails.tr()
                          : LocaleKeys.chatCardViewDetails.tr(),
                      style: AppTextStyle.lightBodySmallSemiBold.copyWith(
                        color: primary,
                      ),
                    ),
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: 16.r,
                      color: primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (c.kind == ChatCardKind.request && !widget.mine) ...[
            Gap(10.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go(RouteName.myRequests),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: theme.border(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  LocaleKeys.chatCardOpenMyRequests.tr(),
                  style: AppTextStyle.lightBodySmallBold.copyWith(
                    color: primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
