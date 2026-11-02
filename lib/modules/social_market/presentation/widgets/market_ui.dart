import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/components/initials_avatar.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

/// Khối UI dùng chung của Social Market — theo UI kit web
/// `(HOME_CATEGORY)/_components/ui` (card bo 16, viền line, badge, SellerInfo…).

/// Card trắng viền xám (web `cardVariants`).
class MarketCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  const MarketCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16.r);
    return Material(
      color: Colour.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? Colour.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding ?? EdgeInsets.all(20.r), child: child),
      ),
    );
  }
}

enum MarketBadgeTone { neutral, seller, warning, info, overlay }

/// Badge bo tròn chữ nhỏ (web `badgeVariants`).
class MarketBadge extends StatelessWidget {
  final String text;
  final MarketBadgeTone tone;
  final IconData? icon;

  const MarketBadge(
    this.text, {
    super.key,
    this.tone = MarketBadgeTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      MarketBadgeTone.neutral => (Colour.subtle, Colour.textSecondary),
      MarketBadgeTone.seller => (Colour.seller50, Colour.seller800),
      MarketBadgeTone.warning => (Colour.amber50, Colour.amber700),
      MarketBadgeTone.info => (Colour.info50, Colour.blue700),
      MarketBadgeTone.overlay => (Colour.surface, Colour.textPrimary),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14.r, color: foreground),
            Gap(4.w),
          ],
          Flexible(
            child: Text(
              text,
              style: AppTextStyle.lightBodySmallMedium.copyWith(
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ảnh cờ nhỏ (16×12).
class CountryFlag extends StatelessWidget {
  final String? url;

  const CountryFlag(this.url, {super.key});

  @override
  Widget build(BuildContext context) {
    final src = url;
    if (src == null || src.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(2.r),
      child: Image.network(
        src,
        width: 16.w,
        height: 12.w,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Avatar tròn + tên (+ dấu xác minh) + dòng phụ "🇻🇳 Vietnam · nghề" (web `SellerInfo`).
class MarketSellerRow extends StatelessWidget {
  final String name;
  final String? avatar;
  final String? country;
  final String? flag;

  /// Phần sau quốc gia (nghề, "2 giờ trước"…).
  final String? trailingMeta;

  /// Thay hẳn dòng phụ mặc định.
  final Widget? meta;
  final bool verified;
  final double avatarSize;
  final bool large;
  final VoidCallback? onTap;

  const MarketSellerRow({
    super.key,
    required this.name,
    this.avatar,
    this.country,
    this.flag,
    this.trailingMeta,
    this.meta,
    this.verified = false,
    this.avatarSize = 40,
    this.large = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sub =
        meta ??
        (country == null && trailingMeta == null
            ? null
            : Row(
                children: [
                  if (country != null) ...[
                    if (flag != null) ...[CountryFlag(flag), Gap(6.w)],
                    Flexible(
                      child: Text(
                        country!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _metaStyle,
                      ),
                    ),
                  ],
                  if (country != null && trailingMeta != null)
                    Text('  ·  ', style: _metaStyle),
                  if (trailingMeta != null)
                    Flexible(
                      child: Text(
                        trailingMeta!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _metaStyle,
                      ),
                    ),
                ],
              ));
    final row = Row(
      children: [
        InitialsAvatar(
          name: name,
          imageUrl: avatar,
          colorSeed: name.hashCode,
          size: avatarSize.r,
        ),
        Gap(large ? 12.w : 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (large
                                  ? AppTextStyle.lightBodyLargeMedium
                                  : AppTextStyle.lightBodyMediumMedium)
                              .copyWith(color: Colour.textPrimary),
                    ),
                  ),
                  if (verified) ...[
                    Gap(4.w),
                    Icon(Icons.verified, size: 16.r, color: Colour.seller),
                  ],
                ],
              ),
              if (sub != null) ...[Gap(2.h), sub],
            ],
          ),
        ),
      ],
    );
    return onTap == null
        ? row
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: row,
          );
  }

  static TextStyle get _metaStyle =>
      AppTextStyle.lightBodyMediumRegular.copyWith(color: Colour.textSecondary);
}

/// Tiêu đề mục + nút mũi tên tròn (cả cụm bấm được) + mô tả (web `SectionHeading`).
class MarketSectionHeading extends StatelessWidget {
  final String title;
  final String? description;
  final VoidCallback? onViewAll;
  final String? viewAllLabel;

  const MarketSectionHeading({
    super.key,
    required this.title,
    this.description,
    this.onViewAll,
    this.viewAllLabel,
  });

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            style: AppTextStyle.lightHeadingMedium.copyWith(
              color: Colour.textPrimary,
            ),
          ),
        ),
        if (onViewAll != null) ...[
          Gap(12.w),
          Container(
            width: 36.r,
            height: 36.r,
            decoration: const BoxDecoration(
              color: Colour.subtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 18.r,
              color: Colour.textPrimary,
              semanticLabel: viewAllLabel,
            ),
          ),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        onViewAll == null
            ? heading
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onViewAll,
                child: heading,
              ),
        if (description != null) ...[
          Gap(8.h),
          Text(
            description!,
            style: AppTextStyle.lightBodyLargeRegular.copyWith(
              color: Colour.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Khối "We couldn't load this section right now." + Try again (web `SectionLoadError`).
class MarketSectionError extends StatelessWidget {
  final String title;
  final VoidCallback onRetry;

  const MarketSectionError({
    super.key,
    required this.title,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarketSectionHeading(title: title),
        Gap(16.h),
        MarketCard(
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 28.r,
                color: Colour.textSecondary,
              ),
              Gap(8.h),
              Text(
                LocaleKeys.marketSectionError.tr(),
                textAlign: TextAlign.center,
                style: AppTextStyle.lightBodyMediumRegular.copyWith(
                  color: Colour.textSecondary,
                ),
              ),
              Gap(12.h),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(LocaleKeys.marketSectionRetry.tr()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chân card: viền trên mảnh, 2 phía trái/phải (web `cardText.footer`).
class MarketCardFooter extends StatelessWidget {
  final Widget leading;
  final Widget? trailing;

  const MarketCardFooter({super.key, required this.leading, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 16.h),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colour.lineSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: leading),
          if (trailing != null) ...[Gap(12.w), trailing!],
        ],
      ),
    );
  }
}

enum MarketButtonVariant { primary, softSeller, outline, link, more }

/// Nút theo `buttonVariants` của web (size sm).
class MarketButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final MarketButtonVariant variant;
  final bool large;

  /// Thanh nút chật (mobile): cao như `large` nhưng chữ 14 + padding hẹp (web `h-11 px-4`).
  final bool dense;

  const MarketButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = MarketButtonVariant.primary,
    this.large = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = (large
        ? AppTextStyle.lightBodyLargeMedium
        : AppTextStyle.lightBodyMediumMedium);
    switch (variant) {
      case MarketButtonVariant.link:
      case MarketButtonVariant.more:
        final color = variant == MarketButtonVariant.link
            ? Colour.primary
            : Colour.textPrimary;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            child: Text(
              label,
              style: textStyle.copyWith(
                color: color,
                decoration: variant == MarketButtonVariant.more
                    ? TextDecoration.underline
                    : null,
                decorationColor: color,
              ),
            ),
          ),
        );
      case MarketButtonVariant.primary:
      case MarketButtonVariant.softSeller:
      case MarketButtonVariant.outline:
        final (background, foreground, border) = switch (variant) {
          MarketButtonVariant.primary => (
            Colour.primary,
            Colors.white,
            Colors.transparent,
          ),
          MarketButtonVariant.softSeller => (
            Colour.seller50,
            Colour.seller800,
            Colour.seller.withValues(alpha: 0.25),
          ),
          _ => (Colour.surface, Colour.textPrimary, Colour.lineStrong),
        };
        return SizedBox(
          height: large ? 48.h : 36.h,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              disabledBackgroundColor: background.withValues(alpha: 0.5),
              disabledForegroundColor: foreground.withValues(alpha: 0.7),
              padding: EdgeInsets.symmetric(
                horizontal: large && !dense ? 24.w : (dense ? 12.w : 16.w),
              ),
              textStyle: textStyle,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
                side: BorderSide(color: border),
              ),
            ),
            child: dense
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, maxLines: 1),
                  )
                : Text(label, textAlign: TextAlign.center),
          ),
        );
    }
  }
}

/// Like (tim đỏ) / Save (bookmark vàng) — web `IconToggle`.
class EngagementToggle extends StatelessWidget {
  final bool like;
  final bool on;
  final bool busy;
  final VoidCallback onTap;

  const EngagementToggle({
    super.key,
    required this.like,
    required this.on,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = like
        ? (on ? Icons.favorite : Icons.favorite_border)
        : (on ? Icons.bookmark : Icons.bookmark_border);
    final color = on
        ? (like ? Colour.primary : Colour.amber)
        : Colour.textSecondary;
    return SizedBox(
      width: 36.r,
      height: 36.r,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: busy ? null : onTap,
        icon: Icon(icon, size: 20.r, color: color),
      ),
    );
  }
}

/// Card mở/đóng tại chỗ (web `ExpandableCard`): chạm card để mở/thu gọn; [builder]
/// nhận trạng thái mở + hàm toggle (nút "View details").
class MarketExpandableCard extends StatefulWidget {
  final Widget Function(BuildContext context, bool open, VoidCallback toggle)
  builder;
  final Color? borderColor;

  const MarketExpandableCard({
    super.key,
    required this.builder,
    this.borderColor,
  });

  @override
  State<MarketExpandableCard> createState() => _MarketExpandableCardState();
}

class _MarketExpandableCardState extends State<MarketExpandableCard> {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) => MarketCard(
    borderColor: widget.borderColor,
    onTap: _toggle,
    child: widget.builder(context, _open, _toggle),
  );
}

/// Dòng "icon  **Nhãn:** giá trị" trong khối chi tiết (web `OfferInfo` / `InfoItem`).
class MarketInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const MarketInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: Icon(icon, size: 17.r, color: Colour.textSecondary),
          ),
          Gap(8.w),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: AppTextStyle.lightBodySmallMedium.copyWith(
                      color: Colour.textPrimary,
                    ),
                  ),
                  TextSpan(text: v),
                ],
              ),
              style: AppTextStyle.lightBodySmallRegular.copyWith(
                color: Colour.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung chờ cho card (mục đang tải).
class MarketCardSkeleton extends StatelessWidget {
  final double height;

  const MarketCardSkeleton({super.key, this.height = 180});

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, double h) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: Colour.subtle,
          borderRadius: BorderRadius.circular(6.r),
        ),
      ),
    );
    return MarketCard(
      child: SizedBox(
        height: height.h - 40.h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(0.7, 18.h),
            Gap(12.h),
            bar(0.45, 14.h),
            Gap(16.h),
            bar(1, 12.h),
            Gap(8.h),
            bar(0.9, 12.h),
            const Spacer(),
            bar(0.35, 16.h),
          ],
        ),
      ),
    );
  }
}
