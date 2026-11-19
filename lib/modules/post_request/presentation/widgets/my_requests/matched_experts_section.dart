import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/components/initials_avatar.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/core/utils/plural_tr.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_page_args.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_expert_card.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_ui.dart';

import '../../../domain/entities/my_request_entity.dart';
import '../../bloc/matched_providers/matched_providers_cubit.dart';

/// "Sent to N matched experts" + "Show experts" / "Hide" trên thẻ My requests (web
/// `RequestItem` + `MatchedProviders`): BE đã gửi thẳng request tới các chuyên gia khớp dịch
/// vụ AI gán; bung danh sách ngay tại chỗ — card chuyên gia như trang category, badge
/// "Replied" + nút Chat (card request đã nằm sẵn trong hội thoại). Chỉ tải lần đầu mở.
class MatchedExpertsSection extends StatefulWidget {
  final int requestId;
  final int count;

  const MatchedExpertsSection({
    super.key,
    required this.requestId,
    required this.count,
  });

  @override
  State<MatchedExpertsSection> createState() => _MatchedExpertsSectionState();
}

class _MatchedExpertsSectionState extends State<MatchedExpertsSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Tạo khi mở lần đầu; giữ danh sách đã tải khi thu lại / mở lại.
      create: (_) => getIt<MatchedProvidersCubit>(),
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_outlined, size: 18.r, color: Colour.success),
                Gap(6.w),
                Expanded(
                  child: Text(
                    pluralTr(
                      widget.count,
                      one: LocaleKeys.myRequestsMatchedCountOne,
                      other: LocaleKeys.myRequestsMatchedCountOther,
                    ),
                    style: AppTextStyle.lightBodyMediumMedium.copyWith(
                      color: Colour.success,
                    ),
                  ),
                ),
                Gap(8.w),
                InkWell(
                  borderRadius: BorderRadius.circular(8.r),
                  onTap: () {
                    setState(() => _open = !_open);
                    if (_open) {
                      context.read<MatchedProvidersCubit>().open(
                        widget.requestId,
                      );
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 6.h,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _open
                              ? LocaleKeys.myRequestsMatchedHide.tr()
                              : LocaleKeys.myRequestsMatchedShow.tr(),
                          style: AppTextStyle.lightBodyMediumMedium.copyWith(
                            color: Colour.textPrimary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        Icon(
                          _open
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18.r,
                          color: Colour.textPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_open) const _MatchedList(),
          ],
        ),
      ),
    );
  }
}

class _MatchedList extends StatelessWidget {
  const _MatchedList();

  @override
  Widget build(BuildContext context) {
    final metaStyle = AppTextStyle.lightBodySmallRegular.copyWith(
      height: 1.4,
      color: Colour.textSecondary,
    );
    return BlocBuilder<MatchedProvidersCubit, MatchedProvidersState>(
      builder: (context, state) {
        final cubit = context.read<MatchedProvidersCubit>();
        return Padding(
          padding: EdgeInsets.only(top: 8.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                LocaleKeys.myRequestsMatchedTitle.tr(),
                style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                  color: Colour.textPrimary,
                ),
              ),
              Gap(2.h),
              Text(LocaleKeys.myRequestsMatchedHint.tr(), style: metaStyle),
              for (final p in state.items) ...[
                Gap(10.h),
                _MatchedExpert(provider: p),
              ],
              if (state.status == MatchedProvidersStatus.failure)
                Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6.w,
                    children: [
                      Text(
                        LocaleKeys.myRequestsMatchedError.tr(),
                        style: metaStyle,
                      ),
                      MarketButton(
                        label: LocaleKeys.commonTryAgain.tr(),
                        variant: MarketButtonVariant.more,
                        onPressed: cubit.loadMore,
                      ),
                    ],
                  ),
                )
              else if (state.status == MatchedProvidersStatus.loading ||
                  state.isFirstLoad)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: const Center(child: CupertinoActivityIndicator()),
                )
              else if (state.hasMore)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MarketButton(
                    label: LocaleKeys.myRequestsMatchedMore.tr(),
                    variant: MarketButtonVariant.more,
                    onPressed: cubit.loadMore,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Card chuyên gia như trang category (hồ sơ không còn công khai → hàng gọn từ tên / ảnh /
/// nước) + "Replied" + nút Chat.
class _MatchedExpert extends StatelessWidget {
  final MatchedProviderEntity provider;

  const _MatchedExpert({required this.provider});

  void _chat(BuildContext context) => context.push(
    RouteName.chat,
    extra: ChatPageArgs(
      partnerId: provider.userId,
      name: provider.expert?.name ?? provider.name,
      avatar: provider.expert?.avatar ?? provider.avatar,
      profession: provider.expert?.subtitle,
      source: 'my_requests_matched',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (p.replied) ...[
          MarketBadge(
            LocaleKeys.myRequestsMatchedReplied.tr(),
            tone: MarketBadgeTone.seller,
          ),
          Gap(8.w),
        ],
        MarketButton(
          label: LocaleKeys.myRequestsMatchedChat.tr(),
          variant: MarketButtonVariant.outline,
          onPressed: () => _chat(context),
        ),
      ],
    );
    final expert = p.expert;
    if (expert != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MarketExpertCard(expert: expert, showEngagement: false),
          Gap(8.h),
          actions,
        ],
      );
    }
    final name = p.name.isEmpty ? LocaleKeys.marketFallbackSeller.tr() : p.name;
    return MarketCard(
      padding: EdgeInsets.all(12.r),
      child: Row(
        children: [
          InitialsAvatar(
            name: name,
            imageUrl: p.avatar,
            colorSeed: p.userId,
            size: 44.r,
          ),
          Gap(10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                    color: Colour.textPrimary,
                  ),
                ),
                if (p.country != null) ...[
                  Gap(2.h),
                  Row(
                    children: [
                      if (p.flag != null) ...[CountryFlag(p.flag), Gap(6.w)],
                      Flexible(
                        child: Text(
                          p.country!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.lightBodySmallRegular.copyWith(
                            color: Colour.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Gap(8.w),
          actions,
        ],
      ),
    );
  }
}
