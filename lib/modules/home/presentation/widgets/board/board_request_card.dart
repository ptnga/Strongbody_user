import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/components/initials_avatar.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/core/utils/language_names.dart';
import 'package:strongbody_buyer/core/utils/plural_tr.dart';
import 'package:strongbody_buyer/modules/auth/presentation/widgets/auth_sheet.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_form_values.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/post_request_flow_args.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/request_formatters.dart';
import 'package:strongbody_buyer/modules/social_market/data/mappers/market_mapper.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_feed_entities.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/engagement/engagement_cubit.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/market_formatters.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_image_viewer.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_ui.dart';

import '../../../domain/entities/board_entities.dart';

/// Thẻ request của board (web `BoardRequestCard`): người đăng (ẩn danh → "***") ·
/// nước · thời gian → nội dung → ảnh / file → hình thức · ngôn ngữ → "Willing to pay"
/// → "Me too" (đăng request tương tự) → dải hoạt động + Like / Save.
///
/// "I can help" (provider trả lời request) là thao tác phía seller — app buyer không hiện.
class BoardRequestCard extends StatelessWidget {
  final BoardRequest request;

  const BoardRequestCard({super.key, required this.request});

  bool get _own {
    final me = getIt<GlobalStorage>().userId;
    return me != null && me == request.userId;
  }

  void _meToo(BuildContext context) {
    final r = request;
    context.push(
      RouteName.postRequest,
      extra: PostRequestFlowArgs(
        prefill: RequestFormValues(
          description: r.text,
          // "all" = cả 4 hình thức (web `requestDeliveryTypes`).
          deliveryTypes: r.deliveryType == 'all'
              ? RequestDeliveryType.values
              : [?RequestDeliveryType.fromApi(r.deliveryType ?? '')],
          similarToRequestId: r.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = request;
    final own = _own;
    return MarketCard(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(request: r),
          Gap(12.h),
          _QuotedText(r.text),
          if (r.attachments.any((a) => a.isPhoto)) ...[
            Gap(12.h),
            _Photos(photos: r.attachments.where((a) => a.isPhoto).toList()),
          ],
          if (r.attachments.any((a) => !a.isPhoto)) ...[
            Gap(8.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: [
                for (final (i, f)
                    in r.attachments.where((a) => !a.isPhoto).indexed)
                  MarketBadge(
                    f.name ??
                        LocaleKeys.boardCardFileN.tr(
                          namedArgs: {'index': '${i + 1}'},
                        ),
                    icon: Icons.attach_file_rounded,
                  ),
              ],
            ),
          ],
          ..._chips(r),
          if (budgetText(r) case final budget?) ...[
            Gap(12.h),
            Row(
              children: [
                Text(
                  LocaleKeys.boardCardWillingToPay.tr(),
                  style: AppTextStyle.lightBodySmallRegular.copyWith(
                    color: Colour.textSecondary,
                  ),
                ),
                Gap(8.w),
                Flexible(
                  child: Text(
                    budget,
                    style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
                      color: Colour.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          Gap(14.h),
          _actions(context, own),
          Gap(12.h),
          const Divider(height: 1, color: Colour.lineSubtle),
          Gap(8.h),
          _Activity(request: r, own: own),
        ],
      ),
    );
  }

  List<Widget> _chips(BoardRequest r) {
    final delivery = switch (r.deliveryType) {
      null || '' => null,
      // "all" hiện "Remote" như web.
      'all' => RequestFormatters.deliveryOption(RequestDeliveryType.remote),
      final d => switch (RequestDeliveryType.fromApi(d)) {
        final type? => RequestFormatters.deliveryOption(type),
        null => MarketFormatters.humanize(d),
      },
    };
    final languages = r.languages.take(2).map(languageLabel).join(', ');
    if (delivery == null && languages.isEmpty) return const [];
    return [
      Gap(12.h),
      Wrap(
        spacing: 6.w,
        runSpacing: 6.h,
        children: [
          if (delivery != null)
            MarketBadge(delivery, icon: Icons.location_on_outlined),
          if (languages.isNotEmpty)
            MarketBadge(languages, icon: Icons.translate_rounded),
        ],
      ),
    ];
  }

  Widget _actions(BuildContext context, bool own) {
    final r = request;
    if (own) {
      return _ActionButton(
        icon: Icons.edit_outlined,
        label: LocaleKeys.boardCardManageOwn.tr(),
        onTap: () => context.go(RouteName.myRequests),
      );
    }
    final meToo = _ActionButton(
      icon: Icons.groups_outlined,
      label: LocaleKeys.boardCardMeToo.tr(),
      highlighted: context.select<EngagementCubit, bool>(
        (c) => c.state.of(r.id).similar,
      ),
      onTap: r.text.trim().isEmpty ? null : () => _meToo(context),
    );
    if (r.closed || !r.solved) return meToo;
    return Row(
      children: [
        Expanded(child: meToo),
        Gap(8.w),
        Expanded(
          child: Center(
            child: Text(
              '✓ ${LocaleKeys.boardCardSolved.tr()}',
              style: AppTextStyle.lightBodyMediumMedium.copyWith(
                color: Colour.success,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "100" / "50 – 80" / "From 50" / "Up to 80" (web `formatBudget`); null = không có.
  static String? budgetText(BoardRequest r) {
    String money(num v) => MarketMapper.formatMoney(v, r.currency);
    final min = r.minBudget;
    final max = r.maxBudget;
    if (min != null && max != null) {
      return min == max
          ? money(min)
          : LocaleKeys.boardBudgetRange.tr(
              namedArgs: {'min': money(min), 'max': money(max)},
            );
    }
    if (min != null) {
      return LocaleKeys.boardBudgetFrom.tr(namedArgs: {'min': money(min)});
    }
    if (max != null) {
      return LocaleKeys.boardBudgetUpTo.tr(namedArgs: {'max': money(max)});
    }
    return r.budget == null ? null : money(r.budget!);
  }
}

class _Header extends StatelessWidget {
  final BoardRequest request;

  const _Header({required this.request});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final name = r.anonymous ? '' : r.authorName;
    final meta = [
      ?r.country,
      if (r.createdAt != null) MarketFormatters.timeAgo(r.createdAt),
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.anonymous || name.isEmpty)
          Container(
            width: 40.r,
            height: 40.r,
            decoration: const BoxDecoration(
              color: Colour.subtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline_rounded,
              size: 22.r,
              color: Colour.textSecondary,
            ),
          )
        else
          InitialsAvatar(
            name: name,
            imageUrl: r.avatar,
            colorSeed: name.hashCode,
            size: 40.r,
          ),
        Gap(10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      r.anonymous || name.isEmpty ? '***' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.lightBodyMediumMedium.copyWith(
                        color: Colour.textPrimary,
                      ),
                    ),
                  ),
                  if (r.anonymous) ...[
                    Gap(4.w),
                    Tooltip(
                      message: LocaleKeys.boardCardAnonymous.tr(),
                      child: Icon(
                        Icons.visibility_off_outlined,
                        size: 14.r,
                        color: Colour.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
              if (meta.isNotEmpty) ...[
                Gap(2.h),
                Row(
                  children: [
                    if (r.flag != null && r.country != null) ...[
                      CountryFlag(r.flag),
                      Gap(6.w),
                    ],
                    Flexible(
                      child: Text(
                        meta,
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
        if (r.closed || r.category != null) ...[
          Gap(8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (r.closed)
                MarketBadge(
                  LocaleKeys.boardCardClosed.tr(),
                  icon: Icons.lock_outline_rounded,
                ),
              if (r.closed && r.category != null) Gap(4.h),
              if (r.category != null)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 130.w),
                  child: MarketBadge(r.category!),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Nội dung dạng trích dẫn (vạch trái), 3 dòng + "See more" khi tràn.
class _QuotedText extends StatefulWidget {
  final String text;

  const _QuotedText(this.text);

  @override
  State<_QuotedText> createState() => _QuotedTextState();
}

class _QuotedTextState extends State<_QuotedText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyle.lightBodyMediumRegular.copyWith(
      height: 1.45,
      color: Colour.textPrimary,
    );
    return Container(
      padding: EdgeInsets.only(left: 12.w),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Colour.lineStrong, width: 3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            maxLines: 3,
            textDirection: Directionality.of(context),
          )..layout(maxWidth: constraints.maxWidth);
          final overflows = painter.didExceedMaxLines;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.text,
                maxLines: _open ? null : 3,
                overflow: _open ? null : TextOverflow.ellipsis,
                style: style,
              ),
              if (overflows)
                GestureDetector(
                  onTap: () => setState(() => _open = !_open),
                  child: Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text(
                      _open
                          ? LocaleKeys.boardCardSeeLess.tr()
                          : LocaleKeys.boardCardSeeMore.tr(),
                      style: AppTextStyle.lightBodySmallMedium.copyWith(
                        color: Colour.textPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 1 ảnh → khung 16:9; 2+ → 3 ô vuông, ô thứ 3 phủ "+N".
class _Photos extends StatelessWidget {
  final List<BoardAttachment> photos;

  const _Photos({required this.photos});

  @override
  Widget build(BuildContext context) {
    final urls = photos.map((p) => p.url).toList();
    void open(int i) =>
        showMarketImageViewer(context, images: urls, initialIndex: i);
    Widget tile(int i, {Widget? overlay}) => GestureDetector(
      onTap: () => open(i),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              urls[i],
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: Colour.subtle),
            ),
            ?overlay,
          ],
        ),
      ),
    );
    if (urls.length == 1) {
      return AspectRatio(aspectRatio: 16 / 9, child: tile(0));
    }
    final shown = urls.length.clamp(0, 3);
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) Gap(6.w),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: i >= shown
                  ? const SizedBox()
                  : tile(
                      i,
                      overlay: i == 2 && urls.length > 3
                          ? ColoredBox(
                              color: Colors.black.withValues(alpha: 0.45),
                              child: Center(
                                child: Text(
                                  '+${urls.length - 3}',
                                  style: AppTextStyle.lightBodyLargeSemiBold
                                      .copyWith(color: Colors.white),
                                ),
                              ),
                            )
                          : null,
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 40.h,
    child: OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colour.textPrimary,
        backgroundColor: highlighted ? Colour.subtle : null,
        side: const BorderSide(color: Colour.lineStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        textStyle: AppTextStyle.lightBodyMediumMedium,
      ),
      icon: Icon(icon, size: 18.r),
      label: Text(label),
    ),
  );
}

/// Dải hoạt động (web): avatar người đã trả lời + "{n} replied" (hoặc "Be the first to
/// respond") · "{n} need this too" · "{n} likes" — bên phải Like / Save.
class _Activity extends StatelessWidget {
  final BoardRequest request;
  final bool own;

  const _Activity({required this.request, required this.own});

  Future<void> _toggle(BuildContext context, EngagementKind kind) async {
    final cubit = context.read<EngagementCubit>();
    if (!getIt<GlobalStorage>().isLoggedIn &&
        !await showAuthSheet(context, source: 'board_engagement')) {
      return;
    }
    await cubit.toggle(request.id, kind);
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyle.lightBodySmallRegular.copyWith(
      color: Colour.textSecondary,
    );
    return BlocBuilder<EngagementCubit, EngagementCubitState>(
      buildWhen: (a, b) =>
          a.of(request.id) != b.of(request.id) || a.pending != b.pending,
      builder: (context, state) {
        final e = state.of(request.id);
        final parts = <Widget>[
          if (e.contacts > 0) ...[
            for (final (i, c) in e.recentContacts.take(3).indexed)
              Transform.translate(
                offset: Offset(-6.w * i, 0),
                child: InitialsAvatar(
                  name: c.name,
                  imageUrl: c.avatar,
                  colorSeed: c.name.hashCode,
                  size: 22.r,
                  border: true,
                ),
              ),
            if (e.recentContacts.isEmpty)
              Icon(
                Icons.forum_outlined,
                size: 16.r,
                color: Colour.textSecondary,
              ),
            Gap(4.w),
            Text(
              LocaleKeys.boardCardRepliedCount.tr(
                namedArgs: {'count': '${e.contacts}'},
              ),
              style: style,
            ),
          ] else if (e.similars == 0 && e.likes == 0)
            Text(LocaleKeys.boardCardNoActivity.tr(), style: style),
          if (e.similars > 0) ...[
            Text('  ·  ', style: style),
            Text(
              pluralTr(
                e.similars,
                one: LocaleKeys.boardCardMeTooCountOne,
                other: LocaleKeys.boardCardMeTooCountOther,
              ),
              style: style,
            ),
          ],
          if (e.likes > 0) ...[
            Text('  ·  ', style: style),
            Text(
              pluralTr(
                e.likes,
                one: LocaleKeys.boardCardLikeCountOne,
                other: LocaleKeys.boardCardLikeCountOther,
              ),
              style: style,
            ),
          ],
        ];
        return Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: parts),
              ),
            ),
            // Request của mình: không tự thích / lưu.
            if (!own) ...[
              EngagementToggle(
                like: true,
                on: e.liked,
                busy: state.isPending(request.id, EngagementKind.like),
                onTap: () => _toggle(context, EngagementKind.like),
              ),
              EngagementToggle(
                like: false,
                on: e.saved,
                busy: state.isPending(request.id, EngagementKind.save),
                onTap: () => _toggle(context, EngagementKind.save),
              ),
            ],
          ],
        );
      },
    );
  }
}
