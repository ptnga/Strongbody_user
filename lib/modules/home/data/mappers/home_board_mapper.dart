import 'dart:convert';

import 'package:strongbody_buyer/modules/social_market/data/mappers/market_mapper.dart';

import '../../domain/entities/board_entities.dart';

/// JSON của board → entity (web `slimRequest` / `slimServiceCard`).
class HomeBoardMapper {
  HomeBoardMapper._();

  static Map<String, dynamic>? _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  static String? _text(Object? v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty || s == 'null' || s == 'undefined' ? null : s;
  }

  static int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

  static num? _num(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');

  /// Chuỗi JSON hoặc giá trị sẵn.
  static Object? _json(Object? v) {
    if (v is! String) return v;
    try {
      return jsonDecode(v);
    } catch (_) {
      return null;
    }
  }

  /// Ngày không kèm múi giờ coi là UTC (web `formatTimeAgo`).
  static DateTime? _date(Object? v) {
    final s = _text(v);
    if (s == null) return null;
    final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(s);
    return DateTime.tryParse(hasZone ? s : '${s.replaceFirst(' ', 'T')}Z');
  }

  static final _photoName = RegExp(
    r'\.(jpe?g|png|webp|gif|heic|avif)$',
    caseSensitive: false,
  );

  static BoardRequest? request(Map<String, dynamic> r) {
    final id = _int(r['id']);
    final text =
        _text(r['content']) ?? _text(r['description']) ?? _text(r['title']);
    if (id == null || text == null) return null;
    final user = _map(r['user']);
    final country = _map(user?['country']);
    // Ẩn danh trừ khi BE nói rõ là không (false / 0 / 'false').
    final rawAnon = r['anonymous'] ?? r['is_anonymous'];
    final anonymous = !(rawAnon == false || rawAnon == 0 || rawAnon == 'false');
    final categories = r['categories'];
    final languages = _json(r['seller_languages']);
    final files = _json(r['attachments']);
    return BoardRequest(
      id: id,
      userId: _int(r['user_id']) ?? _int(user?['id']),
      text: text,
      anonymous: anonymous,
      firstName: anonymous
          ? null
          : _text(user?['first_name']) ?? _text(r['name']),
      lastName: anonymous ? null : _text(user?['last_name']),
      avatar: anonymous ? null : _text(user?['profile_picture']),
      country: _text(country?['title']) ?? _text(r['author_country']),
      flag: MarketMapper.flagUrl(country?['flag'], country?['code']),
      createdAt: _date(r['created_at'] ?? r['time']),
      category:
          _text(_map(r['category'])?['name']) ??
          (categories is List && categories.isNotEmpty
              ? _text(_map(categories.first)?['name'])
              : null),
      closed: r['status'] == 'closed',
      solved: r['solved'] == true || r['is_solved'] == true,
      minBudget: _num(r['min_budget']),
      maxBudget: _num(r['max_budget']),
      budget: _num(r['budget']),
      currency: _text(r['currency'])?.toUpperCase() ?? 'USD',
      deliveryType: _text(r['delivery_type']),
      languages: [
        if (languages is List)
          for (final l in languages) ?_text(l),
      ],
      attachments: [
        if (files is List)
          for (final f in files.map(_map).nonNulls)
            if (_text(f['url']) case final url?)
              BoardAttachment(
                url: url,
                name: _text(f['name']),
                isPhoto:
                    '${f['type'] ?? ''}'.startsWith('image') ||
                    _photoName.hasMatch(_text(f['name']) ?? url),
              ),
      ],
    );
  }

  /// Thứ tự hình thức của dòng offer (web `serviceDetail.delivery`).
  static const _offerDelivery = ['remote', 'at_office', 'at_home'];

  static BoardOffer? offer(Map<String, dynamic> s) {
    final service = MarketMapper.service(s);
    if (service.id == null) return null;
    final options = [
      for (final o
          in (s['delivery_options'] is List
              ? s['delivery_options'] as List
              : const []))
        if (_map(o) case final m? when m['is_active'] != false) m,
    ];
    final types = options.map((o) => _text(o['delivery_type'])).toSet();
    final checks = _map(_map(s['user'])?['verification'])?['checks'];
    final consultation = s['pricing_mode'] == 'consultation';
    const verifiable = {'identity', 'phone', 'profession'};
    return BoardOffer(
      service: service,
      freeConsultation: s['is_free_consultation'] == true,
      verifiedChecks: checks is List
          ? checks
                .map(_map)
                .nonNulls
                .where(
                  (c) =>
                      verifiable.contains(c['key']) && c['state'] == 'verified',
                )
                .length
          : 0,
      price: _num(s['price']),
      priceMax: consultation ? _num(s['price_max']) : null,
      consultation: consultation,
      deliveryTypes: _offerDelivery.where(types.contains).toList(),
    );
  }

  static BoardCountry? country(Map<String, dynamic> c) {
    final title = _text(c['title']) ?? _text(c['name']);
    if (title == null) return null;
    return BoardCountry(
      id: _int(c['id']),
      title: title,
      code: _text(c['code'])?.toUpperCase(),
      flag: MarketMapper.flagUrl(c['flag'], c['code']),
      count: _int(c['count']) ?? 0,
    );
  }
}
