import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../../domain/entities/provider_entity.dart';
import 'provider_formatters.dart';

/// Thẻ provider (mockup "Browse matching providers"): avatar · tên ✓ · nghề + số năm ·
/// rating · giá "from" · tag · lịch rảnh gần nhất · Voice message / Request offer.
/// Thông tin nào API chưa có thì ẩn.
class ProviderCard extends StatelessWidget {
  final ProviderEntity provider;
  final ProviderExtras? extras;
  final VoidCallback onVoiceMessage;
  final VoidCallback onRequestOffer;

  /// Chế độ chọn nhiều: thay 2 nút bằng nút Chọn / Đã chọn.
  final bool? selected;
  final VoidCallback? onToggleSelect;

  const ProviderCard({
    super.key,
    required this.provider,
    required this.extras,
    required this.onVoiceMessage,
    required this.onRequestOffer,
    this.selected,
    this.onToggleSelect,
  });

  static const _avatarColors = [
    (Color(0xFFE6F4EA), Color(0xFF1C7C54)),
    (Color(0xFFE7EEFB), Color(0xFF2B5BB5)),
    (Color(0xFFFBE7EE), Color(0xFFB4235A)),
    (Color(0xFFFFF1DE), Color(0xFFB0640B)),
    (Color(0xFFEDE7FB), Color(0xFF5B3CC4)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.languageCode;
    final e = extras;
    final years = provider.yearsOfExperience;
    final subtitle = [
      provider.profession,
      if (years == 1) LocaleKeys.providersYearsOne.tr(),
      if (years > 1) LocaleKeys.providersYearsMany.tr(args: ['$years']),
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final next = e?.nextAvailable(DateTime.now());
    final tags = [
      ...provider.skills.take(1),
      ...?e?.deliveryTypes.map(ProviderFormatters.delivery),
      if (provider.languages.isNotEmpty)
        provider.languages
            .take(2)
            .map((code) => ProviderFormatters.languageName(code, locale))
            .join(', '),
    ];
    final isSelected = selected ?? false;

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: theme.surface(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isSelected ? theme.secondary(context) : theme.border(context),
          width: isSelected ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                provider: provider,
                colors: _avatarColors[provider.id % _avatarColors.length],
              ),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            provider.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.lightBodyLargeBold.copyWith(
                              color: theme.textPrimary(context),
                            ),
                          ),
                        ),
                        if (provider.verified) ...[
                          Gap(4.w),
                          Icon(
                            Icons.verified_rounded,
                            size: 16.r,
                            color: Colour.success,
                          ),
                        ],
                      ],
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.lightBodySmallRegular.copyWith(
                          color: theme.textSecondary(context),
                        ),
                      ),
                    if (provider.reviewCount > 0) ...[
                      Gap(2.h),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16.r,
                            color: const Color(0xFFF5A524),
                          ),
                          Gap(2.w),
                          Text(
                            provider.rating.toStringAsFixed(1),
                            style: AppTextStyle.lightBodySmallBold.copyWith(
                              color: theme.textPrimary(context),
                            ),
                          ),
                          Text(
                            ' (${provider.reviewCount})',
                            style: AppTextStyle.lightBodySmallRegular.copyWith(
                              color: theme.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (e?.minPrice != null) ...[
                Gap(8.w),
                _Price(
                  amount: e!.minPrice!,
                  currency: e.currency,
                  perSession: e.perSession,
                ),
              ],
            ],
          ),
          if (tags.isNotEmpty) ...[
            Gap(10.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: [for (final tag in tags) _Tag(text: tag)],
            ),
          ],
          if (next != null) ...[
            Gap(10.h),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 15.r, color: Colour.success),
                Gap(6.w),
                Text(
                  LocaleKeys.providersAvailable.tr(
                    args: [ProviderFormatters.slot(next, locale)],
                  ),
                  style: AppTextStyle.lightBodySmallMedium.copyWith(
                    color: Colour.success,
                  ),
                ),
              ],
            ),
          ],
          Gap(12.h),
          if (selected != null)
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: isSelected
                  ? FilledButton.icon(
                      onPressed: onToggleSelect,
                      icon: Icon(Icons.check_rounded, size: 18.r),
                      label: Text(LocaleKeys.providersSelected.tr()),
                      style: _filledStyle(context),
                    )
                  : OutlinedButton(
                      onPressed: onToggleSelect,
                      style: _outlinedStyle(context),
                      child: Text(LocaleKeys.providersSelect.tr()),
                    ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44.h,
                    child: OutlinedButton.icon(
                      onPressed: onVoiceMessage,
                      icon: Icon(Icons.mic_none_rounded, size: 18.r),
                      label: Text(LocaleKeys.providersVoiceMessage.tr()),
                      style: _outlinedStyle(context),
                    ),
                  ),
                ),
                Gap(8.w),
                Expanded(
                  child: SizedBox(
                    height: 44.h,
                    child: FilledButton(
                      onPressed: onRequestOffer,
                      style: _filledStyle(context),
                      child: Text(LocaleKeys.providersRequestOffer.tr()),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  ButtonStyle _outlinedStyle(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.styleFrom(
      foregroundColor: theme.textPrimary(context),
      side: BorderSide(color: theme.border(context)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      textStyle: AppTextStyle.lightBodyMediumSemiBold,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
    );
  }

  ButtonStyle _filledStyle(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton.styleFrom(
      backgroundColor: theme.secondary(context),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      textStyle: AppTextStyle.lightBodyMediumBold,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
    );
  }
}

class _Avatar extends StatelessWidget {
  final ProviderEntity provider;
  final (Color, Color) colors;

  const _Avatar({required this.provider, required this.colors});

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = colors;
    return CircleAvatar(
      radius: 24.r,
      backgroundColor: background,
      foregroundImage: provider.avatarUrl == null
          ? null
          : NetworkImage(provider.avatarUrl!),
      onForegroundImageError: provider.avatarUrl == null ? null : (_, _) {},
      child: Text(
        provider.initials,
        style: AppTextStyle.lightBodyMediumBold.copyWith(color: foreground),
      ),
    );
  }
}

class _Price extends StatelessWidget {
  final double amount;
  final String? currency;
  final bool perSession;

  const _Price({
    required this.amount,
    required this.currency,
    required this.perSession,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = AppTextStyle.lightBodySmallRegular.copyWith(
      color: theme.textSecondary(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(LocaleKeys.providersFrom.tr(), style: small),
        Text(
          ProviderFormatters.money(amount, currency),
          style: AppTextStyle.lightBodyXLargeBold.copyWith(
            color: theme.textPrimary(context),
          ),
        ),
        if (perSession) Text(LocaleKeys.providersPerSession.tr(), style: small),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: theme.muted(context),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        text,
        style: AppTextStyle.lightBodySmallRegular.copyWith(
          color: theme.textPrimary(context),
        ),
      ),
    );
  }
}
