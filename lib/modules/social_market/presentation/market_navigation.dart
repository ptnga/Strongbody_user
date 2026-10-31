import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/post_request_flow_args.dart';

import '../data/mappers/market_mapper.dart';
import '../domain/entities/market_category.dart';
import '../domain/entities/market_feed_entities.dart';
import '../domain/entities/market_inquiry.dart';
import '../domain/entities/market_listing_entities.dart';
import '../domain/usecases/social_market_use_cases.dart';
import 'widgets/appointment_sheet.dart';
import 'widgets/market_inquiry_sheet.dart';

/// Đường dẫn trong module (con của `/socialMarket/:category`).
class MarketRoutes {
  MarketRoutes._();

  static String category(MarketCategory c) =>
      '${RouteName.socialMarket}/${c.route}';
  static String services(MarketCategory c) => '${category(c)}/services';
  static String providers(MarketCategory c) => '${category(c)}/providers';

  /// Medical Travel: landing riêng (web `/medical-travel`).
  static const String medicalTravel =
      '${RouteName.socialMarket}/medical-travel';
  static String medicalService(int id) => '$medicalTravel/service/$id';
  static String destination(String code) =>
      '$medicalTravel/destination/${code.toLowerCase()}';
}

/// Hành động của card Social Market.
class MarketNavigation {
  MarketNavigation._();

  /// Màn chưa có trên app (chi tiết, đặt lịch Medical Travel…).
  static void comingSoon() => ToastUtil.showInfo(LocaleKeys.navComingSoon.tr());

  /// "View & book" của service Medical Travel: mở thẳng form Request Appointment với
  /// dữ liệu của card, chi tiết tải nền (web `MedicalTravelBookButton`).
  static void viewAndBook(BuildContext context, MarketServiceEntity s) {
    final id = s.id;
    if (id == null) return;
    showAppointmentSheet(
      context,
      AppointmentSeed(
        serviceId: id,
        title: s.title,
        organization: s.seller.shopName,
        location: s.place,
      ),
    );
  }

  /// Chạm card service: Medical Travel có trang chi tiết riêng; service thường dùng
  /// trang chi tiết chung (chưa có trên app).
  static void openService(BuildContext context, MarketServiceEntity s) {
    final id = s.id;
    if (id == null) return;
    if (s.isMedicalTravel) {
      context.push(MarketRoutes.medicalService(id));
    } else {
      comingSoon();
    }
  }

  /// "Send Inquiry" của card service (web `ServiceCard` → `InquiryDialog kind="service"`).
  static void inquireService(BuildContext context, MarketServiceEntity s) {
    final sellerId = s.seller.id;
    final id = s.id;
    if (id == null || sellerId == null) return;
    final price = s.price;
    showMarketInquirySheet(
      context,
      InquiryTarget(
        kind: InquiryKind.service,
        id: id,
        recipientUserId: sellerId,
        title: s.title,
        image: s.previewImage,
        // Kèm đơn vị tiền ("$45") - lưu vào inquiry, hiện ở dashboard seller.
        price: price?.amount == null
            ? null
            : MarketMapper.formatMoney(price!.amount!, price.currency),
        recipientName: s.seller.shopName,
        recipientShop: s.seller.shopName,
        recipientAvatar: s.seller.avatar,
        cardData: {
          'id': id,
          'title': s.title,
          'description': s.rawDescription,
          'user_id': sellerId,
          'price': ?s.rawPrice,
          'original_price': s.originalPrice,
          'type': 'service',
          'image': s.imageList,
          'cover_image': s.coverList,
          'status': s.status,
          'slug': s.slug,
        },
      ),
    );
  }

  /// "I want this offer" (web `OfferCard` → `InquiryDialog kind="offer"`).
  static void inquireOffer(BuildContext context, MarketOfferEntity o) {
    final id = o.id;
    final sellerId = o.sellerUserId;
    if (id == null || sellerId == null) return;
    final name = o.sellerName ?? LocaleKeys.marketOfferFallbackName.tr();
    final detail = o.detail.length > 80 ? o.detail.substring(0, 80) : o.detail;
    final title = detail.trim().isEmpty ? 'Offer from $name' : detail.trim();
    final min = o.minPrice;
    final unit = o.pricingUnit == null ? '' : ' / ${o.pricingUnit}';
    showMarketInquirySheet(
      context,
      InquiryTarget(
        kind: InquiryKind.offer,
        id: id,
        recipientUserId: sellerId,
        title: title,
        price: min == null
            ? null
            : '${MarketMapper.formatMoney(min, o.currency)}$unit',
        recipientName: name,
        recipientAvatar: o.sellerAvatar,
        cardData: {
          'id': id,
          'title': title,
          'description': o.detail,
          'price': ?min,
          'type': 'offer',
          'seller_id': sellerId,
        },
      ),
    );
  }

  /// "I want a solution of this type": soạn request từ `request_template`; đăng xong
  /// thì báo provider phù hợp qua API matching (web `SolutionComposer`, vai seeker).
  static void wantSolution(BuildContext context, HealthSolutionEntity s) {
    final match = getIt<MatchHealthSolutionUseCase>();
    context.push(
      RouteName.requestHeard,
      extra: PostRequestFlowArgs(
        text: s.requestTemplate ?? s.title,
        onPosted: (description) async {
          final result = await match((solutionId: s.id, message: description));
          result.fold(
            (failure) => ToastUtil.showError(failure.message),
            (count) => ToastUtil.showSuccess(
              count > 0
                  ? LocaleKeys.marketSolutionSentToProviders.plural(count)
                  : LocaleKeys.marketSolutionSentNoMatch.tr(),
            ),
          );
        },
      ),
    );
  }
}

/// Tham số trang `page` của listing (10 bản ghi, web `LISTING_PAGE_SIZE`).
MarketPageParams listingParams(
  MarketCategory c,
  int page, {
  bool newestFirst = false,
}) => MarketPageParams(
  categorySlug: c.slug,
  page: page,
  limit: 10,
  newestFirst: newestFirst,
);
