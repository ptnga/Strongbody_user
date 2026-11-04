import 'package:strongbody_buyer/core/utils/language_names.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_draft_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_form_values.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_options.dart';
import 'package:strongbody_buyer/modules/social_market/data/mappers/market_mapper.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_listing_entities.dart';

import '../../domain/entities/assistant_entities.dart';

/// JSON của trợ lý ↔ entity (web `_lib/searchAssistant.ts`).
class AssistantMapper {
  const AssistantMapper._();

  static Map<String, dynamic>? _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  static String? _text(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }

  static int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

  static double? _positive(Object? v) =>
      v is num && v > 0 ? v.toDouble() : null;

  static List<String> _strings(Object? v) => v is List
      ? v.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList()
      : const [];

  // ------------------------------------------------------------------ events

  /// Một dòng `data:` của SSE → event; loại không dùng (`step`) / hỏng → null.
  static AssistantEvent? event(Map<String, dynamic> e) => switch (e['type']) {
    'route' => AssistantRouteEvent(_text(e['branch']) ?? ''),
    'result' => switch (_map(e['result'])) {
      final r? => AssistantResultEvent(result(r)),
      _ => null,
    },
    'delta' => AssistantDeltaEvent('${e['text'] ?? ''}'),
    'done' => AssistantDoneEvent(
      branch: _text(e['branch']),
      historyText: _text(e['history_text']),
    ),
    'error' => const AssistantErrorEvent(),
    _ => null,
  };

  // ------------------------------------------------------------------ result

  static AssistantResult result(Map<String, dynamic> r) {
    final understanding = _map(r['understanding']);
    final near = _map(r['near']);
    final relaxed = _map(r['relaxed']);
    final draft = _map(r['request_draft']);
    return AssistantResult(
      branch: _text(r['branch']) ?? '',
      answer: _text(r['answer']),
      understanding: understanding,
      kinds: _strings(r['kinds']).map(AssistantKind.fromApi).nonNulls.toList(),
      cards: _groups(r['cards']),
      closeMatches: _groups(r['close_matches']),
      totals: {
        for (final entry in (_map(r['totals']) ?? const {}).entries)
          if ((AssistantKind.fromApi(entry.key), _int(entry.value)) case (
            final kind?,
            final n?,
          ))
            kind: n,
      },
      requestDraft: draft == null ? null : requestDraft(draft),
      needsLocation: r['needs_location'] == true,
      near: switch (_text(near?['label'])) {
        final label? => AssistantNear(
          label: label,
          fromGps: near?['source'] == 'gps',
        ),
        _ => null,
      },
      nearRelaxed:
          relaxed?.values.any((v) => v is List && v.contains('near')) ?? false,
      suggestions: _strings(understanding?['suggestions']),
      reason: _text(understanding?['reason']),
      raw: r,
    );
  }

  static Map<AssistantKind, List<AssistantCard>> _groups(Object? raw) {
    final out = <AssistantKind, List<AssistantCard>>{};
    for (final entry in (_map(raw) ?? const {}).entries) {
      final kind = AssistantKind.fromApi(entry.key);
      final list = entry.value;
      if (kind == null || list is! List) continue;
      final cards = list.map(_map).nonNulls.map(card).nonNulls.toList();
      if (cards.isNotEmpty) out[kind] = cards;
    }
    return out;
  }

  // ------------------------------------------------------------------- cards

  static AssistantCard? card(Map<String, dynamic> c) {
    final ref = _text(c['ref']) ?? '${c['kind']}:${c['id']}';
    final missing = _strings(
      c['missing'],
    ).map(AssistantMissing.fromApi).nonNulls.toList();
    return switch (c['kind']) {
      'seller' => AssistantCard(ref: ref, seller: _seller(c), missing: missing),
      'offer' => AssistantCard(
        ref: ref,
        offer: MarketMapper.offer(_offerJson(c)),
        missing: missing,
      ),
      'service' => AssistantCard(
        ref: ref,
        service: MarketMapper.service(_serviceJson(c)),
        missing: missing,
      ),
      _ => null,
    };
  }

  /// Mã ngôn ngữ → tên ("en" → "English").
  static List<String> _languageNames(Object? v) =>
      _strings(v).map(languageLabel).toList();

  /// Thẻ service → JSON kiểu `/public/services` (web `assistantServiceToApi`).
  static Map<String, dynamic> _serviceJson(Map<String, dynamic> c) {
    final price = c['price_from'];
    final medicalTravel = c['medical_travel'] == true;
    final destinations = _strings(c['destinations']);
    return {
      'id': _int(c['id']),
      'slug': c['slug'],
      'title': c['title'],
      'description': c['description'],
      'image': _text(c['image']) == null ? null : [c['image']],
      'price': price,
      'currency': c['currency'],
      'is_medical_travel': medicalTravel,
      // Medical Travel: nơi điều trị; còn lại: địa chỉ cơ sở (rỗng → Online / nước seller).
      'location': medicalTravel && destinations.isNotEmpty
          ? destinations.join(', ')
          : c['address'],
      'languages': switch (_languageNames(c['languages']).join(', ')) {
        '' => null,
        final s => s,
      },
      'delivery_options': [
        for (final d in _strings(c['delivery']))
          {'delivery_type': d, 'price': price, 'is_active': true},
      ],
      'user': {
        'id': _int(c['user_id']),
        'profile_picture': c['provider_avatar'],
        'seller_profile': {
          'shop_name': c['provider'],
          'slug': c['provider_slug'],
        },
      },
    };
  }

  /// Thẻ seller → card hồ sơ (web `assistantSellerToExpert`).
  static MarketExpertEntity _seller(Map<String, dynamic> c) {
    final reviews = _int(c['reviews']) ?? 0;
    final years = _int(c['years_experience']);
    return MarketExpertEntity(
      id: _int(c['id']),
      userId: _int(c['user_id']),
      name: _text(c['title']) ?? '',
      slug: _text(c['slug']),
      avatar: _text(c['image']),
      subtitle: _text(c['subtitle']),
      medicalTravel: c['medical_travel'] == true,
      yearsOfExperience: years != null && years > 0 ? years : null,
      ratingValue: reviews > 0 ? (c['rating'] as num?)?.toDouble() ?? 0 : 0,
      ratingCount: reviews,
      verified: c['verified'] == true,
      about: _text(c['description']),
      languages: _languageNames(c['languages']),
    );
  }

  /// Thẻ offer → JSON kiểu public offer (web `assistantOfferToApi`).
  static Map<String, dynamic> _offerJson(Map<String, dynamic> c) {
    final price = c['price_from'];
    final delivery = _strings(c['delivery']);
    Object? priceIf(String mode) => delivery.contains(mode) ? price : null;
    return {
      'id': _int(c['id']),
      'detail': c['title'],
      'currency': c['currency'],
      'price_remote': priceIf('remote'),
      'price_at_office': priceIf('at_office'),
      'price_at_home': priceIf('at_home'),
      'delivery_types': delivery,
      'languages': _strings(c['languages']),
      'seller_id': _int(c['user_id']),
      'seller': {
        'id': _int(c['user_id']),
        'profile_picture': c['provider_avatar'],
        'seller_profile': {'shop_name': c['provider']},
      },
    };
  }

  // ------------------------------------------------------------ request draft

  static String _num(double n) =>
      n % 1 == 0 ? n.toInt().toString() : n.toString();

  /// `request_draft` → giá trị form Post Request + meta AI (web `draftToFormValues`).
  static RequestDraftEntity requestDraft(
    Map<String, dynamic> d, {
    DateTime? today,
  }) {
    final min = _positive(d['budget_min']);
    final max = _positive(d['budget_max']);
    final budget = min != null && max != null && min != max
        ? '${_num(min)}-${_num(max)}'
        : switch (max ?? min) {
            final n? => _num(n),
            _ => '',
          };
    final currency = '${d['currency'] ?? ''}'.toUpperCase();
    final description = (_text(d['description']) ?? '');
    return RequestDraftEntity(
      isEmpty: d['empty'] == true,
      values: RequestFormValues(
        description: description.length > RequestFormValues.maxDescription
            ? description.substring(0, RequestFormValues.maxDescription)
            : description,
        budget: budget,
        currency: requestCurrencies.contains(currency) ? currency : 'USD',
        deliveryTypes: _strings(
          d['delivery_types'],
        ).map(RequestDeliveryType.fromApi).nonNulls.toList(),
        deadline: _deadline(_text(d['deadline']), today ?? DateTime.now()),
        sellerLanguages: _strings(
          d['seller_languages'],
        ).where((c) => requestLanguageByCode(c) != null).toList(),
      ),
      assistant: RequestAssistantMeta(
        categoryIds: _ints(d['category_ids']),
        qualityScore: _int(d['rank']),
        suggestion: _text(d['suggestion']) ?? '',
      ),
    );
  }

  static List<int> _ints(Object? v) =>
      v is List ? v.map(_int).nonNulls.toList() : const [];

  /// "YYYY-MM-DD" chưa qua → 09:00 ngày đó (giờ máy); đã qua / sai dạng → bỏ.
  static DateTime? _deadline(String? value, DateTime today) {
    if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final date = DateTime.tryParse(value);
    if (date == null) return null;
    final start = DateTime(today.year, today.month, today.day);
    if (date.isBefore(start)) return null;
    return DateTime(date.year, date.month, date.day, 9);
  }

  /// Ngược lại [requestDraft] — để lưu hội thoại.
  static Map<String, dynamic> requestDraftJson(RequestDraftEntity draft) {
    final v = draft.values;
    final budget = v.parsedBudget;
    final deadline = v.deadline;
    String two(int n) => n.toString().padLeft(2, '0');
    return {
      'description': v.description,
      'category_ids': draft.assistant.categoryIds,
      'delivery_types': v.deliveryTypes.map((t) => t.apiValue).toList(),
      if (budget.min != null && budget.min != budget.max)
        'budget_min': budget.min,
      if (budget.max != null) 'budget_max': budget.max,
      'currency': v.currency,
      if (deadline != null)
        'deadline':
            '${deadline.year}-${two(deadline.month)}-${two(deadline.day)}',
      'seller_languages': v.sellerLanguages,
      if (draft.assistant.qualityScore != null)
        'rank': draft.assistant.qualityScore,
      'suggestion': draft.assistant.suggestion,
      if (draft.isEmpty) 'empty': true,
    };
  }

  /// Điều kiện tìm đã hiểu → bản nháp request khi không ai khớp (web `understandingToDraft`):
  /// mô tả = câu khách nói (kèm khu vực nếu có), ngân sách, hình thức, ngày, ngôn ngữ, category.
  static RequestDraftEntity understandingToDraft(
    Map<String, dynamic>? u,
    String said, {
    DateTime? today,
  }) {
    final x = u ?? const <String, dynamic>{};
    final place = _text(x['location_text']) ?? '';
    var description = said.trim().isNotEmpty
        ? said.trim()
        : (_text(x['refined']) ?? '');
    if (place.isNotEmpty &&
        !description.toLowerCase().contains(place.toLowerCase())) {
      description += ' ($place)';
    }
    return requestDraft({
      'description': description,
      'category_ids': x['category_ids'],
      'delivery_types': _strings(
        x['delivery_types'],
      ).map((d) => d == 'at_office' ? 'at_clinic' : d).toList(),
      'budget_min': x['budget_min'],
      'budget_max': x['budget_max'],
      'currency': x['currency'],
      'deadline': x['date'],
      'seller_languages': x['languages'],
    }, today: today);
  }

  // ------------------------------------------------------------ conversation

  /// Lịch sử gửi BE: lượt trợ lý dùng `history` (BE dựng), lượt rỗng / lỗi bỏ qua.
  static List<Map<String, String>> historyMessages(List<AssistantTurn> turns) =>
      [
        for (final t in turns)
          switch (t) {
            AssistantUserTurn(:final content) => {
              'role': 'user',
              'content': content.trim(),
            },
            AssistantReplyTurn(:final history, :final text) => {
              'role': 'assistant',
              'content': (history ?? text).trim(),
            },
          },
      ].where((m) => m['content']!.isNotEmpty).toList();

  static Map<String, dynamic> turnJson(AssistantTurn turn) => switch (turn) {
    AssistantUserTurn(:final content) => {'role': 'user', 'content': content},
    final AssistantReplyTurn t => {
      'role': 'assistant',
      'branch': t.branch,
      'text': t.text,
      'history': t.history,
      'result': t.result?.raw,
      'said_text': t.saidText,
      'error': t.error?.name,
      if (t.requestDraft case final d?) 'request_draft': requestDraftJson(d),
    },
  };

  static AssistantTurn? turn(Map<String, dynamic> j) {
    if (j['role'] == 'user') {
      final content = _text(j['content']);
      return content == null ? null : AssistantUserTurn(content);
    }
    if (j['role'] != 'assistant') return null;
    final result = _map(j['result']);
    final draft = _map(j['request_draft']);
    return AssistantReplyTurn(
      branch: _text(j['branch']),
      text: '${j['text'] ?? ''}',
      history: _text(j['history']),
      result: result == null ? null : AssistantMapper.result(result),
      saidText: _text(j['said_text']),
      error: AssistantTurnError.values
          .where((e) => e.name == j['error'])
          .firstOrNull,
      requestDraft: draft == null ? null : requestDraft(draft),
    );
  }
}
