import 'package:intl/intl.dart';

import '../../domain/entities/market_feed_entities.dart';
import '../../domain/entities/market_listing_entities.dart';
import '../../domain/entities/medical_travel_entities.dart';

/// JSON thô → entity hiển thị. Port từ web `_components/cards/{normalize,service-meta,
/// adapters}.ts`, `utils/sellerPlace.ts`, `slimOffer` — mỗi entity đến từ nhiều
/// endpoint với shape khác nhau nên card không đọc thẳng field thô.
class MarketMapper {
  MarketMapper._();

  // ---------------------------------------------------------------- helpers

  static Map<String, dynamic>? _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  static String? _text(Object? v) {
    if (v is! String) return v is num ? '$v' : null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

  static double? _num(Object? v) {
    if (v == null || v == '') return null;
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    return n != null && n.isFinite ? n : null;
  }

  static DateTime? _date(Object? v) {
    final raw = _text(v);
    if (raw == null) return null;
    // Chuỗi không có múi giờ là UTC (như web formatTimeAgo thêm 'Z').
    final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw);
    return DateTime.tryParse(hasZone ? raw : '${raw.replaceFirst(' ', 'T')}Z');
  }

  /// jsonb có thể đã là object/mảng, là chuỗi JSON, hoặc rỗng.
  static List<Object?> _list(Object? v) => v is List ? v : const [];

  static List<String> _strings(Object? v) =>
      _list(v).map(_text).nonNulls.toList();

  /// Giá trị chuỗi hoặc object quan hệ ({title}/{name}) → chuỗi (web `label`).
  static String? label(Object? value) {
    if (value is String || value is num) return _text(value);
    final m = _map(value);
    return m == null ? null : _text(m['title'] ?? m['name']);
  }

  /// Số tiền theo đúng đơn vị (web `formatMoney`): `$70`, `£70`, `€12.50`.
  static String formatMoney(num value, [String? currency]) {
    final code = (currency ?? '').trim().toUpperCase();
    try {
      return NumberFormat.simpleCurrency(
        locale: 'en_US',
        name: code.isEmpty ? 'USD' : code,
        decimalDigits: value % 1 == 0 ? 0 : 2,
      ).format(value);
    } catch (_) {
      return '${code.isEmpty ? 'USD' : code} $value';
    }
  }

  static final _entities = <String, String>{
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
  };

  /// Rich text API → chữ thuần (web `plainTextFromHtml`).
  static String plainText(String? html) {
    if (html == null || html.isEmpty) return '';
    return html
        .replaceAll(
          RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAllMapped(
          RegExp(r'&(#x?[0-9a-f]+|[a-z]+);', caseSensitive: false),
          (m) {
            final entity = m[1]!;
            if (entity.startsWith('#')) {
              final hex = entity.length > 1 && entity[1].toLowerCase() == 'x';
              final code = int.tryParse(
                entity.substring(hex ? 2 : 1),
                radix: hex ? 16 : 10,
              );
              return code != null && code >= 0 && code <= 0x10ffff
                  ? String.fromCharCode(code)
                  : m[0]!;
            }
            return _entities[entity.toLowerCase()] ?? m[0]!;
          },
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Ảnh cờ: flagcdn trả SVG — đổi sang PNG `w40` (cờ chỉ hiện ~16px, Image không vẽ SVG).
  static String? flagUrl(String? flag, [String? code]) {
    final f = _text(flag);
    if (f != null) {
      final svg = RegExp(r'flagcdn\.com/([a-z]{2})\.svg$').firstMatch(f);
      return svg == null ? f : 'https://flagcdn.com/w40/${svg[1]}.png';
    }
    final c = _text(code);
    return c != null && RegExp(r'^[a-zA-Z]{2}$').hasMatch(c)
        ? 'https://flagcdn.com/w40/${c.toLowerCase()}.png'
        : null;
  }

  // ------------------------------------------------------- seller identity

  /// Người đại diện organization → danh tính là của organization (web `representedOrganization`).
  static Map<String, dynamic>? _representedOrg(Map<String, dynamic>? seller) {
    final org = _map(seller?['organization']);
    if (seller?['is_org_owner'] != true || org == null) return null;
    if ((_int(org['id']) ?? 0) == 0 || _text(org['name']) == null) return null;
    return org;
  }

  static Map<String, dynamic>? _firstObject(Object? raw) {
    for (final item in _list(raw)) {
      final m = _map(item);
      if (m != null) return m;
    }
    return _map(raw);
  }

  /// Nước + cờ của seller, CHỈ từ hồ sơ seller (web `sellerPlace`).
  static ({String? country, String? flag}) _sellerPlace(
    Map<String, dynamic>? seller,
  ) {
    if (seller == null) return (country: null, flag: null);
    final org = _representedOrg(seller);
    final address = _firstObject(
      org != null ? org['address'] : seller['addresses'],
    );
    var country = _text(address?['country']);
    var flag = flagUrl(address?['flag'], address?['country_code']);
    final c = _map(org != null ? org['country'] : seller['country']);
    if (c != null) {
      final title = _text(c['title']) ?? _text(c['name']);
      final cFlag = flagUrl(c['flag'], c['code']);
      if (org != null) {
        country = title ?? country;
        flag = cFlag ?? flag;
      } else {
        country ??= title;
        flag ??= cFlag;
      }
    }
    return (country: country, flag: flag);
  }

  /// Owner của service (`user` thô, `seller_profile` lồng) → [MarketSeller] (web `resolveSeller`).
  static MarketSeller seller(Object? raw) {
    final u = _map(raw);
    final inner = _map(u?['user']);
    final profile =
        _map(u?['seller_profile']) ??
        _map(inner?['seller_profile']) ??
        (u != null && (u.containsKey('addresses') || u['is_org_owner'] == true)
            ? u
            : null);
    final org = _representedOrg(profile);
    final place = _sellerPlace(profile);
    final professions = _list(u?['professions']);
    return MarketSeller(
      id: _int(inner?['id']) ?? _int(u?['id']),
      shopName:
          _text(org?['name']) ??
          _text(u?['shop_name']) ??
          _text(_map(u?['seller_profile'])?['shop_name']) ??
          _text(inner?['shop_name']) ??
          _text(_map(inner?['seller_profile'])?['shop_name']),
      avatar:
          _text(org?['logo']) ??
          _text(inner?['profile_picture']) ??
          _text(u?['profile_picture']),
      country: place.country,
      flag: place.flag,
      profession:
          _text(u?['profession']) ??
          (professions.isEmpty ? null : label(professions.first)),
      slug:
          _text(_map(u?['seller_profile'])?['slug']) ??
          _text(_map(inner?['seller_profile'])?['slug']) ??
          _text(u?['slug']),
    );
  }

  // ---------------------------------------------------------------- service

  static const _deliveryOrder = [
    MarketDeliveryType.remote,
    MarketDeliveryType.atOffice,
    MarketDeliveryType.atHome,
  ];

  /// Hình thức đang bật, thứ tự cố định; service luồng cũ suy từ cột `type`.
  static List<MarketDelivery> _deliveries(Map<String, dynamic> s) {
    final byType = <MarketDeliveryType, MarketDelivery>{};
    for (final raw in _list(s['delivery_options'])) {
      final o = _map(raw);
      if (o == null || o['is_active'] == false) continue;
      final type = MarketDeliveryType.fromApi(_text(o['delivery_type']));
      if (type == null) continue;
      final radius = _num(o['radius_value']);
      final unit = o['distance_unit'] == 'miles' ? 'miles' : 'km';
      byType[type] = MarketDelivery(
        type: type,
        price: _num(o['price']),
        coverage: radius != null && radius != 0
            ? '${_trimNum(radius)} $unit'
            : '',
      );
    }
    final ordered = [
      for (final t in _deliveryOrder)
        if (byType[t] != null) byType[t]!,
    ];
    if (ordered.isNotEmpty) return ordered;
    final legacy = switch ('${s['type'] ?? ''}'.toLowerCase()) {
      'online' => [MarketDeliveryType.remote],
      'offline' => [MarketDeliveryType.atOffice],
      'hybrid' ||
      'mix' => [MarketDeliveryType.remote, MarketDeliveryType.atOffice],
      _ => const <MarketDeliveryType>[],
    };
    return [for (final t in legacy) MarketDelivery(type: t)];
  }

  static String _trimNum(num n) =>
      n % 1 == 0 ? n.toInt().toString() : n.toString();

  /// Giá thấp nhất trong các hình thức, "From" khi có nhiều mức (web `servicePrice`).
  static MarketPrice? _price(
    Map<String, dynamic> s,
    List<MarketDelivery> deliveries,
  ) {
    final currency = (_text(s['currency']) ?? '');
    final prices = deliveries.map((d) => d.price).nonNulls.toList();
    if (prices.isNotEmpty) {
      final min = prices.reduce((a, b) => a < b ? a : b);
      return MarketPrice(
        amount: min,
        text: formatMoney(min, currency),
        from: prices.toSet().length > 1,
        currency: currency,
      );
    }
    final raw = s['price'];
    if (raw == null || raw == '') return null;
    if (raw is num) {
      return MarketPrice(
        amount: raw.toDouble(),
        text: formatMoney(raw, currency),
        from: false,
        currency: currency,
      );
    }
    return MarketPrice(
      amount: _num(raw),
      text: '$raw',
      from: false,
      currency: currency,
    );
  }

  static List<String> _images(Object? a, Object? b) {
    final out = <String>[];
    for (final v in [a, b]) {
      if (v is List) {
        out.addAll(v.map(_text).nonNulls);
      } else if (_text(v) case final s?) {
        out.add(s);
      }
    }
    return out.toSet().toList();
  }

  static MarketServiceEntity service(Map<String, dynamic> s) {
    final deliveries = _deliveries(s);
    final price = _price(s, deliveries);
    final original = _num(s['original_price']);
    final strike =
        price?.amount != null &&
            original != null &&
            original > 0 &&
            original > price!.amount!
        ? formatMoney(original, price.currency)
        : null;
    final seller = MarketMapper.seller(s['user']);
    final coverage = deliveries
        .map((d) => d.coverage)
        .firstWhere((c) => c.isNotEmpty, orElse: () => '');
    return MarketServiceEntity(
      id: _int(s['id']),
      slug: _text(s['slug']) ?? '',
      title: _text(s['title']) ?? _text(s['name']) ?? '',
      description: plainText(_text(s['description'])),
      isMedicalTravel: s['is_medical_travel'] == true,
      images: _images(s['image'], s['cover_image']),
      deliveries: deliveries,
      price: price,
      strikePrice: strike,
      coverage: coverage.isEmpty ? null : coverage,
      languages: _text(s['languages']),
      place: _text(s['location']) ?? _text(s['address']) ?? seller.country,
      seller: seller,
      rawPrice: s['price'] is num ? s['price'] as num : null,
      originalPrice: s['original_price'] is num
          ? s['original_price'] as num
          : null,
      status: _text(s['status']),
      imageList: _images(s['image'], null),
      coverList: _images(s['cover_image'], null),
      rawDescription: _text(s['description']),
    );
  }

  // ----------------------------------------------------------------- expert

  /// Expert `/expert/balanced` → card `profile` (web `expertToCard`).
  static MarketExpertEntity expert(Map<String, dynamic> e) {
    final org = _representedOrg(e);
    final place = _sellerPlace(e);
    final categories = _list(
      e['category'] is List ? e['category'] : e['categories'],
    ).map(_map).nonNulls.toList();
    String norm(Object? v) =>
        '${v ?? ''}'.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');
    final medicalTravel =
        e['is_medical_travel'] == true ||
        categories.any(
          (c) =>
              norm(c['slug']).startsWith('medical-travel') ||
              norm(c['name']).startsWith('medical-travel'),
        );
    final primaryId = _int(e['primary_category_id']);
    final primary = primaryId == null
        ? null
        : categories.where((c) => _int(c['id']) == primaryId).firstOrNull;
    final categoryName = _text((primary ?? categories.firstOrNull)?['name']);
    final professions = _list(e['professions']);
    final summary = _map(e['review_summary']);
    final user = _map(e['user']);

    final orgLanguages = org == null
        ? const <String>[]
        : _strings(org['languages']);
    final languages = orgLanguages.isNotEmpty
        ? orgLanguages.map((c) => c.toUpperCase()).toSet().toList()
        : sellerLanguageLabels(e['supported_languages'], e['language_items']);

    return MarketExpertEntity(
      id: _int(e['id']),
      userId: _int(e['user_id']) ?? _int(user?['id']),
      name: _text(org?['name']) ?? _text(e['shop_name']) ?? '',
      slug: _text(e['slug']),
      avatar: _text(org?['logo']) ?? _text(user?['profile_picture']),
      subtitle:
          _text(e['profession']) ??
          (professions.isEmpty ? null : label(professions.first)) ??
          (medicalTravel ? null : categoryName),
      medicalTravel: medicalTravel,
      country: place.country,
      flag: place.flag,
      yearsOfExperience: _positiveInt(e['years_of_experience']),
      ratingValue: _num(summary?['rating']) ?? 0,
      ratingCount: _int(summary?['review_count']) ?? 0,
      booked: _positiveInt(e['served_customers']),
      verified: _list(e['certificates']).isNotEmpty,
      about: org != null
          ? (_orgDescription(org['description']) ?? _text(e['about']))
          : _text(e['about']),
      languages: languages,
    );
  }

  static int? _positiveInt(Object? v) {
    final n = _int(v);
    return n != null && n > 0 ? n : null;
  }

  static String? _orgDescription(Object? html) {
    final raw = _text(html);
    if (raw == null) return null;
    final text = raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|li|h[1-6])>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return text.isEmpty ? null : text;
  }

  /// Title ngôn ngữ (bảng languages), seller cũ chưa liên kết thì hiện mã.
  static List<String> sellerLanguageLabels(Object? codes, Object? items) {
    final out = <String>[];
    void push(String? v) {
      if (v != null && v.isNotEmpty && !out.contains(v)) out.add(v);
    }

    final list = _list(items).map(_map).nonNulls.toList();
    if (list.isNotEmpty) {
      for (final item in list) {
        push(_text(item['title']) ?? _text(item['code'])?.toUpperCase());
      }
      return out;
    }
    final raw = codes is String ? codes.split(',') : _list(codes);
    for (final c in raw) {
      push(_text(c)?.toUpperCase());
    }
    return out;
  }

  // ------------------------------------------------------------------ offer

  static List<MarketScheduleSlot> _schedule(Object? value) {
    final map = _map(value);
    if (map == null) return const [];
    final out = <MarketScheduleSlot>[];
    map.forEach((day, ranges) {
      if (ranges is! List) return;
      final times = ranges
          .map(_map)
          .nonNulls
          .where((r) => _text(r['from']) != null && _text(r['to']) != null)
          .map((r) => '${r['from']}–${r['to']}')
          .join(', ');
      if (times.isNotEmpty) out.add((day: day, times: times));
    });
    return out;
  }

  static List<({String key, String value})> _location(Object? value) {
    final map = _map(value);
    if (map == null) return const [];
    return [
      for (final e in map.entries)
        if (e.value != null && e.value != '') (key: e.key, value: '${e.value}'),
    ];
  }

  static List<MarketMedia> _media(Object? value) => _list(value)
      .map(_map)
      .nonNulls
      .where((m) => _text(m['url']) != null)
      .map(
        (m) => MarketMedia(
          url: _text(m['url'])!,
          name: _text(m['name']),
          isVideo: '${m['type'] ?? ''}'.startsWith('video'),
        ),
      )
      .toList();

  /// Public offer (web `slimOffer` + `OfferCard`).
  static MarketOfferEntity offer(Map<String, dynamic> o) {
    final s = _map(o['seller']);
    final profile = _map(s?['seller_profile']);
    final place = _sellerPlace(profile);
    final fullName = [
      _text(s?['first_name']),
      _text(s?['last_name']),
    ].nonNulls.join(' ');
    final prices = <({String mode, double amount})>[
      for (final (mode, key) in [
        ('remote', 'price_remote'),
        ('at_office', 'price_at_office'),
        ('at_home', 'price_at_home'),
      ])
        if (_num(o[key]) case final amount?) (mode: mode, amount: amount),
    ];
    return MarketOfferEntity(
      id: _int(o['id']),
      sellerUserId: _int(s?['id']) ?? _int(o['seller_id']),
      sellerName:
          _text(profile?['shop_name']) ?? (fullName.isEmpty ? null : fullName),
      sellerAvatar: _text(s?['profile_picture']),
      profession: _text(s?['profession']) ?? _text(profile?['profession']),
      country: place.country,
      flag: place.flag,
      createdAt: _date(o['created_at']),
      detail: _text(o['detail']) ?? '',
      currency: _text(o['currency']) ?? 'USD',
      pricingUnit: _text(o['pricing_unit']),
      prices: prices,
      deliveryTypes: _strings(o['delivery_types']),
      durationValue: o['duration_value'] is num
          ? o['duration_value'] as num
          : null,
      durationUnit: _text(o['duration_unit']),
      schedule: _schedule(o['schedule']),
      languages: _strings(o['languages']),
      serviceLocation: _location(o['service_location']),
      coverageArea: _location(o['coverage_area']),
      category: label(o['category']),
      acceptTravelingPatients: o['accept_traveling_patients'] == true,
      additionalRequirements: _text(o['additional_requirements']),
      expectedResult: _text(o['expected_result']),
      stories: _text(o['stories']),
      hashtags: _strings(o['hashtags']),
      media: _media(o['media']),
    );
  }

  // ---------------------------------------------------------------- request

  static MarketBudget? _budget(Map<String, dynamic> r) {
    final currency = _text(r['currency']);
    String money(double n) => formatMoney(n, currency);
    final min = _num(r['min_budget']);
    final max = _num(r['max_budget']);
    if (min != null && min == max) return BudgetExact(money(min));
    if (min != null && max != null) return BudgetRange(money(min), money(max));
    if (min != null) return BudgetFrom(money(min));
    if (max != null) return BudgetUpTo(money(max));
    final budget = _num(r['budget']);
    return budget == null ? null : BudgetExact(money(budget));
  }

  /// Request công khai (web `RequestCard`).
  static MarketRequestEntity request(Map<String, dynamic> r) {
    final user = _map(r['user']);
    final categories = <String>{
      ?label(r['category']),
      ..._list(r['categories']).map(label).nonNulls,
    }.toList();
    return MarketRequestEntity(
      id: _int(r['id']),
      userId: _int(r['user_id']) ?? _int(user?['id']),
      text:
          _text(r['content']) ??
          _text(r['description']) ??
          _text(r['title']) ??
          '',
      authorFirstName: _text(user?['first_name']) ?? _text(r['name']),
      avatar: _text(user?['profile_picture']),
      country: label(user?['country']) ?? _text(r['author_country']),
      createdAt: _date(r['created_at'] ?? r['time']),
      deliveryType: _text(r['delivery_type']),
      deadline: _date(r['deadline'])?.toLocal(),
      schedule: _schedule(r['schedule']),
      sellerLanguages: _strings(r['seller_languages']),
      budget: _budget(r),
      categories: categories,
      voiceUrl: _text(r['voice_url']),
      attachments: _media(r['attachments']),
      conversations:
          _int(r['conversations_count']) ?? _int(r['conversations']) ?? 0,
      offers:
          _int(r['offers_count']) ??
          (r['offers'] is num ? _int(r['offers'])! : 0),
      solved: r['solved'] == true || r['is_solved'] == true,
    );
  }

  // --------------------------------------------------------------- solution

  static HealthSolutionEntity? solution(Map<String, dynamic> s) {
    final id = _int(s['id']);
    if (id == null) return null;
    return HealthSolutionEntity(
      id: id,
      title: _text(s['title']) ?? '',
      categories: [
        for (final c in _list(s['library_categories']).map(_map).nonNulls)
          if (_int(c['id']) case final cid?)
            (id: cid, name: '${c['name'] ?? ''}'),
      ],
      applicableWhen: _text(s['applicable_when']),
      method: _text(s['method']),
      expectedResult: _text(s['expected_result']),
      notes: _text(s['notes']),
      hashtags: _strings(s['hashtags']),
      requestTemplate: _text(s['request_template']),
    );
  }

  // ------------------------------------------------------------- engagement

  static MapEntry<int, EngagementState>? engagement(Map<String, dynamic> it) {
    final id = _int(it['target_id']);
    if (id == null) return null;
    final mine = _map(it['my_state']);
    return MapEntry(
      id,
      EngagementState(
        likes: _int(it['likes']) ?? 0,
        saves: _int(it['saves']) ?? 0,
        contacts: _int(it['contacts']) ?? 0,
        liked: mine?['liked'] == true,
        saved: mine?['saved'] == true,
      ),
    );
  }

  // --------------------------------------------------------- medical travel

  /// Coordinator / seller của nước (web `toCoordinator` + `coordinatorToProfileCard`):
  /// danh tính là organization khi là người đại diện; xác minh = `seller_verified`.
  static MarketExpertEntity coordinator(Map<String, dynamic> e) {
    final represented = _representedOrg(e);
    final org = _map(e['organization']);
    final orgName = _text(org?['name']);
    final id = _int(e['id']) ?? 0;
    final name = _text(represented?['name']) ?? _text(e['shop_name']) ?? '#$id';
    final place = _sellerPlace(e);
    final summary = _map(e['review_summary']);
    final reviews = _int(summary?['review_count']) ?? 0;
    final orgLanguages = represented == null
        ? const <String>[]
        : sellerLanguageLabels(org?['languages'], null);
    return MarketExpertEntity(
      id: id,
      userId: _int(e['user_id']),
      name: name,
      slug: _text(e['slug']),
      avatar:
          _text(represented?['logo']) ??
          _text(_map(e['user'])?['profile_picture']),
      country: place.country,
      flag: place.flag,
      yearsOfExperience: _positiveInt(e['years_of_experience']),
      ratingValue: reviews > 0 ? _num(summary?['rating']) ?? 0 : 0,
      ratingCount: reviews,
      verified: e['seller_verified'] == true,
      about:
          (represented == null
              ? null
              : _orgDescription(represented['description'])) ??
          _text(e['about']),
      languages: orgLanguages.isNotEmpty
          ? orgLanguages
          : sellerLanguageLabels(e['supported_languages'], e['language_items']),
      // Người đại diện mang luôn tên organization → không lặp "Representative of <tên>".
      representativeOf: orgName != null && orgName != name ? orgName : null,
      independent: orgName == null,
    );
  }

  /// Service trên trang Medical Travel (web `toServiceCardData`): tên cơ sở đứng trước
  /// tên shop, nơi = nước của organization gắn với service.
  static MarketServiceEntity medicalService(Map<String, dynamic> s) {
    final base = service(s);
    final org = _map(s['organization']);
    final orgCountry = label(_map(org?['country']));
    final shop = _text(org?['name']) ?? base.seller.shopName;
    final seller = base.seller;
    return MarketServiceEntity(
      id: base.id,
      slug: base.slug,
      title: base.title,
      description: base.description,
      isMedicalTravel: base.isMedicalTravel,
      images: base.images,
      deliveries: base.deliveries,
      price: base.price,
      strikePrice: base.strikePrice,
      coverage: base.coverage,
      languages: null,
      place: orgCountry ?? seller.country,
      seller: MarketSeller(
        id: seller.id ?? _int(s['user_id']),
        shopName: shop,
        avatar: seller.avatar,
        country: seller.country,
        flag: seller.flag,
        profession: seller.profession,
        slug: seller.slug,
      ),
      rawPrice: base.rawPrice,
      originalPrice: base.originalPrice,
      status: base.status,
      imageList: base.imageList,
      coverList: base.coverList,
      rawDescription: base.rawDescription,
    );
  }

  static MarketDestination? destination(Map<String, dynamic> c) {
    final id = _int(c['id']);
    final title = _text(c['title']);
    if (id == null || title == null) return null;
    final gallery = _strings(c['gallery']);
    return MarketDestination(
      id: id,
      country: title,
      code: _text(c['code']),
      flag: flagUrl(c['flag'], c['code']),
      image: gallery.firstOrNull ?? _text(c['cover_image']),
      focus: plainText(_text(c['description'])),
    );
  }

  static MarketCountry? country(Map<String, dynamic> c, String code) {
    final id = _int(c['id']);
    if (id == null || id == 0) return null;
    final gallery = _strings(c['gallery']);
    final images = gallery.isNotEmpty ? gallery : [?_text(c['cover_image'])];
    return MarketCountry(
      id: id,
      title: _text(c['title']) ?? code.toUpperCase(),
      code: (_text(c['code']) ?? code).toUpperCase(),
      flag: flagUrl(c['flag'], c['code'] ?? code),
      description: plainText(_text(c['description'])),
      images: images.toSet().toList(),
    );
  }

  /// `GET /buyer/service/{id}` (web `ServiceDetail` + helper `_lib/detail.ts`).
  static MarketServiceDetail? serviceDetail(Map<String, dynamic> s) {
    final id = _int(s['id']);
    if (id == null) return null;
    final sellerProfile = _map(s['seller_profile']);
    final org = _map(s['organization']);
    final hasOrg = (_int(org?['id']) ?? 0) > 0 && _text(org?['name']) != null;
    final represented = _representedOrg(sellerProfile);
    final providerName =
        _text(represented?['name']) ?? _text(sellerProfile?['shop_name']);
    final orgCountry = hasOrg ? _map(org?['country']) : null;
    final country = orgCountry ?? _map(s['country']);

    // Ngôn ngữ: không gắn organization → của seller (title bảng languages), không thì của service.
    final own = _strings(s['supported_languages']);
    final sellerLangs = _strings(sellerProfile?['supported_languages']);
    final fromSeller = !hasOrg && sellerLangs.isNotEmpty;
    final items = _list(sellerProfile?['language_items']).map(_map).nonNulls;
    final languages = <({String code, String label})>[];
    for (final raw
        in hasOrg ? own : (sellerLangs.isNotEmpty ? sellerLangs : own)) {
      final code = raw.toLowerCase();
      if (languages.any((l) => l.code == code)) continue;
      final title = fromSeller
          ? _text(
              items
                  .where((i) => '${i['code']}'.toLowerCase() == code)
                  .firstOrNull?['title'],
            )
          : null;
      languages.add((code: code, label: title ?? languageName(code)));
    }

    final accreditations = _map(org?['accreditations']) ?? const {};
    return MarketServiceDetail(
      id: id,
      userId: _int(s['user_id']) ?? 0,
      title: _text(s['title']) ?? '',
      slug: _text(s['slug']) ?? '',
      description: _text(s['description']),
      images: _images(s['cover_image'], s['image']),
      price: s['price'] is num ? s['price'] as num : 0,
      duration: _positiveInt(s['duration']),
      durationUnit: switch (_text(s['duration_unit'])) {
        'minute' => 'minute',
        'hour' => 'hour',
        _ => 'day',
      },
      languages: languages,
      rating: _num(s['rating']) ?? 0,
      isMedicalTravel: s['is_medical_travel'] == true,
      faqs: [for (final f in _list(s['faqs']).map(_map).nonNulls) ?_faq(f)],
      locationTitle: label(country),
      locationFlag: flagUrl(country?['flag'], country?['code']),
      organizationName: hasOrg ? _text(org?['name']) : providerName,
      providerName: providerName,
      providerSlug: _text(sellerProfile?['slug']),
      providerAvatar: _text(_map(s['user'])?['profile_picture']),
      certs: [
        for (final c in MarketCert.values)
          if (accreditations[c.apiValue] == true) c,
      ],
      included: _strings(s['included_items']),
      notIncluded: _strings(s['not_included_items']),
      roadmapTitle: _text(s['roadmap_title']),
      roadmapSteps: _text(s['roadmap_steps']),
    );
  }

  static MarketFaq? _faq(Map<String, dynamic> f) {
    final question = plainText(_text(f['question']));
    final answers = _list(f['answers']);
    final list = answers.isNotEmpty
        ? answers.map((a) => a is Map ? a['answer'] : a)
        : [f['answer']];
    final texts = list
        .map((a) => plainText(_text(a)))
        .where((a) => a.isNotEmpty);
    if (question.isEmpty || texts.isEmpty) return null;
    return MarketFaq(question: question, answers: texts.toList());
  }

  /// Tên ngôn ngữ từ mã ISO (web dùng `Intl.DisplayNames`).
  static String languageName(String code) =>
      _languageNames[code.toLowerCase()] ?? code.toUpperCase();

  static const _languageNames = {
    'en': 'English',
    'vi': 'Vietnamese',
    'th': 'Thai',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ru': 'Russian',
    'ar': 'Arabic',
    'pt': 'Portuguese',
    'it': 'Italian',
    'hi': 'Hindi',
    'id': 'Indonesian',
    'ms': 'Malay',
    'tr': 'Turkish',
    'hu': 'Hungarian',
    'nl': 'Dutch',
    'pl': 'Polish',
  };

  /// Mã vùng từ bảng countries: mỗi mã một lựa chọn, giữ thứ tự API (web `phoneCodeOptions`).
  static List<PhoneCodeOption> phoneCodes(
    List<Map<String, dynamic>> countries,
  ) {
    final seen = <String>{};
    final out = <PhoneCodeOption>[];
    for (final c in countries) {
      final digits = '${c['phone_code'] ?? ''}'
          .replaceAll(RegExp(r'\D'), '')
          .replaceFirst(RegExp('^0+'), '');
      if (digits.isEmpty) continue;
      final code = '+$digits';
      if (!seen.add(code)) continue;
      final iso = '${c['code'] ?? ''}'.trim().toUpperCase();
      final flag = RegExp(r'^[A-Z]{2}$').hasMatch(iso)
          ? String.fromCharCodes(iso.codeUnits.map((u) => 0x1F1A5 + u))
          : '';
      out.add(
        PhoneCodeOption(code: code, label: flag.isEmpty ? code : '$flag $code'),
      );
    }
    return out;
  }
}
