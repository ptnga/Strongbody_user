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

/// Card request GỌN của trang chủ (web `RequestFeedCard`): người đăng (tên · nơi ở; ẩn danh →
/// "Anonymous" + "name hidden for privacy") + Save ở góc phải → lời yêu cầu 3 dòng có "See
/// more" → chip ngân sách / loại dịch vụ / hình thức → hành động dạng chữ ("Me too").
/// "See more" (hoặc chạm lời yêu cầu) mở rộng NGAY TẠI CHỖ: lời yêu cầu đầy đủ, ngôn ngữ (cùng
/// hàng chip), ảnh / tệp, dải hoạt động; "Show less" thu lại. Không hiện thời gian đăng.
///
/// "I can help" (provider trả lời request) là thao tác phía seller — app buyer không hiện.
class BoardRequestCard extends StatefulWidget {
  final BoardRequest request;

  const BoardRequestCard({super.key, required this.request});

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

  /// Tên hiển thị card gọn (web): công khai → "Teri M." (họ chỉ chữ cái đầu); ẩn danh /
  /// không có tên → `null` ("Anonymous").
  static String? displayName(BoardRequest r) {
    final first = r.firstName?.trim() ?? '';
    if (r.anonymous || first.isEmpty) return null;
    final last = r.lastName?.trim() ?? '';
    return last.isEmpty ? first : '$first ${last.characters.first}.';
  }

  /// "all" hiện "Remote" như web; giá trị lạ → viết hoa chữ đầu.
  static String? delivery(String? type) => switch (type) {
    null || '' => null,
    'all' => RequestFormatters.deliveryOption(RequestDeliveryType.remote),
    final d => switch (RequestDeliveryType.fromApi(d)) {
      final t? => RequestFormatters.deliveryOption(t),
      null => MarketFormatters.humanize(d),
    },
  };

  @override
  State<BoardRequestCard> createState() => _BoardRequestCardState();
}

class _BoardRequestCardState extends State<BoardRequestCard> {
  bool _expanded = false;

  BoardRequest get _r => widget.request;

  bool get _own {
    final me = getIt<GlobalStorage>().userId;
    return me != null && me == _r.userId;
  }

  void _meToo() {
    final r = _r;
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

  Future<void> _toggleSave() async {
    final cubit = context.read<EngagementCubit>();
    if (!getIt<GlobalStorage>().isLoggedIn &&
        !await showAuthSheet(context, source: 'board_engagement')) {
      return;
    }
    await cubit.toggle(_r.id, EngagementKind.save);
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final own = _own;
    final budget = BoardRequestCard.budgetText(r);
    final delivery = BoardRequestCard.delivery(r.deliveryType);
    // Ngôn ngữ người đăng muốn được hỗ trợ (tối đa 2): chỉ khi mở rộng, cùng hàng chip.
    final languages = _expanded
        ? r.languages.take(2).map(languageLabel).join(', ')
        : '';
    final chips = <Widget>[
      if (budget != null) MarketBadge(budget, tone: MarketBadgeTone.warning),
      if (r.category != null)
        MarketBadge(r.category!, tone: MarketBadgeTone.info),
      if (delivery != null) MarketBadge(delivery),
      if (languages.isNotEmpty)
        MarketBadge(languages, icon: Icons.translate_rounded),
      if (r.closed)
        MarketBadge(
          LocaleKeys.boardCardClosed.tr(),
          icon: Icons.lock_outline_rounded,
        ),
    ];
    return MarketCard(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(request: r, own: own, onSave: _toggleSave),
          Gap(12.h),
          _RequestText(
            text: r.text,
            expanded: _expanded,
            onExpand: () => setState(() => _expanded = true),
            onCollapse: () => setState(() => _expanded = false),
          ),
          if (chips.isNotEmpty) ...[
            Gap(12.h),
            Wrap(spacing: 6.w, runSpacing: 6.h, children: chips),
          ],
          Gap(16.h),
          const Divider(height: 1, color: Colour.lineSubtle),
          Gap(4.h),
          _actions(own),
          if (_expanded) ..._body(r),
        ],
      ),
    );
  }

  /// Hàng hành động dạng chữ: request của mình → "Manage my request"; còn lại "Me too"
  /// (+ "✓ Solved" khi đã giải quyết, chưa đóng).
  Widget _actions(bool own) {
    final r = _r;
    if (own) {
      return _TextAction(
        icon: Icons.edit_outlined,
        label: LocaleKeys.boardCardManageOwn.tr(),
        onTap: () => context.go(RouteName.myRequests),
      );
    }
    final meToo = _TextAction(
      icon: Icons.volunteer_activism_outlined,
      label: LocaleKeys.boardCardMeToo.tr(),
      highlighted: context.select<EngagementCubit, bool>(
        (c) => c.state.of(r.id).similar,
      ),
      onTap: r.text.trim().isEmpty ? null : _meToo,
    );
    if (r.closed || !r.solved) return meToo;
    return Row(
      children: [
        Expanded(child: meToo),
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16.r,
                  color: Colour.buttonPrimary,
                ),
                Gap(6.w),
                Text(
                  LocaleKeys.boardCardSolved.tr(),
                  style: AppTextStyle.lightBodyMediumMedium.copyWith(
                    color: Colour.buttonPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Phần mở rộng: ảnh / tệp đính kèm + dải hoạt động (khi có).
  List<Widget> _body(BoardRequest r) {
    final photos = r.attachments.where((a) => a.isPhoto).toList();
    final files = r.attachments.where((a) => !a.isPhoto).toList();
    return [
      if (photos.isNotEmpty) ...[Gap(8.h), _Photos(photos: photos)],
      if (files.isNotEmpty) ...[
        Gap(8.h),
        Wrap(
          spacing: 6.w,
          runSpacing: 6.h,
          children: [
            for (final (i, f) in files.indexed)
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
      _Activity(request: r),
    ];
  }
}

class _Header extends StatelessWidget {
  final BoardRequest request;
  final bool own;
  final VoidCallback onSave;

  const _Header({
    required this.request,
    required this.own,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final r = request;
    final name = BoardRequestCard.displayName(r);
    final nameStyle = AppTextStyle.lightBodyLargeSemiBold.copyWith(
      height: 1.35,
      color: Colour.textPrimary,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name == null)
          Container(
            width: 44.r,
            height: 44.r,
            decoration: const BoxDecoration(
              color: Colour.subtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline_rounded,
              size: 20.r,
              color: Colour.textSecondary,
            ),
          )
        else
          InitialsAvatar(
            name: name,
            imageUrl: r.avatar,
            colorSeed: name.hashCode,
            size: 44.r,
          ),
        Gap(12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: name ?? LocaleKeys.boardCardAnonymous.tr()),
                    if (r.country != null) ...[
                      const TextSpan(
                        text: '  ·  ',
                        style: TextStyle(color: Colour.textTertiary),
                      ),
                      // Cờ + nước không tách dòng.
                      if (r.flag != null)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(end: 6.w),
                            child: CountryFlag(r.flag),
                          ),
                        ),
                      TextSpan(text: r.country),
                    ],
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: nameStyle,
              ),
              // Người đăng chọn ẩn danh → nói rõ tên được che để bảo vệ riêng tư.
              if (name == null) ...[
                Gap(2.h),
                Text(
                  LocaleKeys.boardCardNameHidden.tr(),
                  style: AppTextStyle.lightBodySmallRegular.copyWith(
                    color: Colour.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Lưu request: góc phải trên (card gọn không có nút tim). Request của mình: không lưu.
        if (!own)
          BlocBuilder<EngagementCubit, EngagementCubitState>(
            buildWhen: (a, b) =>
                a.of(r.id).saved != b.of(r.id).saved || a.pending != b.pending,
            builder: (context, state) => Transform.translate(
              offset: Offset(6.w, -6.h),
              child: EngagementToggle(
                like: false,
                on: state.of(r.id).saved,
                busy: state.isPending(r.id, EngagementKind.save),
                onTap: onSave,
              ),
            ),
          ),
      ],
    );
  }
}

/// Lời yêu cầu: 3 dòng + "… See more" khi tràn (chạm chữ cũng mở); mở rộng → đầy đủ +
/// "Show less" ngay sau chữ.
class _RequestText extends StatelessWidget {
  final String text;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;

  const _RequestText({
    required this.text,
    required this.expanded,
    required this.onExpand,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyle.lightBodyMediumRegular.copyWith(
      height: 1.6,
      color: Colour.textPrimary,
    );
    final linkStyle = AppTextStyle.lightBodyMediumMedium.copyWith(
      height: 1.6,
      color: Colour.textPrimary,
      decoration: TextDecoration.underline,
    );
    if (expanded) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$text '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: onCollapse,
                child: Text(
                  LocaleKeys.boardCardShowLess.tr(),
                  style: linkStyle,
                ),
              ),
            ),
          ],
        ),
        style: style,
      );
    }
    return GestureDetector(
      onTap: onExpand,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final more = LocaleKeys.boardCardSeeMore.tr();
          final direction = Directionality.of(context);
          final scale = MediaQuery.textScalerOf(context);
          // Không bị cắt (kể cả "See more" đứng ngay sau chữ) → "See more" sau chữ;
          // bị cắt → "… See more" đè cuối dòng 3.
          final inline = TextPainter(
            text: TextSpan(
              children: [
                TextSpan(text: '$text ', style: style),
                TextSpan(text: more, style: linkStyle),
              ],
            ),
            maxLines: 3,
            textDirection: direction,
            textScaler: scale,
          )..layout(maxWidth: constraints.maxWidth);
          if (!inline.didExceedMaxLines) {
            return Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$text '),
                  TextSpan(text: more, style: linkStyle),
                ],
              ),
              style: style,
            );
          }
          return Stack(
            children: [
              Text(
                text,
                maxLines: 3,
                overflow: TextOverflow.clip,
                style: style,
              ),
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: ColoredBox(
                  color: Colour.surface,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(start: 4.w),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: '… '),
                          TextSpan(text: more, style: linkStyle),
                        ],
                      ),
                      style: style,
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

/// Hành động dạng chữ (web `part="actions"`): icon + nhãn màu xanh, căn giữa.
class _TextAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;

  const _TextAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? Colour.textTertiary : Colour.buttonPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              highlighted ? Icons.volunteer_activism : icon,
              size: 18.r,
              color: color,
            ),
            Gap(6.w),
            Flexible(
              child: Text(
                label,
                style: AppTextStyle.lightBodyMediumMedium.copyWith(
                  color: color,
                  decoration: highlighted ? TextDecoration.underline : null,
                  decorationColor: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dải hoạt động khi mở rộng (web): avatar người đã đề xuất + "{n} experts offered" ·
/// "{n} need this too" · "{n} likes". Chưa có hoạt động nào → không hiện.
class _Activity extends StatelessWidget {
  final BoardRequest request;

  const _Activity({required this.request});

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyle.lightBodySmallRegular.copyWith(
      color: Colour.textSecondary,
    );
    return BlocBuilder<EngagementCubit, EngagementCubitState>(
      buildWhen: (a, b) => a.of(request.id) != b.of(request.id),
      builder: (context, state) {
        final e = state.of(request.id);
        if (e.contacts <= 0 && e.similars <= 0 && e.likes <= 0) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.only(top: 12.h),
          child: Container(
            padding: EdgeInsets.only(top: 8.h),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colour.lineSubtle)),
            ),
            child: Wrap(
              spacing: 12.w,
              runSpacing: 4.h,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (e.contacts > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (e.recentContacts.isEmpty)
                        Icon(
                          Icons.forum_outlined,
                          size: 14.r,
                          color: Colour.seller800,
                        )
                      else
                        for (final (i, c) in e.recentContacts.take(3).indexed)
                          Transform.translate(
                            offset: Offset(-6.w * i, 0),
                            child: InitialsAvatar(
                              name: c.name,
                              imageUrl: c.avatar,
                              colorSeed: c.name.hashCode,
                              size: 20.r,
                              border: true,
                            ),
                          ),
                      Gap(4.w),
                      Text(
                        pluralTr(
                          e.contacts,
                          one: LocaleKeys.boardCardOfferedCountOne,
                          other: LocaleKeys.boardCardOfferedCountOther,
                        ),
                        style: AppTextStyle.lightBodySmallSemiBold.copyWith(
                          color: Colour.seller800,
                        ),
                      ),
                    ],
                  ),
                if (e.similars > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.volunteer_activism_outlined,
                        size: 14.r,
                        color: Colour.textSecondary,
                      ),
                      Gap(4.w),
                      Text(
                        pluralTr(
                          e.similars,
                          one: LocaleKeys.boardCardMeTooCountOne,
                          other: LocaleKeys.boardCardMeTooCountOther,
                        ),
                        style: style,
                      ),
                    ],
                  ),
                if (e.likes > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, size: 14.r, color: Colour.primary),
                      Gap(4.w),
                      Text(
                        pluralTr(
                          e.likes,
                          one: LocaleKeys.boardCardLikeCountOne,
                          other: LocaleKeys.boardCardLikeCountOther,
                        ),
                        style: style,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
