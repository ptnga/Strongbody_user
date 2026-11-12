import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../domain/entities/my_request_entity.dart';
import '../../domain/entities/posted_request_entity.dart';
import '../../domain/entities/provider_entity.dart';
import '../../domain/entities/request_draft_entity.dart';
import '../../domain/entities/request_form_values.dart';
import '../../domain/entities/request_options.dart';
import '../models/response/my_request_dto.dart';
import '../models/response/provider_dto.dart';
import '../models/response/request_draft_response_dto.dart';

class PostRequestMapper {
  const PostRequestMapper._();

  /// Kết quả AI → giá trị form. `fallbackText` = câu người dùng nói/nhập (AI trả rỗng thì giữ).
  static RequestDraftEntity draft(
    RequestDraftResponseDto dto, {
    required String fallbackText,
  }) {
    final d = dto.draft;
    final description = (d?.description?.trim().isNotEmpty ?? false)
        ? d!.description!.trim()
        : fallbackText.trim();
    final currency = d?.currency?.toUpperCase();

    final values = RequestFormValues(
      description: description.length > RequestFormValues.maxDescription
          ? description.substring(0, RequestFormValues.maxDescription)
          : description,
      budget: d?.budget ?? '',
      currency: requestCurrencies.contains(currency) ? currency! : 'USD',
      deliveryTypes:
          d?.deliveryTypes
              .map(RequestDeliveryType.fromApi)
              .whereType<RequestDeliveryType>()
              .toList() ??
          const [],
      deadline: _parseLocal(d?.deadline),
      schedule: _schedule(d?.schedule ?? const {}),
      sellerLanguages:
          d?.sellerLanguages
              .where((c) => requestLanguageByCode(c) != null)
              .toList() ??
          const [],
    );

    return RequestDraftEntity(
      isEmpty: dto.empty ?? false,
      values: values.withRangeFromSchedule(),
      assistant: RequestAssistantMeta(
        categoryIds: d?.categoryIds ?? const [],
        qualityScore: dto.rank,
        suggestion: dto.suggestion ?? '',
      ),
    );
  }

  static DateTime? _parseLocal(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static Map<WeekDay, List<TimeRange>> _schedule(
    Map<String, List<Map<String, String>>> raw,
  ) {
    final out = <WeekDay, List<TimeRange>>{};
    for (final day in WeekDay.values) {
      final ranges = (raw[day.key] ?? const [])
          .map((r) => TimeRange(from: r['from'] ?? '', to: r['to'] ?? ''))
          .where((r) => r.isValid)
          .toList();
      if (ranges.isNotEmpty) out[day] = ranges;
    }
    return out;
  }

  /// Giá trị form → multipart `POST /buyer/request` — giống `createBuyerNeedHelpRequest`
  /// của web, cộng file `voice` như Multime. `sellerUserId` != null → biến thể
  /// `POST /buyer/request/to-seller` (`seller_id`, `is_privated=true`, như web `sendRequestToSeller`).
  static Future<FormData> createRequestFormData({
    required int userId,
    required RequestFormValues values,
    RequestAssistantMeta? assistant,
    int? sellerUserId,
  }) async {
    final budget = values.parsedBudget;
    final hasBudget = budget.min != null || budget.max != null;
    final deliveryType = switch (values.deliveryTypes.length) {
      0 => null,
      1 => values.deliveryTypes.first.apiValue,
      _ => 'all',
    };

    final fields = <MapEntry<String, String>>[
      MapEntry('description', values.description.trim()),
      MapEntry('user_id', '$userId'),
      const MapEntry('notes', ''),
      const MapEntry('type', 'ldp'),
      if (sellerUserId != null) ...[
        MapEntry('seller_id', '$sellerUserId'),
        const MapEntry('is_privated', 'true'),
        const MapEntry('status', 'active'),
      ],
      if (budget.min != null) MapEntry('min_budget', _num(budget.min!)),
      if (budget.max != null) MapEntry('max_budget', _num(budget.max!)),
      // `budget` (field cũ) — ưu tiên max, rồi min.
      if (budget.max != null)
        MapEntry('budget', _num(budget.max!))
      else if (budget.min != null)
        MapEntry('budget', _num(budget.min!)),
      if (hasBudget) MapEntry('currency', values.currency),
      if (hasBudget && values.currencyId != null)
        MapEntry('currency_id', '${values.currencyId}'),
      if (deliveryType != null) MapEntry('delivery_type', deliveryType),
      if (!values.isScheduleEmpty)
        MapEntry('schedule', jsonEncode(_scheduleJson(values.schedule))),
      // Gửi riêng (web form `variant="send"`): không có Working language / Post
      // anonymously → không gửi hai field này.
      if (sellerUserId == null && values.sellerLanguages.isNotEmpty)
        MapEntry('seller_languages', jsonEncode(values.sellerLanguages)),
      if (values.deadline != null)
        MapEntry('deadline', values.deadline!.toUtc().toIso8601String()),
      if (sellerUserId == null) MapEntry('anonymous', '${values.anonymous}'),
      if (assistant != null && assistant.categoryIds.isNotEmpty) ...[
        MapEntry('category_ids', jsonEncode(assistant.categoryIds)),
        MapEntry('category_id', '${assistant.categoryIds.first}'),
      ],
      if (assistant?.qualityScore != null)
        MapEntry('quality_score', '${assistant!.qualityScore}'),
      if (assistant != null && assistant.suggestion.isNotEmpty)
        MapEntry('ai_suggestion', assistant.suggestion),
      if (values.similarToRequestId != null)
        MapEntry('similar_to_request_id', '${values.similarToRequestId}'),
    ];

    final formData = FormData()..fields.addAll(fields);
    for (final path in values.attachmentPaths) {
      formData.files.add(
        MapEntry('attachments', await MultipartFile.fromFile(path)),
      );
    }
    final voice = values.voicePath;
    if (voice != null) {
      // Một file duy nhất ở field `voice` (không `[]`), content-type theo đuôi file như Multime.
      formData.files.add(
        MapEntry(
          'voice',
          await MultipartFile.fromFile(
            voice,
            filename: voice.split('/').last,
            contentType: MediaType('audio', _audioSubtype(voice)),
          ),
        ),
      );
    }
    return formData;
  }

  static String _audioSubtype(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'mp3' => 'mpeg',
      'wav' => 'wav',
      'aac' => 'aac',
      'ogg' => 'ogg',
      _ => 'm4a',
    };
  }

  static Map<String, List<Map<String, String>>> _scheduleJson(
    Map<WeekDay, List<TimeRange>> schedule,
  ) => {
    for (final entry in schedule.entries)
      if (entry.value.any((r) => r.isValid))
        entry.key.key: entry.value
            .where((r) => r.isValid)
            .map((r) => r.toJson())
            .toList(),
  };

  static String _num(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  /// Request vừa tạo: id (sang trang "Providers for your request") + status
  /// (`active` = đã lên, còn lại = chờ duyệt) — web đọc `data.data` → `data` → gốc.
  static CreatedRequest createdRequest(dynamic body) {
    Object? pick(String key) {
      if (body is! Map) return null;
      final data = body['data'];
      if (data is Map) {
        final nested = data['data'];
        if (nested is Map && nested[key] != null) return nested[key];
        if (data[key] != null) return data[key];
      }
      return body[key];
    }

    final id = pick('id');
    return CreatedRequest(
      id: id is num ? id.toInt() : int.tryParse('${id ?? ''}'),
      status: pick('status')?.toString(),
    );
  }

  /// Bảng `currencies` → ô chọn tiền (web `toOptions`): đang bật, tiền ưu tiên lên
  /// đầu, rồi theo `ordering`, cuối cùng theo mã.
  static List<CurrencyOption> currencies(dynamic body) {
    final data = body is Map ? body['data'] : null;
    final list = data is Map ? data['list'] : null;
    if (list is! List) return const [];
    final rows = list
        .whereType<Map>()
        .where(
          (c) =>
              c['is_active'] != false && '${c['name'] ?? ''}'.trim().isNotEmpty,
        )
        .toList();
    int ordering(Map c) =>
        c['ordering'] is num ? (c['ordering'] as num).toInt() : 1 << 31;
    rows.sort((a, b) {
      final fa = a['is_featured'] == true;
      final fb = b['is_featured'] == true;
      if (fa != fb) return fa ? -1 : 1;
      final byOrder = ordering(a).compareTo(ordering(b));
      if (byOrder != 0) return byOrder;
      return '${a['name']}'.compareTo('${b['name']}');
    });
    return [
      for (final c in rows)
        if (c['id'] is num)
          CurrencyOption(
            id: (c['id'] as num).toInt(),
            code: '${c['name']}'.trim().toUpperCase(),
          ),
    ];
  }

  /// `GET /user/request/{id}` → [SentRequest] (web `toSentRequest`).
  static SentRequest? sentRequest(dynamic body) {
    final data = body is Map ? body['data'] : null;
    if (data is! Map) return null;
    final r = Map<String, dynamic>.from(data);
    final id = r['id'] is num ? (r['id'] as num).toInt() : null;
    final description = '${r['description'] ?? ''}'.trim();
    if (id == null || description.isEmpty) return null;

    num? number(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');
    final min = number(r['min_budget']);
    final max = number(r['max_budget']) ?? number(r['budget']);
    final budget = min != null && max != null && min != max
        ? '${_num(min.toDouble())}-${_num(max.toDouble())}'
        : max != null
        ? _num(max.toDouble())
        : min != null
        ? _num(min.toDouble())
        : '';

    Object? json(Object? v) {
      if (v is! String) return v;
      try {
        return jsonDecode(v);
      } catch (_) {
        return null;
      }
    }

    final delivery = '${r['delivery_type'] ?? ''}';
    final languages = json(r['seller_languages']);
    final categories = json(r['category_ids']);
    final categoryIds = categories is List
        ? categories.map((c) => int.tryParse('$c')).whereType<int>().toList()
        : [?number(r['category_id'])?.toInt()];
    return SentRequest(
      id: id,
      description: description,
      budget: budget,
      currency: '${r['currency'] ?? ''}'.trim().isEmpty
          ? 'USD'
          : '${r['currency']}'.trim(),
      // 'all' = mọi hình thức → không lọc theo nơi nhận dịch vụ.
      deliveryTypes: delivery == 'all'
          ? const []
          : [?RequestDeliveryType.fromApi(delivery)],
      sellerLanguages: languages is List
          ? languages.map(_languageCode).whereType<String>().toSet().toList()
          : const [],
      categoryIds: categoryIds.where((c) => c > 0).toList(),
      status: r['status']?.toString(),
    );
  }

  /// Ngôn ngữ cũ có thể lưu tên ("English") thay vì mã → đổi về mã (web `toLanguageCodes`).
  static String? _languageCode(Object? value) {
    final v = '${value ?? ''}'.trim();
    if (v.isEmpty) return null;
    final key = v.toLowerCase();
    for (final l in requestLanguages) {
      if (l.code.toLowerCase() == key || l.name.toLowerCase() == key) {
        return l.code;
      }
    }
    return v;
  }

  /// `expert/balanced` (`list`) hoặc `/public/profiles` (`data`) → trang provider.
  static ProviderPage providers(Map<String, dynamic> data) {
    final rawList = data['list'] ?? data['data'];
    final raw = rawList is List ? rawList : const [];
    final items = <ProviderEntity>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final dto = ProviderDto.fromJson(Map<String, dynamic>.from(item));
      if (dto.id == null || dto.userId == null) continue;
      items.add(
        ProviderEntity(
          id: dto.id!,
          userId: dto.userId!,
          slug: dto.slug ?? '',
          // Web: tên shop / organization; rỗng → UI hiện "StrongBody Provider".
          name: dto.shopName ?? '',
          avatarUrl: _validImage(dto.profilePicture),
          profession: dto.profession,
          country: (dto.country?.isNotEmpty ?? false) ? dto.country : null,
          verified: dto.sellerVerified ?? false,
          yearsOfExperience: dto.yearsOfExperience ?? 0,
          rating: dto.rating ?? 0,
          reviewCount: dto.reviewCount ?? 0,
          skills: dto.skills,
          languages: dto.languages,
        ),
      );
    }
    return ProviderPage(
      items: items,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      totalPage: (data['total_page'] as num?)?.toInt() ?? 1,
    );
  }

  /// Bỏ URL ảnh rỗng / chỉ là thư mục (BE hay trả `…/public` không có file).
  static String? _validImage(String? url) {
    if (url == null || !url.startsWith('http')) return null;
    final last = Uri.tryParse(url)?.pathSegments.lastOrNull ?? '';
    return last.isEmpty || last == 'public' ? null : url;
  }

  /// Service + profile chi tiết của seller → giá "from", cách cung cấp, lịch rảnh.
  static ProviderExtras providerExtras({
    required List<Map<String, dynamic>> services,
    required Map<String, dynamic> profile,
  }) {
    double? minPrice;
    String? currency;
    var perSession = false;
    final delivery = <RequestDeliveryType>{};
    for (final raw in services) {
      final service = ProviderServiceDto.fromJson(raw);
      final prices = [
        if (service.price != null && service.price! > 0) service.price!,
        for (final option in service.deliveryOptions)
          if (option.price != null && option.price! > 0) option.price!,
      ];
      for (final price in prices) {
        if (minPrice == null || price < minPrice) {
          minPrice = price;
          currency = (service.currency?.isNotEmpty ?? false)
              ? service.currency
              : null;
          perSession =
              (service.sessionMode?.isNotEmpty ?? false) ||
              (service.durationMinutes ?? 0) > 0 ||
              (service.sessionCount ?? 0) > 0;
        }
      }
      for (final option in service.deliveryOptions) {
        final type = switch (option.type) {
          'remote' || 'online' => RequestDeliveryType.remote,
          'at_home' => RequestDeliveryType.atHome,
          'at_office' || 'at_clinic' => RequestDeliveryType.atClinic,
          _ => null,
        };
        if (type != null) delivery.add(type);
      }
    }

    final slots = <WeeklySlot>[];
    final availabilities = profile['availabilities'];
    if (availabilities is List) {
      for (final a in availabilities.whereType<Map>()) {
        if (a['is_active'] == false) continue;
        final weekday = (a['weekday'] as num?)?.toInt(); // 0 = CN … 6 = T7
        final start = a['start_time']?.toString() ?? '';
        if (weekday == null || start.isEmpty) continue;
        slots.add(
          WeeklySlot(
            weekday: weekday == 0 ? DateTime.sunday : weekday,
            startTime: start,
            endTime: a['end_time']?.toString() ?? '',
          ),
        );
      }
    }

    return ProviderExtras(
      minPrice: minPrice,
      currency: currency,
      perSession: perSession,
      deliveryTypes: delivery,
      slots: slots,
    );
  }

  static MyRequestPage myRequests(Map<String, dynamic> data) {
    final raw = data['list'] is List ? data['list'] as List : const [];
    final items = <MyRequestEntity>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final dto = MyRequestDto.fromJson(Map<String, dynamic>.from(item));
      if (dto.id == null) continue;
      items.add(
        MyRequestEntity(
          id: dto.id!,
          status: dto.status ?? 'pending',
          offersCount: dto.offersCount ?? 0,
          respondersCount: dto.respondersCount ?? 0,
          createdAt: DateTime.tryParse(dto.createdAt ?? '')?.toLocal(),
          updatedAt: DateTime.tryParse(dto.updatedAt ?? '')?.toLocal(),
          hasVoice: dto.voiceUrl?.isNotEmpty ?? false,
          details: _requestDetails(dto),
          isPrivate: dto.isPrivate ?? dto.inquiry != null,
          inquiry: _inquiry(dto.inquiry),
        ),
      );
    }
    return MyRequestPage(
      items: items,
      totalPage: (data['total_page'] as num?)?.toInt() ?? 1,
    );
  }

  static RequestInquiryInfo? _inquiry(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final avatar = _nonEmpty(raw['recipient_avatar']?.toString());
    return RequestInquiryInfo(
      recipientId: _int(raw['recipient_id']),
      recipientName: '${raw['recipient_name'] ?? ''}'.trim(),
      recipientAvatar: avatar,
      targetType: '${raw['target_type'] ?? ''}',
      title: '${raw['title'] ?? ''}'.trim(),
    );
  }

  /// Field request của BE → giá trị form — cùng quy tắc web `requestToFormValues`.
  static RequestFormValues _requestDetails(MyRequestDto dto) {
    final min = dto.minBudget;
    final max = dto.maxBudget ?? dto.budget;
    final budget = min != null && max != null && min != max
        ? '${_num(min.toDouble())}-${_num(max.toDouble())}'
        : max != null
        ? _num(max.toDouble())
        : min != null
        ? _num(min.toDouble())
        : '';
    final delivery = dto.deliveryType ?? '';
    final deliveryTypes = delivery == 'all'
        ? RequestDeliveryType.values.toList()
        : [?RequestDeliveryType.fromApi(delivery)];
    return RequestFormValues(
      description: dto.description?.trim() ?? '',
      budget: budget,
      currency: (dto.currency?.isNotEmpty ?? false) ? dto.currency! : 'USD',
      deliveryTypes: deliveryTypes,
      deadline: DateTime.tryParse(dto.deadline ?? '')?.toLocal(),
      schedule: _parseSchedule(dto.schedule),
    ).withRangeFromSchedule();
  }

  /// `{ mon: [{from, to}] }` (object hoặc chuỗi JSON); dữ liệu lạ bỏ qua như web `toSchedule`.
  static Map<WeekDay, List<TimeRange>> _parseSchedule(Object? raw) {
    var value = raw;
    if (value is String) {
      if (value.isEmpty) return const {};
      try {
        value = jsonDecode(value);
      } on FormatException {
        return const {};
      }
    }
    if (value is! Map) return const {};
    final schedule = <WeekDay, List<TimeRange>>{};
    for (final day in WeekDay.values) {
      final ranges = value[day.key];
      if (ranges is! List) continue;
      final valid = [
        for (final r in ranges)
          if (r is Map)
            TimeRange(from: '${r['from'] ?? ''}', to: '${r['to'] ?? ''}'),
      ].where((r) => r.isValid).toList();
      if (valid.isNotEmpty) schedule[day] = valid;
    }
    return schedule;
  }

  /// `data.list` của `sent-offers-by-my-requests` → offer (bỏ item thiếu id).
  static List<RequestOfferEntity> requestOffers(Map<String, dynamic> data) {
    final raw = data['list'] is List ? data['list'] as List : const [];
    return [
      for (final item in raw)
        if (item is Map)
          if (RequestOfferDto.fromJson(Map<String, dynamic>.from(item))
              case final dto when dto.id != null)
            RequestOfferEntity(
              id: dto.id!,
              status: dto.status ?? 'pending',
              sellerName: dto.sellerDisplayName ?? '',
              sellerAvatar: dto.sellerAvatar,
              sellerId: dto.sellerId,
              requestId: dto.requestId ?? _int(dto.request?['id']),
              request: dto.request == null
                  ? null
                  : myRequests({
                      'list': [dto.request],
                    }).items.firstOrNull,
              sellerVerified: dto.sellerVerified ?? false,
              title: dto.title?.trim() ?? '',
              description: dto.description?.trim() ?? '',
              price: dto.price?.toDouble(),
              currency: dto.currency,
              rating: (dto.sellerRating ?? dto.serviceRating)?.toDouble(),
              reviewCount: dto.serviceReviewCount?.toInt(),
              profession: _nonEmpty(dto.serviceCategory),
              address: _nonEmpty(dto.serviceAddress),
              leadTimeDays: dto.leadTimeDays?.toInt(),
              voiceUrl: dto.voiceUrl,
              createdAt: DateTime.tryParse(dto.createdAt ?? '')?.toLocal(),
              paidAt: DateTime.tryParse(dto.paymentDate ?? '')?.toLocal(),
              paymentStatus: dto.paymentStatus ?? '',
              pointsUsed: dto.pointsUsed?.toInt() ?? 0,
              pointsValue: dto.pointsValue?.toDouble() ?? 0,
              voucherValue: dto.voucherValue?.toDouble() ?? 0,
              voucherCode: (dto.voucherCode?.isNotEmpty ?? false)
                  ? dto.voucherCode
                  : null,
            ),
    ];
  }

  static String? _nonEmpty(String? value) =>
      (value?.trim().isEmpty ?? true) ? null : value!.trim();

  static int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
}
