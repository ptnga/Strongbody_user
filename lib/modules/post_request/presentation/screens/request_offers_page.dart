import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/components/empty_state_view.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_page_args.dart';
import 'package:strongbody_buyer/modules/checkout/presentation/widgets/offer_checkout_sheet.dart';

import '../../domain/entities/my_request_entity.dart';
import '../bloc/request_offers/request_offers_bloc.dart';
import '../request_offers_page_args.dart';
import '../request_formatters.dart';
import '../widgets/my_requests/offer_card.dart';

/// "Offers" — mọi offer provider gửi cho một request; chưa có thì báo chưa có offer.
/// Mở từ "Details" trong chat → in đậm viền + cuộn tới offer đó; mở thường → không in đậm.
class RequestOffersPage extends StatefulWidget {
  final RequestOffersPageArgs args;

  const RequestOffersPage({super.key, required this.args});

  @override
  State<RequestOffersPage> createState() => _RequestOffersPageState();
}

class _RequestOffersPageState extends State<RequestOffersPage> {
  static const _listBackground = Color(0xFFF4F6F9);

  final _highlightKey = GlobalKey();
  bool _scrolledToHighlight = false;

  void _scrollToHighlight() {
    if (_scrolledToHighlight || widget.args.highlightOfferId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _highlightKey.currentContext;
      if (target == null || !mounted) return;
      _scrolledToHighlight = true;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        alignment: 0.05,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<RequestOffersBloc, RequestOffersState>(
      builder: (context, state) {
        final request = widget.args.request ?? state.request;
        return Scaffold(
          backgroundColor: _listBackground,
          body: Column(
            children: [
              Container(
                color: theme.surface(context),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 10.h),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: theme.textPrimary(context),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocaleKeys.offersTitle.tr(),
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textPrimary(context),
                                ),
                              ),
                              if (request != null)
                                Text(
                                  RequestFormatters.headline(
                                    request.description,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: theme.textSecondary(context),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: theme.border(context)),
              Expanded(child: _list(context, state, request)),
            ],
          ),
        );
      },
    );
  }

  Widget _list(
    BuildContext context,
    RequestOffersState state,
    MyRequestEntity? request,
  ) {
    if (state.status == RequestOffersStatus.loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    final offers = state.sortedOffers;
    final highlightId = widget.args.highlightOfferId;
    if (offers.isNotEmpty) _scrollToHighlight();
    return RefreshIndicator(
      onRefresh: () async => context.read<RequestOffersBloc>().add(
        RequestOffersStarted(widget.args.requestId),
      ),
      child: offers.isEmpty
          ? _EmptyState(
              failed: state.status == RequestOffersStatus.failure,
              onRefresh: () => context.read<RequestOffersBloc>().add(
                RequestOffersStarted(widget.args.requestId),
              ),
            )
          // Không lazy: cần dựng đủ thẻ để cuộn tới offer được in đậm.
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
              children: [
                _SortChips(
                  selected: state.sort,
                  onChanged: (sort) {
                    AppAnalytics.capture(AnalyticsEvents.offersSortChanged, {
                      'sort': sort.name,
                    });
                    context.read<RequestOffersBloc>().add(
                      RequestOffersSortChanged(sort),
                    );
                  },
                ),
                for (var i = 0; i < offers.length; i++) ...[
                  Gap(i == 0 ? 12.h : 14.h),
                  OfferCard(
                    key: offers[i].id == highlightId
                        ? _highlightKey
                        : ValueKey(offers[i].id),
                    offer: offers[i],
                    index: i,
                    highlighted: offers[i].id == highlightId,
                    deliveryTypes: request?.details.deliveryTypes ?? const [],
                    fallbackCurrency: request?.details.currency ?? 'USD',
                    onReply: () => _reply(context, offers[i]),
                    onAccept: () => _acceptAndPay(
                      context,
                      offers[i],
                      widget.args.requestId,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// "Accept & Pay" → sheet thanh toán (luồng web checkout); trả xong thì tải lại offer.
Future<void> _acceptAndPay(
  BuildContext context,
  RequestOfferEntity offer,
  int pageRequestId,
) async {
  final bloc = context.read<RequestOffersBloc>();
  final requestId = offer.requestId ?? offer.request?.id ?? pageRequestId;
  if (await showOfferCheckoutSheet(context, offer: offer, source: 'offers')) {
    bloc.add(RequestOffersStarted(requestId));
  }
}

/// "Reply" → chat 1:1 với provider của offer.
void _reply(BuildContext context, RequestOfferEntity offer) {
  final sellerId = offer.sellerId;
  AppAnalytics.capture(AnalyticsEvents.offerReplyTapped, {
    'offer_id': offer.id,
    'request_id': offer.requestId ?? offer.request?.id,
    'seller_id': sellerId,
  });
  if (sellerId == null) {
    ToastUtil.showError(LocaleKeys.chatConnectError.tr());
    return;
  }
  context.push(
    RouteName.chat,
    extra: ChatPageArgs(
      partnerId: sellerId,
      name: offer.sellerName,
      avatar: offer.sellerAvatar,
      profession: offer.profession,
      focusOfferId: offer.id,
      source: 'offer_reply',
    ),
  );
}

class _SortChips extends StatelessWidget {
  final OfferSort selected;
  final ValueChanged<OfferSort> onChanged;

  const _SortChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String label(OfferSort sort) => switch (sort) {
      OfferSort.bestMatch => LocaleKeys.offersSortBest.tr(),
      OfferSort.lowestPrice => LocaleKeys.offersSortLowest.tr(),
      OfferSort.soonest => LocaleKeys.offersSortSoonest.tr(),
    };
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final sort in OfferSort.values)
          GestureDetector(
            onTap: () => onChanged(sort),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
              decoration: BoxDecoration(
                color: sort == selected
                    ? theme.secondary(context)
                    : theme.surface(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: sort == selected
                      ? theme.secondary(context)
                      : theme.border(context),
                ),
              ),
              child: Text(
                label(sort),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: sort == selected
                      ? Colors.white
                      : theme.textPrimary(context),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Chưa có offer (hoặc lỗi tải) — vẫn kéo để làm mới được.
class _EmptyState extends StatelessWidget {
  final bool failed;
  final VoidCallback onRefresh;

  const _EmptyState({required this.failed, required this.onRefresh});

  @override
  Widget build(BuildContext context) => failed
      ? EmptyStateView(
          icon: Icons.cloud_off_rounded,
          title: LocaleKeys.offersLoadErrorTitle.tr(),
          message: LocaleKeys.commonConnectionMessage.tr(),
          actionLabel: LocaleKeys.commonTryAgain.tr(),
          actionIcon: Icons.refresh_rounded,
          onAction: onRefresh,
        )
      : EmptyStateView(
          icon: Icons.local_offer_outlined,
          title: LocaleKeys.offersEmptyTitle.tr(),
          message: LocaleKeys.offersEmptyMessage.tr(),
          actionLabel: LocaleKeys.offersRefresh.tr(),
          actionIcon: Icons.refresh_rounded,
          onAction: onRefresh,
        );
}
