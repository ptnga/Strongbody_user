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
import 'package:strongbody_buyer/modules/auth/presentation/widgets/auth_sheet.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_page_args.dart';

import '../../data/mappers/market_mapper.dart';
import '../../domain/entities/medical_travel_entities.dart';
import '../bloc/category_market/category_market_bloc.dart' show SectionStatus;
import '../bloc/medical_travel/service_detail_cubit.dart';
import '../widgets/appointment_sheet.dart';
import '../widgets/market_hero.dart';
import '../widgets/market_image_viewer.dart';
import '../widgets/market_rich_text.dart';
import '../widgets/market_ui.dart';
import '../widgets/medical_travel_widgets.dart';

/// Chi tiết service Medical Travel (web `/medical-travel/service/...` =
/// `CategoryServiceDetailPage`): tiêu đề · cơ sở · ảnh · thông tin nhanh · nội dung ·
/// FAQ; thanh dưới: Chat với cơ sở + Request appointment.
class MarketServiceDetailPage extends StatelessWidget {
  final int serviceId;

  const MarketServiceDetailPage({super.key, required this.serviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colour.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            MarketTopBar(title: LocaleKeys.marketServiceDetailTitle.tr()),
            const Divider(height: 1, color: Colour.lineSubtle),
            Expanded(
              child: BlocBuilder<ServiceDetailCubit, ServiceDetailState>(
                builder: (context, state) {
                  final detail = state.detail;
                  if (detail == null) {
                    if (state.status == SectionStatus.failure) {
                      return Center(
                        child: MarketSectionError(
                          title: '',
                          onRetry: () => context
                              .read<ServiceDetailCubit>()
                              .load(serviceId),
                        ),
                      );
                    }
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Column(
                    children: [
                      Expanded(child: _DetailBody(detail: detail)),
                      _BookingBar(detail: detail),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mở chat với seller của service; khách thì mở popup đăng nhập trước.
Future<void> _openChat(
  BuildContext context,
  MarketServiceDetail d, {
  String? name,
}) async {
  if (!getIt<GlobalStorage>().isLoggedIn) {
    final ok = await showAuthSheet(context, source: 'medical_travel_chat');
    if (!ok || !context.mounted) return;
  }
  context.push(
    RouteName.chat,
    extra: ChatPageArgs(
      partnerId: d.userId,
      name: name ?? d.organizationName ?? d.providerName,
      avatar: d.providerAvatar,
      source: 'medical_travel_service',
    ),
  );
}

String _duration(MarketServiceDetail d) {
  final n = d.duration;
  if (n == null) return '';
  return switch (d.durationUnit) {
    'minute' => LocaleKeys.marketSvcDurationMinute.plural(n),
    'hour' => LocaleKeys.marketSvcDurationHour.plural(n),
    _ => LocaleKeys.marketSvcDurationDay.plural(n),
  };
}

class _DetailBody extends StatelessWidget {
  final MarketServiceDetail detail;

  const _DetailBody({required this.detail});

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final secondary = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );
    Widget block(Widget child, {bool border = true}) => Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      decoration: border
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colour.lineSubtle)),
            )
          : null,
      child: child,
    );
    final panelTitle = AppTextStyle.lightBodyXLargeSemiBold.copyWith(
      color: Colour.textPrimary,
    );
    final duration = _duration(d);
    final languages = d.languages.map((l) => l.label).join(', ');

    return ListView(
      padding: EdgeInsets.only(bottom: 24.h),
      children: [
        // Tiêu đề + cơ sở · nước · rating + badge chứng nhận (web `Gallery` showImages=false).
        block(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.title,
                style: AppTextStyle.lightHeadingMedium.copyWith(
                  color: Colour.textPrimary,
                  height: 1.25,
                ),
              ),
              Gap(12.h),
              Wrap(
                spacing: 16.w,
                runSpacing: 8.h,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (d.organizationName != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_hospital_outlined,
                          size: 18.r,
                          color: Colour.primary,
                        ),
                        Gap(4.w),
                        Text(
                          d.organizationName!,
                          style: AppTextStyle.lightBodyMediumMedium.copyWith(
                            color: Colour.primary,
                          ),
                        ),
                      ],
                    ),
                  if (d.locationTitle != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18.r,
                          color: Colour.textSecondary,
                        ),
                        Gap(4.w),
                        Text(d.locationTitle!, style: secondary),
                        Gap(4.w),
                        CountryFlag(d.locationFlag),
                      ],
                    ),
                  if (d.rating > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 18.r,
                          color: Colour.amber,
                        ),
                        Gap(2.w),
                        Text(
                          d.rating.toStringAsFixed(1),
                          style: AppTextStyle.lightBodyMediumMedium.copyWith(
                            color: Colour.amber,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (d.certs.isNotEmpty) ...[
                Gap(16.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    for (final c in d.certs)
                      MarketBadge(
                        // Badge nói rõ "on request"; nhãn lọc ngắn thì không.
                        c == MarketCert.visaLetterOnRequest
                            ? LocaleKeys.marketMtDetailVisaLetterOnRequest.tr()
                            : MedicalTravelTexts.cert(c),
                        tone: MarketBadgeTone.seller,
                        icon: Icons.verified,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (d.images.isNotEmpty) _Gallery(images: d.images),
        // Thông tin nhanh (web `BookingFacts`).
        block(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.isMedicalTravel)
                MarketBadge(
                  LocaleKeys.marketMedicalTravelBadge.tr(),
                  tone: MarketBadgeTone.info,
                  icon: Icons.flight,
                )
              else ...[
                Text(
                  LocaleKeys.marketMtDetailEstimatedCost.tr().toUpperCase(),
                  style: AppTextStyle.lightBodySmallMedium.copyWith(
                    color: Colour.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                Gap(4.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(LocaleKeys.marketMtPriceFrom.tr(), style: secondary),
                    Gap(8.w),
                    Text(
                      MarketMapper.formatMoney(d.price),
                      style: AppTextStyle.lightHeadingMedium.copyWith(
                        color: Colour.textPrimary,
                      ),
                    ),
                  ],
                ),
                Gap(8.h),
                Text(LocaleKeys.marketMtDetailPriceNote.tr(), style: secondary),
              ],
              Gap(16.h),
              if (duration.isNotEmpty)
                _FactRow(
                  icon: Icons.schedule,
                  text: LocaleKeys.marketMtDetailDuration.tr(
                    namedArgs: {'duration': duration},
                  ),
                ),
              if (languages.isNotEmpty)
                _FactRow(
                  icon: Icons.translate,
                  text: LocaleKeys.marketMtDetailLanguages.tr(
                    namedArgs: {'languages': languages},
                  ),
                ),
              _FactRow(
                icon: Icons.lock_outline,
                text: LocaleKeys.marketMtDetailNoPayment.tr(),
              ),
            ],
          ),
        ),
        // Nội dung (web `DetailContent`).
        block(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.description != null) ...[
                Text(LocaleKeys.marketMtDetailOverview.tr(), style: panelTitle),
                Gap(12.h),
                MarketRichText(d.description!),
                Gap(32.h),
              ],
              if (d.included.isNotEmpty || d.notIncluded.isNotEmpty) ...[
                Text(
                  LocaleKeys.marketMtDetailWhatsIncluded.tr(),
                  style: panelTitle,
                ),
                Gap(20.h),
                if (d.included.isNotEmpty)
                  _ItemList(
                    title: LocaleKeys.marketMtHowIncludedTitle.tr(),
                    icon: Icons.check_circle_outline,
                    color: Colour.seller,
                    items: d.included,
                  ),
                if (d.included.isNotEmpty && d.notIncluded.isNotEmpty)
                  Gap(24.h),
                if (d.notIncluded.isNotEmpty)
                  _ItemList(
                    title: LocaleKeys.marketMtHowNotIncludedTitle.tr(),
                    icon: Icons.cancel_outlined,
                    color: Colour.primary,
                    items: d.notIncluded,
                  ),
                Gap(32.h),
              ],
              if (d.roadmapSteps != null) ...[
                Text(
                  d.roadmapTitle ?? LocaleKeys.marketMtDetailWhatToExpect.tr(),
                  style: panelTitle,
                ),
                Gap(12.h),
                MarketRichText(d.roadmapSteps!),
                Gap(32.h),
              ],
              _CrossSell(detail: d),
            ],
          ),
          border: d.faqs.isNotEmpty,
        ),
        if (d.faqs.isNotEmpty) block(_ServiceFaq(faqs: d.faqs), border: false),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 10.h),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18.r, color: Colour.textSecondary),
        Gap(10.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyle.lightBodyLargeRegular.copyWith(
              color: Colour.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Included / Not included: admin lưu 1 phần tử HTML; seller nhập thì mỗi dòng 1 phần tử.
class _ItemList extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _ItemList({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final html =
        items.length == 1 &&
        RegExp(
          r'<\/?[a-z][\s\S]*>',
          caseSensitive: false,
        ).hasMatch(items.first);
    return Column(
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
        MarketRichText(
          html ? items.first : items.map((i) => '•$i').join('\n'),
          color: Colour.textPrimary,
          dotColor: color,
        ),
      ],
    );
  }
}

/// "Not sure this is the right package?" — chat với seller (web `SellerCrossSell`).
class _CrossSell extends StatelessWidget {
  final MarketServiceDetail detail;

  const _CrossSell({required this.detail});

  @override
  Widget build(BuildContext context) {
    final name =
        detail.providerName ?? LocaleKeys.marketSvcProviderFallbackName.tr();
    return MarketCard(
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(
            name: name,
            imageUrl: detail.providerAvatar,
            colorSeed: name.hashCode,
            size: 64.r,
          ),
          Gap(16.h),
          Text(
            LocaleKeys.marketMtDetailCrossSellTitle.tr(),
            style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
              color: Colour.textPrimary,
            ),
          ),
          Gap(4.h),
          Text(
            LocaleKeys.marketMtDetailCrossSellDesc.tr(
              namedArgs: {'name': name},
            ),
            style: AppTextStyle.lightBodyMediumRegular.copyWith(
              color: Colour.textSecondary,
            ),
          ),
          if (detail.userId > 0) ...[
            Gap(16.h),
            MarketButton(
              label: LocaleKeys.marketMtDetailCrossSellChat.tr(
                namedArgs: {'name': name},
              ),
              variant: MarketButtonVariant.outline,
              onPressed: () => _openChat(context, detail, name: name),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceFaq extends StatefulWidget {
  final List<MarketFaq> faqs;

  const _ServiceFaq({required this.faqs});

  @override
  State<_ServiceFaq> createState() => _ServiceFaqState();
}

class _ServiceFaqState extends State<_ServiceFaq> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.marketSvcFaqTitle.tr(),
          style: AppTextStyle.lightBodyXLargeSemiBold.copyWith(
            color: Colour.textPrimary,
          ),
        ),
        Gap(16.h),
        MarketFaqList(
          items: [
            for (final f in widget.faqs) (f.question, f.answers.join('\n\n')),
          ],
          openIndex: _open,
          onToggle: (i) => setState(() => _open = _open == i ? null : i),
        ),
      ],
    );
  }
}

/// Nhiều ảnh → ảnh chính + tối đa 3 ảnh phụ ("+N"); 1 ảnh → tràn ngang. Chạm để xem
/// toàn màn hình (web `GalleryImages` / `ServiceGallery`).
class _Gallery extends StatelessWidget {
  final List<String> images;

  const _Gallery({required this.images});

  @override
  Widget build(BuildContext context) {
    void open(int i) =>
        showMarketImageViewer(context, images: images, initialIndex: i);
    Widget image(int i, {BorderRadius? radius}) => GestureDetector(
      onTap: () => open(i),
      child: ClipRRect(
        borderRadius: radius ?? BorderRadius.circular(12.r),
        child: Image.network(
          images[i],
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(color: Colour.subtle),
        ),
      ),
    );
    if (images.length == 1) {
      return AspectRatio(
        aspectRatio: 16 / 10,
        child: image(0, radius: BorderRadius.zero),
      );
    }
    final thumbs = images.length - 1 > 3 ? 3 : images.length - 1;
    final more = images.length - 1 - thumbs;
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colour.lineSubtle)),
      ),
      child: Column(
        children: [
          AspectRatio(aspectRatio: 16 / 10, child: image(0)),
          Gap(8.h),
          SizedBox(
            height: 72.h,
            child: Row(
              children: [
                for (var i = 1; i <= thumbs; i++) ...[
                  if (i > 1) Gap(8.w),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        image(i),
                        if (i == thumbs && more > 0)
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                LocaleKeys.marketMtDetailMorePhotos.tr(
                                  namedArgs: {'count': '$more'},
                                ),
                                style: AppTextStyle.lightBodyMediumSemiBold
                                    .copyWith(color: Colors.white),
                              ),
                            ),
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
    );
  }
}

/// Thanh dính đáy: giá (service thường) · Chat · Request appointment (web `BookingBar`).
class _BookingBar extends StatelessWidget {
  final MarketServiceDetail detail;

  const _BookingBar({required this.detail});

  @override
  Widget build(BuildContext context) {
    final d = detail;
    return Container(
      padding: EdgeInsets.fromLTRB(
        14.w,
        10.h,
        14.w,
        10.h + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colour.surface,
        border: Border(top: BorderSide(color: Colour.lineSubtle)),
      ),
      child: Row(
        children: [
          // Medical Travel không có giá → 2 nút chia đều bề ngang.
          if (!d.isMedicalTravel) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${LocaleKeys.marketMtPriceFrom.tr()} ',
                          style: AppTextStyle.lightBodyMediumMedium.copyWith(
                            color: Colour.textSecondary,
                          ),
                        ),
                        TextSpan(text: MarketMapper.formatMoney(d.price)),
                      ],
                    ),
                    style: AppTextStyle.lightBodyXLargeSemiBold.copyWith(
                      color: Colour.textPrimary,
                    ),
                  ),
                  Text(
                    LocaleKeys.marketMtDetailEstimatedCost.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.lightBodyMediumRegular.copyWith(
                      color: Colour.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Gap(8.w),
          ],
          Expanded(
            child: MarketButton(
              label: LocaleKeys.marketMtDetailChatFacility.tr(),
              variant: MarketButtonVariant.outline,
              large: true,
              dense: true,
              onPressed: d.userId > 0 ? () => _openChat(context, d) : null,
            ),
          ),
          Gap(8.w),
          Expanded(
            child: MarketButton(
              label: LocaleKeys.marketMtDetailRequestAppointment.tr(),
              large: true,
              dense: true,
              onPressed: () => showAppointmentSheet(
                context,
                AppointmentSeed(
                  serviceId: d.id,
                  title: d.title,
                  organization: d.organizationName,
                  location: d.locationTitle,
                  detail: d,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
