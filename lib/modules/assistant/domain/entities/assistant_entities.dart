import 'package:equatable/equatable.dart';

import 'package:strongbody_buyer/modules/post_request/domain/entities/request_draft_entity.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_feed_entities.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_listing_entities.dart';

/// Nhóm kết quả BE trả (`kinds`, key của `cards` / `totals`).
enum AssistantKind {
  services('services'),
  sellers('sellers'),
  publicOffers('public_offers');

  const AssistantKind(this.apiValue);
  final String apiValue;

  static AssistantKind? fromApi(String? value) {
    for (final kind in values) {
      if (kind.apiValue == value) return kind;
    }
    return null;
  }
}

/// Điều kiện khách đòi mà thẻ "gần đúng" không đáp ứng (web `MISSING_KEYS`).
enum AssistantMissing {
  languages,
  gender,
  delivery,
  price,
  verified,
  experienced,
  distance;

  static AssistantMissing? fromApi(String value) {
    for (final m in values) {
      if (m.name == value) return m;
    }
    return null;
  }
}

/// Một thẻ kết quả, đã quy về entity của card Social Market (web `assistantServiceToApi`,
/// `assistantSellerToExpert`, `assistantOfferToApi`). Đúng một trong ba field có giá trị.
class AssistantCard extends Equatable {
  final String ref;
  final MarketServiceEntity? service;
  final MarketExpertEntity? seller;
  final MarketOfferEntity? offer;
  final List<AssistantMissing> missing;

  /// Khoảng cách tới khách (web `PlaceLine`).
  final double? distanceKm;

  /// Địa chỉ — chỉ thẻ chuyên gia (thẻ dịch vụ đã ghi địa chỉ trong card).
  final String? address;

  const AssistantCard({
    required this.ref,
    this.service,
    this.seller,
    this.offer,
    this.missing = const [],
    this.distanceKm,
    this.address,
  });

  /// Khoảng cách: dưới 10 km lấy 1 số lẻ ("2.4", ít nhất 0.1), xa hơn làm tròn (web `formatKm`).
  static String formatKm(double km) {
    if (km >= 10) return '${km.round()}';
    final v = (km * 10).round() / 10;
    final out = v < 0.1 ? 0.1 : v;
    return out == out.roundToDouble() ? '${out.toInt()}' : '$out';
  }

  /// Dòng vị trí của thẻ dịch vụ / chuyên gia: "Hoàn Kiếm · 2.4 km away".
  bool get hasPlaceLine =>
      offer == null && (address != null || distanceKm != null);

  @override
  List<Object?> get props => [
    ref,
    service,
    seller,
    offer,
    missing,
    distanceKm,
    address,
  ];
}

/// Khu vực đã tìm quanh: `gps` = vị trí của khách, còn lại = nơi khách nêu.
class AssistantNear extends Equatable {
  final String label;
  final bool fromGps;

  /// Chỉ xếp người gần lên trước (khách chỉ cần online), không lọc → không hiện dòng khu vực.
  final bool soft;

  const AssistantNear({
    required this.label,
    required this.fromGps,
    this.soft = false,
  });

  /// Tên khu vực để hiện (web `NearLine`): GPS tra ngược ra địa chỉ dài → quận + thành phố
  /// (bỏ phố / phường đầu và tên nước cuối); nơi khách tự nói → 2 phần đầu. BE để "GPS" khi
  /// chưa tra được tên → rỗng.
  String get displayLabel {
    final parts = label
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final picked = fromGps && parts.length >= 3
        ? parts.sublist(parts.length - 3, parts.length - 1)
        : parts.take(2).toList();
    final out = picked.join(', ');
    return out.toUpperCase() == 'GPS' ? '' : out;
  }

  @override
  List<Object?> get props => [label, fromGps, soft];
}

/// Kết quả một lượt (BE `PublicResult`). `raw` giữ nguyên JSON để lưu hội thoại và gửi lại
/// `understanding` ở lượt sau.
class AssistantResult extends Equatable {
  /// search | request | account | info | results | refine | out_of_scope | smalltalk | error…
  final String branch;
  final String? answer;
  final Map<String, dynamic>? understanding;
  final List<AssistantKind> kinds;
  final Map<AssistantKind, List<AssistantCard>> cards;
  final Map<AssistantKind, List<AssistantCard>> closeMatches;
  final Map<AssistantKind, int> totals;

  /// Nhánh request: form Post Request điền sẵn.
  final RequestDraftEntity? requestDraft;
  final bool needsLocation;
  final AssistantNear? near;

  /// Không ai trong khu vực nên đã nới vị trí (kết quả ở xa hơn / online) — chỉ tính nhóm
  /// đang hiện thẻ.
  final bool nearRelaxed;

  /// Điều kiện khách nói mà BE phải bỏ để có kết quả (web `RelaxedLine`), chỉ tính nhóm
  /// đang hiện thẻ; vị trí có [nearRelaxed] riêng.
  final List<AssistantMissing> relaxed;
  final List<String> suggestions;
  final String? reason;
  final Map<String, dynamic> raw;

  const AssistantResult({
    required this.branch,
    this.answer,
    this.understanding,
    this.kinds = const [],
    this.cards = const {},
    this.closeMatches = const {},
    this.totals = const {},
    this.requestDraft,
    this.needsLocation = false,
    this.near,
    this.nearRelaxed = false,
    this.relaxed = const [],
    this.suggestions = const [],
    this.reason,
    this.raw = const {},
  });

  bool get hasCards => cards.values.any((list) => list.isNotEmpty);
  bool get hasCloseMatches => closeMatches.values.any((l) => l.isNotEmpty);

  /// Câu tìm kiếm BE đã hiểu (dùng làm mô tả khi khách bấm "Đăng yêu cầu").
  String? get query => understanding?['query'] as String?;

  @override
  List<Object?> get props => [raw];
}

/// Event SSE của `POST /search/assistant/chat`.
sealed class AssistantEvent {
  const AssistantEvent();
}

final class AssistantRouteEvent extends AssistantEvent {
  final String branch;
  const AssistantRouteEvent(this.branch);
}

final class AssistantResultEvent extends AssistantEvent {
  final AssistantResult result;
  const AssistantResultEvent(this.result);
}

final class AssistantDeltaEvent extends AssistantEvent {
  final String text;
  const AssistantDeltaEvent(this.text);
}

final class AssistantDoneEvent extends AssistantEvent {
  final String? branch;

  /// Nội dung BE dựng để gửi lại ở các lượt sau (kết quả tóm thành danh sách).
  final String? historyText;
  const AssistantDoneEvent({this.branch, this.historyText});
}

final class AssistantErrorEvent extends AssistantEvent {
  const AssistantErrorEvent();
}

enum AssistantTurnError { failed, rateLimited }

/// Một lượt trong hội thoại.
sealed class AssistantTurn extends Equatable {
  const AssistantTurn();
}

final class AssistantUserTurn extends AssistantTurn {
  final String content;
  const AssistantUserTurn(this.content);

  @override
  List<Object?> get props => [content];
}

final class AssistantReplyTurn extends AssistantTurn {
  final String? branch;

  /// Chữ trong bong bóng (câu trả lời / câu dẫn), stream dần.
  final String text;

  /// Gửi lại BE ở các lượt sau (BE dựng); thiếu thì dùng [text].
  final String? history;
  final AssistantResult? result;

  /// Câu khách đã nói cho lần tìm này (gửi kèm khi tìm tiếp).
  final String? saidText;
  final bool streaming;
  final AssistantTurnError? error;

  /// Khách bấm "Đăng yêu cầu" khi không có kết quả: form điền từ điều kiện đã hiểu.
  final RequestDraftEntity? requestDraft;

  /// Lượt vừa chạy trong phiên này: chữ chạy dần. Hội thoại nạp lại thì hiện ngay cả câu
  /// (web `live`, không lưu).
  final bool live;

  const AssistantReplyTurn({
    this.branch,
    this.text = '',
    this.history,
    this.result,
    this.saidText,
    this.streaming = false,
    this.error,
    this.requestDraft,
    this.live = false,
  });

  bool get isEmpty => text.isEmpty && result == null && error == null;

  AssistantReplyTurn copyWith({
    String? branch,
    String? text,
    String? history,
    AssistantResult? result,
    bool? streaming,
    AssistantTurnError? error,
    RequestDraftEntity? requestDraft,
  }) => AssistantReplyTurn(
    branch: branch ?? this.branch,
    text: text ?? this.text,
    history: history ?? this.history,
    result: result ?? this.result,
    saidText: saidText,
    streaming: streaming ?? this.streaming,
    error: error ?? this.error,
    requestDraft: requestDraft ?? this.requestDraft,
    live: live,
  );

  @override
  List<Object?> get props => [
    branch,
    text,
    history,
    result,
    saidText,
    streaming,
    error,
    requestDraft,
    live,
  ];
}
