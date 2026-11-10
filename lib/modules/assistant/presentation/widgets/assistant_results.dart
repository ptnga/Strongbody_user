import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/market_navigation.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_expert_card.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_offer_card.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_service_card.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_ui.dart';

import '../../domain/entities/assistant_entities.dart';

/// Thẻ kết quả theo nhóm (web `ResultGroups`): nhóm khách hỏi tới lên trước, mỗi nhóm tối
/// đa [limit] thẻ + "4 of 120". `close` = nhóm "Close matches" kèm điều kiện chưa khớp.
class AssistantResultGroups extends StatelessWidget {
  final AssistantResult result;
  final Map<AssistantKind, List<AssistantCard>> groups;
  final int limit;
  final bool close;

  const AssistantResultGroups({
    super.key,
    required this.result,
    required this.groups,
    this.limit = 4,
    this.close = false,
  });

  /// Thứ tự BE (`kinds`) rồi tới thứ tự mặc định services → sellers → offers.
  List<AssistantKind> _orderedKinds() {
    final have = [
      for (final k in AssistantKind.values)
        if (groups[k]?.isNotEmpty ?? false) k,
    ];
    final first = result.kinds.where(have.contains).toList();
    return [...first, ...have.where((k) => !first.contains(k))];
  }

  static String _title(AssistantKind kind) => switch (kind) {
    AssistantKind.services => LocaleKeys.assistantGroupsServices.tr(),
    AssistantKind.sellers => LocaleKeys.assistantGroupsSellers.tr(),
    AssistantKind.publicOffers => LocaleKeys.assistantGroupsPublicOffers.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final kinds = _orderedKinds();
    if (kinds.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, kind) in kinds.indexed) ...[
          if (i > 0) Gap(16.h),
          _Group(
            title: close ? LocaleKeys.assistantCloseMatches.tr() : _title(kind),
            total: close ? null : result.totals[kind],
            cards: groups[kind]!.take(limit).toList(),
            close: close,
          ),
        ],
      ],
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final int? total;
  final List<AssistantCard> cards;
  final bool close;

  const _Group({
    required this.title,
    required this.total,
    required this.cards,
    required this.close,
  });

  @override
  Widget build(BuildContext context) {
    final total = this.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
                  color: Colour.textPrimary,
                ),
              ),
            ),
            if (total != null && total > cards.length)
              Text(
                LocaleKeys.assistantShownOf.tr(
                  namedArgs: {'shown': '${cards.length}', 'total': '$total'},
                ),
                style: AppTextStyle.lightBodySmallRegular.copyWith(
                  color: Colour.textSecondary,
                ),
              ),
          ],
        ),
        for (final card in cards) ...[
          Gap(12.h),
          if (close && card.missing.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: MarketBadge(
                LocaleKeys.assistantMissingLabel.tr(
                  namedArgs: {
                    'items': card.missing.map(assistantMissingLabel).join(', '),
                  },
                ),
                tone: MarketBadgeTone.warning,
                icon: Icons.info_outline_rounded,
              ),
            ),
            Gap(8.h),
          ],
          AssistantResultCard(card: card),
          if (card.hasPlaceLine) ...[Gap(6.h), _PlaceLine(card: card)],
        ],
      ],
    );
  }
}

/// Nhãn điều kiện chưa khớp / đã nới (web `missing.*`).
String assistantMissingLabel(AssistantMissing m) => switch (m) {
  AssistantMissing.languages => LocaleKeys.assistantMissingLanguages.tr(),
  AssistantMissing.gender => LocaleKeys.assistantMissingGender.tr(),
  AssistantMissing.delivery => LocaleKeys.assistantMissingDelivery.tr(),
  AssistantMissing.price => LocaleKeys.assistantMissingPrice.tr(),
  AssistantMissing.verified => LocaleKeys.assistantMissingVerified.tr(),
  AssistantMissing.experienced => LocaleKeys.assistantMissingExperienced.tr(),
  AssistantMissing.distance => LocaleKeys.assistantMissingDistance.tr(),
};

/// Dòng vị trí của thẻ (web `PlaceLine`): khoảng cách tới khách; thẻ chuyên gia ghi cả địa
/// chỉ (thẻ dịch vụ đã có địa chỉ trong card).
class _PlaceLine extends StatelessWidget {
  final AssistantCard card;

  const _PlaceLine({required this.card});

  @override
  Widget build(BuildContext context) {
    final km = card.distanceKm;
    final text = [
      ?card.address,
      if (km != null)
        LocaleKeys.assistantDistanceAway.tr(
          namedArgs: {'km': AssistantCard.formatKm(km)},
        ),
    ].join(' · ');
    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 16.r,
          color: Colour.textSecondary,
        ),
        Gap(6.w),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.lightBodySmallRegular.copyWith(
              color: Colour.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Một thẻ: dùng lại card Social Market, ẩn like / save (web `showEngagement={false}`).
class AssistantResultCard extends StatelessWidget {
  final AssistantCard card;

  const AssistantResultCard({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    if (card.service case final s?) {
      return MarketServiceCard(
        service: s,
        showEngagement: false,
        onInquiry: () => MarketNavigation.inquireService(context, s),
        onViewAndBook: () => MarketNavigation.viewAndBook(context, s),
        onTap: () => MarketNavigation.openService(context, s),
      );
    }
    if (card.seller case final e?) {
      return MarketExpertCard(expert: e, showEngagement: false);
    }
    if (card.offer case final o?) {
      return MarketOfferCard(
        offer: o,
        index: o.id ?? 0,
        showEngagement: false,
        onWantThis: () => MarketNavigation.inquireOffer(context, o),
      );
    }
    return const SizedBox.shrink();
  }
}
