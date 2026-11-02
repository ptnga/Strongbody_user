import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../domain/entities/medical_travel_entities.dart';
import 'market_ui.dart';

/// Chữ dùng chung của Medical Travel.
class MedicalTravelTexts {
  MedicalTravelTexts._();

  static String cert(MarketCert c) => switch (c) {
    MarketCert.jciAccredited => LocaleKeys.marketDestCertsJciAccredited.tr(),
    MarketCert.iso9001 => LocaleKeys.marketDestCertsIso9001.tr(),
    MarketCert.visaLetterOnRequest =>
      LocaleKeys.marketDestCertsVisaLetterOnRequest.tr(),
    MarketCert.medicalTranslator =>
      LocaleKeys.marketDestCertsMedicalTranslator.tr(),
  };
}

/// Tiêu đề mục căn giữa (web `mx-auto max-w-2xl text-center`).
class MedicalCenteredHeading extends StatelessWidget {
  final String title;
  final String? subtitle;

  const MedicalCenteredHeading({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyle.lightHeadingMedium.copyWith(
              color: Colour.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            Gap(8.h),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: AppTextStyle.lightBodyLargeRegular.copyWith(
                color: Colour.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip lọc (web `chipVariants` tone brand).
class MarketFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const MarketFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colour.brand50 : Colour.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? Colour.primary.withValues(alpha: 0.2)
              : Colour.border,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Text(
            label,
            style: AppTextStyle.lightBodyMediumMedium.copyWith(
              color: selected ? Colour.primary : Colour.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ một nước: ảnh phủ + gradient tối, cờ, tên, mô tả, nút "Explore →".
class DestinationCard extends StatelessWidget {
  final MarketDestination destination;
  final VoidCallback onTap;

  /// Bản gọn (mục "Explore other destinations"): chỉ cờ + tên.
  final bool compact;

  const DestinationCard({
    super.key,
    required this.destination,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final d = destination;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: Material(
        color: Colour.textPrimary,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (d.image != null)
                Image.network(
                  d.image!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 12.r : 20.r),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (compact)
                      Row(
                        children: [
                          CountryFlag(d.flag),
                          Gap(6.w),
                          Expanded(
                            child: Text(
                              d.country,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyle.lightBodyLargeSemiBold
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      if (d.flag != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3.r),
                          child: Image.network(
                            d.flag!,
                            width: 32.w,
                            height: 24.w,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      Gap(6.h),
                      Text(
                        d.country,
                        style: AppTextStyle.lightBodyXLargeSemiBold.copyWith(
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      if (d.focus.isNotEmpty) ...[
                        Gap(4.h),
                        Text(
                          d.focus,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.lightBodyMediumRegular.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                      Gap(12.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              LocaleKeys.marketMtDestinationsExplore.tr(),
                              style: AppTextStyle.lightBodyMediumMedium
                                  .copyWith(color: Colors.white),
                            ),
                            Gap(4.w),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14.r,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4 cam kết: kiểm định, thư mời visa, điều phối & phiên dịch, trả tiền khi đã xác nhận.
class MedicalTrustStrip extends StatelessWidget {
  const MedicalTrustStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.verified_outlined,
        LocaleKeys.marketMtTrustAccreditationTitle.tr(),
        LocaleKeys.marketMtTrustAccreditationDesc.tr(),
      ),
      (
        Icons.approval_outlined,
        LocaleKeys.marketMtTrustVisaLettersTitle.tr(),
        LocaleKeys.marketMtTrustVisaLettersDesc.tr(),
      ),
      (
        Icons.translate,
        LocaleKeys.marketMtTrustCoordinatorTitle.tr(),
        LocaleKeys.marketMtTrustCoordinatorDesc.tr(),
      ),
      (
        Icons.lock_outline,
        LocaleKeys.marketMtTrustPayWhenConfirmedTitle.tr(),
        LocaleKeys.marketMtTrustPayWhenConfirmedDesc.tr(),
      ),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 40.h),
      child: Column(
        children: [
          for (final (i, (icon, title, desc)) in items.indexed) ...[
            if (i > 0) Gap(16.h),
            MarketCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconTile(icon: icon),
                  Gap(16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
                            color: Colour.textPrimary,
                          ),
                        ),
                        Gap(4.h),
                        Text(
                          desc,
                          style: AppTextStyle.lightBodyMediumRegular.copyWith(
                            color: Colour.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color background;

  const _IconTile({required this.icon, this.background = Colour.seller50});

  @override
  Widget build(BuildContext context) => Container(
    width: 44.r,
    height: 44.r,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12.r),
    ),
    child: Icon(icon, color: Colour.seller, size: 22.r),
  );
}

/// "How a medical trip works": 5 bước · gói ghi rõ bao gồm / không bao gồm · bảo vệ
/// thanh toán (web `HowItWorksSection`).
class MedicalHowItWorks extends StatelessWidget {
  const MedicalHowItWorks({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        LocaleKeys.marketMtHowStepsCoordinatorTitle.tr(),
        LocaleKeys.marketMtHowStepsCoordinatorDesc.tr(),
      ),
      (
        LocaleKeys.marketMtHowStepsShortlistTitle.tr(),
        LocaleKeys.marketMtHowStepsShortlistDesc.tr(),
      ),
      (
        LocaleKeys.marketMtHowStepsFlyTitle.tr(),
        LocaleKeys.marketMtHowStepsFlyDesc.tr(),
      ),
      (
        LocaleKeys.marketMtHowStepsTreatedTitle.tr(),
        LocaleKeys.marketMtHowStepsTreatedDesc.tr(),
      ),
      (
        LocaleKeys.marketMtHowStepsRecoverTitle.tr(),
        LocaleKeys.marketMtHowStepsRecoverDesc.tr(),
      ),
    ];
    final metaStyle = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );
    final titleStyle = AppTextStyle.lightBodyLargeSemiBold.copyWith(
      color: Colour.textPrimary,
    );
    Widget list(String title, IconData icon, Color color, List<String> items) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18.r, color: color),
                Gap(6.w),
                Text(
                  title,
                  style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                    color: color,
                  ),
                ),
              ],
            ),
            Gap(12.h),
            for (final item in items)
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 7.h, right: 8.w),
                      width: 6.r,
                      height: 6.r,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(child: Text(item, style: metaStyle)),
                  ],
                ),
              ),
          ],
        );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 56.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MedicalCenteredHeading(
            title: LocaleKeys.marketMtHowTitle.tr(),
            subtitle: LocaleKeys.marketMtHowSubtitle.tr(),
          ),
          Gap(40.h),
          MarketCard(
            padding: EdgeInsets.all(24.r),
            child: Column(
              children: [
                for (final (i, (title, desc)) in steps.indexed) ...[
                  if (i > 0) Gap(16.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36.r,
                        height: 36.r,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colour.brand50,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: AppTextStyle.lightBodyMediumMedium.copyWith(
                            color: Colour.primary,
                          ),
                        ),
                      ),
                      Gap(12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: titleStyle),
                            Gap(2.h),
                            Text(desc, style: metaStyle),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Gap(24.h),
          MarketCard(
            padding: EdgeInsets.all(24.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.marketMtHowPackageTitle.tr(),
                  style: AppTextStyle.lightBodyXLargeSemiBold.copyWith(
                    color: Colour.textPrimary,
                  ),
                ),
                Gap(4.h),
                Text(LocaleKeys.marketMtHowPackageDesc.tr(), style: metaStyle),
                Gap(20.h),
                list(
                  LocaleKeys.marketMtHowIncludedTitle.tr(),
                  Icons.check_circle_outline,
                  Colour.seller,
                  [
                    LocaleKeys.marketMtHowIncludedTests.tr(),
                    LocaleKeys.marketMtHowIncludedStay.tr(),
                    LocaleKeys.marketMtHowIncludedVisaLetter.tr(),
                    LocaleKeys.marketMtHowIncludedTransfer.tr(),
                  ],
                ),
                Gap(16.h),
                list(
                  LocaleKeys.marketMtHowNotIncludedTitle.tr(),
                  Icons.cancel_outlined,
                  Colour.primary,
                  [
                    LocaleKeys.marketMtHowNotIncludedVisaFees.tr(),
                    LocaleKeys.marketMtHowNotIncludedFlights.tr(),
                    LocaleKeys.marketMtHowNotIncludedMedication.tr(),
                    LocaleKeys.marketMtHowNotIncludedComplications.tr(),
                  ],
                ),
                Container(
                  margin: EdgeInsets.only(top: 12.h),
                  padding: EdgeInsets.only(top: 16.h),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colour.lineSubtle)),
                  ),
                  child: Text(
                    LocaleKeys.marketMtHowPriceNote.tr(),
                    style: metaStyle,
                  ),
                ),
              ],
            ),
          ),
          Gap(20.h),
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: Colour.seller25,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colour.seller.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _IconTile(
                  icon: Icons.lock_outline,
                  background: Colour.surface,
                ),
                Gap(16.h),
                Text(
                  LocaleKeys.marketMtHowProtectionTitle.tr(),
                  style: AppTextStyle.lightBodyXLargeSemiBold.copyWith(
                    color: Colour.textPrimary,
                  ),
                ),
                Gap(16.h),
                for (final item in [
                  LocaleKeys.marketMtHowProtectionNoPayment.tr(),
                  LocaleKeys.marketMtHowProtectionFundsHeld.tr(),
                  LocaleKeys.marketMtHowProtectionFreeCancellation.tr(),
                ])
                  Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 18.r,
                          color: Colour.seller,
                        ),
                        Gap(10.w),
                        Expanded(
                          child: Text(
                            item,
                            style: AppTextStyle.lightBodyMediumRegular.copyWith(
                              color: Colour.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Before you fly": 6 câu hỏi, mở một câu một lúc (web `FaqSection`).
class MedicalFaq extends StatefulWidget {
  const MedicalFaq({super.key});

  @override
  State<MedicalFaq> createState() => _MedicalFaqState();
}

class _MedicalFaqState extends State<MedicalFaq> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        LocaleKeys.marketMtFaqItemsCoordinatorsQ.tr(),
        LocaleKeys.marketMtFaqItemsCoordinatorsA.tr(),
      ),
      (
        LocaleKeys.marketMtFaqItemsVisaQ.tr(),
        LocaleKeys.marketMtFaqItemsVisaA.tr(),
      ),
      (
        LocaleKeys.marketMtFaqItemsPriceQ.tr(),
        LocaleKeys.marketMtFaqItemsPriceA.tr(),
      ),
      (
        LocaleKeys.marketMtFaqItemsVerificationQ.tr(),
        LocaleKeys.marketMtFaqItemsVerificationA.tr(),
      ),
      (
        LocaleKeys.marketMtFaqItemsLanguageQ.tr(),
        LocaleKeys.marketMtFaqItemsLanguageA.tr(),
      ),
      (
        LocaleKeys.marketMtFaqItemsCancelQ.tr(),
        LocaleKeys.marketMtFaqItemsCancelA.tr(),
      ),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 56.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MarketSectionHeading(
            title: LocaleKeys.marketMtFaqTitle.tr(),
            description: LocaleKeys.marketMtFaqSubtitle.tr(),
          ),
          Gap(32.h),
          MarketFaqList(
            items: items,
            openIndex: _open,
            onToggle: (i) => setState(() => _open = _open == i ? null : i),
          ),
        ],
      ),
    );
  }
}

/// Danh sách hỏi-đáp trong một card, kẻ ngang giữa các câu.
class MarketFaqList extends StatelessWidget {
  final List<(String, String)> items;
  final int? openIndex;
  final ValueChanged<int> onToggle;

  const MarketFaqList({
    super.key,
    required this.items,
    required this.openIndex,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return MarketCard(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        children: [
          for (final (i, (q, a)) in items.indexed) ...[
            if (i > 0) const Divider(height: 1, color: Colour.lineSubtle),
            InkWell(
              onTap: () => onToggle(i),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        q,
                        style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
                          color: Colour.textPrimary,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: openIndex == i ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: Colour.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (openIndex == i)
              Padding(
                padding: EdgeInsets.only(bottom: 20.h),
                child: Text(
                  a,
                  style: AppTextStyle.lightBodyMediumRegular.copyWith(
                    color: Colour.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
