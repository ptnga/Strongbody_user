import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/core/utils/plural_tr.dart';
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

  /// Listing "View all" của trang category (gồm Medical Travel — web
  /// `/services/{route}`, `/providers/{route}`); [language] = bộ lọc ngôn ngữ seller.
  static String scopeServices(MarketPageScope s, {String? language}) =>
      '${RouteName.socialMarket}/${s.route}/services'
      '${language == null ? '' : '?$listingLanguageParam=$language'}';
  static String scopeProviders(MarketPageScope s) =>
      '${RouteName.socialMarket}/${s.route}/providers';

  /// Query của listing service: ngôn ngữ làm việc của seller (web `?lang=`).
  static const String listingLanguageParam = 'lang';

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

  /// Chạm card lưới trang category / listing: Medical Travel mở trang chi tiết riêng;
  /// service thường — app chưa có trang chi tiết chung (web `/service/...`, nơi gửi
  /// inquiry) → mở thẳng form inquiry.
  static void openServiceCard(BuildContext context, MarketServiceEntity s) {
    if (s.isMedicalTravel) {
      openService(context, s);
    } else {
      inquireService(context, s);
    }
  }

  /// "Send Inquiry" của card service (web `ServiceCard` → `InquiryDialog kind="service"`).
  /// Service Tư vấn: inquiry mang khoảng giá ("$50 – $200"), card chat kèm
  /// `pricing_mode` + `price_max`.
  static void inquireService(
    BuildContext context,
    MarketServiceEntity s, {
    String? message,
  }) {
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
        // Kèm đơn vị tiền ("$45" / Tư vấn "$50 – $200") - lưu vào inquiry, hiện ở
        // dashboard seller.
        price: inquiryPrice(price),
        recipientName: s.seller.shopName,
        recipientShop: s.seller.shopName,
        recipientAvatar: s.seller.avatar,
        message: message,
        cardData: {
          'id': id,
          'title': s.title,
          'description': s.rawDescription,
          'user_id': sellerId,
          'price': ?s.rawPrice,
          'original_price': s.originalPrice,
          'pricing_mode': ?s.pricingMode,
          'price_max': ?s.priceMax,
          'currency': ?(price == null || price.currency.isEmpty
              ? null
              : price.currency),
          'type': 'service',
          'image': s.imageList,
          'cover_image': s.coverList,
          'status': s.status,
          'slug': s.slug,
        },
      ),
    );
  }

  /// Giá lưu vào inquiry (web `inquiryItem.price`): Tư vấn = khoảng giá, còn lại 1 giá.
  static String? inquiryPrice(MarketPrice? price) {
    if (price == null) return null;
    if (price.consultation) return price.text;
    final amount = price.amount;
    return amount == null
        ? null
        : MarketMapper.formatMoney(amount, price.currency);
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
      RouteName.postRequest,
      extra: PostRequestFlowArgs(
        text: s.requestTemplate ?? s.title,
        onPosted: (description) async {
          final result = await match((solutionId: s.id, message: description));
          result.fold(
            (failure) => ToastUtil.showError(failure.message),
            (count) => ToastUtil.showSuccess(
              count > 0
                  ? pluralTr(
                      count,
                      one: LocaleKeys.marketSolutionSentToProvidersOne,
                      other: LocaleKeys.marketSolutionSentToProvidersOther,
                    )
                  : LocaleKeys.marketSolutionSentNoMatch.tr(),
            ),
          );
        },
      ),
    );
  }
}

/// Tham số trang `page` của listing (10 bản ghi, web `LISTING_PAGE_SIZE`);
/// [language] = bộ lọc ngôn ngữ seller ("View all services in …").
MarketPageParams listingParams(
  MarketPageScope scope,
  int page, {
  bool newestFirst = false,
  String? language,
}) => MarketPageParams(
  scope: scope,
  categorySlug: scope.slug,
  page: page,
  limit: 10,
  newestFirst: newestFirst,
  language: language,
);
