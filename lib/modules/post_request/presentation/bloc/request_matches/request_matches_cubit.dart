import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/utils/app_logger.dart';
import 'package:strongbody_buyer/core/utils/language_names.dart';
import 'package:strongbody_buyer/modules/assistant/data/datasources/remote/assistant_remote_datasource.dart';
import 'package:strongbody_buyer/modules/assistant/domain/entities/assistant_entities.dart';
import 'package:strongbody_buyer/modules/assistant/domain/usecases/assistant_use_cases.dart';
import 'package:strongbody_buyer/modules/chat/domain/usecases/chat_use_cases.dart';
import 'package:strongbody_buyer/modules/social_market/data/mappers/market_mapper.dart';
import 'package:strongbody_buyer/modules/social_market/data/services/market_chat_publisher.dart';

import '../../../domain/entities/posted_request_entity.dart';
import '../../../domain/entities/request_form_values.dart';
import '../../../domain/usecases/get_sent_request_use_case.dart';

enum RequestMatchesStatus { loading, success, failure }

/// Một chuyên gia gợi ý (web `Match`): seller, hoặc người cung cấp một service.
class RequestMatch extends Equatable {
  final int userId;
  final String name;
  final String? avatar;
  final String? country;
  final String? flag;

  /// Gợi ý đến từ một service → hiện tên service dưới tên người.
  final int? serviceId;
  final String? serviceTitle;
  final bool verified;

  const RequestMatch({
    required this.userId,
    required this.name,
    this.avatar,
    this.country,
    this.flag,
    this.serviceId,
    this.serviceTitle,
    this.verified = false,
  });

  @override
  List<Object?> get props => [userId, name, serviceId];
}

class RequestMatchesState extends Equatable {
  final RequestMatchesStatus requestStatus;
  final SentRequest? request;
  final RequestMatchesStatus matchesStatus;
  final List<RequestMatch> matches;
  final bool rateLimited;

  /// Đang chia sẻ request vào chat với người này.
  final int? openingUserId;

  const RequestMatchesState({
    this.requestStatus = RequestMatchesStatus.loading,
    this.request,
    this.matchesStatus = RequestMatchesStatus.loading,
    this.matches = const [],
    this.rateLimited = false,
    this.openingUserId,
  });

  RequestMatchesState copyWith({
    RequestMatchesStatus? requestStatus,
    SentRequest? request,
    RequestMatchesStatus? matchesStatus,
    List<RequestMatch>? matches,
    bool? rateLimited,
    int? openingUserId,
    bool clearOpening = false,
  }) => RequestMatchesState(
    requestStatus: requestStatus ?? this.requestStatus,
    request: request ?? this.request,
    matchesStatus: matchesStatus ?? this.matchesStatus,
    matches: matches ?? this.matches,
    rateLimited: rateLimited ?? this.rateLimited,
    openingUserId: clearOpening ? null : (openingUserId ?? this.openingUserId),
  );

  @override
  List<Object?> get props => [
    requestStatus,
    request,
    matchesStatus,
    matches,
    rateLimited,
    openingUserId,
  ];
}

/// Trang ngay sau khi đăng request (web `/buyer/request/matches/{id}` + `RequestMatches`):
/// tóm tắt request + chuyên gia phù hợp từ trợ lý tìm kiếm (LLM + Elasticsearch):
/// 1. Lượt 1: mô tả + lựa chọn ở form → LLM rút ý / category rồi tìm.
/// 2. LLM bỏ sót nơi nhận / ngôn ngữ / category của form → lượt 2 với `understanding`
///    đã gộp (bỏ qua LLM); không còn ai thì giữ lượt 1.
/// Bấm Chat: gửi thẻ request + lời chào vào cuộc trò chuyện rồi mở chat.
class RequestMatchesCubit extends Cubit<RequestMatchesState> {
  final GetSentRequestUseCase _getRequest;
  final StreamAssistantChatUseCase _search;
  final OpenChatSessionUseCase _openSession;
  final MarketChatPublisher _publisher;
  final GlobalStorage _storage;

  /// Số chuyên gia gợi ý tối đa (web trang riêng: 6).
  static const maxMatches = 6;

  /// Đã chia sẻ request X cho chuyên gia Y → không gửi lại thẻ + lời chào.
  static final _shared = <String>{};

  RequestMatchesCubit({
    required GetSentRequestUseCase getRequest,
    required StreamAssistantChatUseCase search,
    required OpenChatSessionUseCase openSession,
    required MarketChatPublisher publisher,
    required GlobalStorage storage,
  }) : _getRequest = getRequest,
       _search = search,
       _openSession = openSession,
       _publisher = publisher,
       _storage = storage,
       super(const RequestMatchesState());

  Future<void> start(int id, {required String language}) async {
    final result = await _getRequest(id);
    if (isClosed) return;
    final request = result.toNullable();
    if (request == null) {
      emit(state.copyWith(requestStatus: RequestMatchesStatus.failure));
      return;
    }
    emit(
      state.copyWith(
        requestStatus: RequestMatchesStatus.success,
        request: request,
      ),
    );
    await _findMatches(request, language);
  }

  Future<void> _findMatches(SentRequest request, String language) async {
    final history = [AssistantUserTurn(requestQuery(request))];
    try {
      final first = await _run(history, language);
      var matches = toMatches(first, _storage.userId);
      final filtered = withFormFilters(first?.understanding, request);
      if (filtered != null) {
        try {
          final second = await _run(history, language, understanding: filtered);
          final strict = toMatches(second, _storage.userId);
          if (strict.isNotEmpty) matches = strict;
        } catch (_) {
          // Lượt lọc thêm lỗi → giữ kết quả lượt 1.
        }
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          matchesStatus: RequestMatchesStatus.success,
          matches: matches,
        ),
      );
    } on _RateLimited {
      if (!isClosed) {
        emit(
          state.copyWith(
            matchesStatus: RequestMatchesStatus.failure,
            rateLimited: true,
          ),
        );
      }
    } catch (e) {
      AppLogger.w('Request matches failed', e);
      if (!isClosed) {
        emit(state.copyWith(matchesStatus: RequestMatchesStatus.failure));
      }
    }
  }

  /// 1 lượt tìm: trả kết quả (kể cả khi stream lỗi giữa chừng nhưng đã có result).
  Future<AssistantResult?> _run(
    List<AssistantTurn> history,
    String language, {
    Map<String, dynamic>? understanding,
  }) async {
    try {
      await for (final event in _search(
        AssistantChatParams(
          history: history,
          language: language,
          understanding: understanding,
        ),
      )) {
        if (event is AssistantResultEvent) return event.result;
        if (event is AssistantErrorEvent) throw Exception('assistant error');
      }
    } on AssistantRateLimitException {
      throw const _RateLimited();
    }
    return null;
  }

  /// Chia sẻ request vào chat với chuyên gia; trả `true` khi mở được chat (gửi thẻ lỗi
  /// vẫn mở chat như web).
  Future<bool> shareToChat(RequestMatch match, String intro) async {
    final request = state.request;
    final buyerId = _storage.userId;
    if (request == null || state.openingUserId != null) return false;
    emit(state.copyWith(openingUserId: match.userId));
    final key = '${request.id}:${match.userId}';
    try {
      if (buyerId != null && !_shared.contains(key)) {
        final session = (await _openSession(match.userId)).toNullable();
        if (session != null) {
          final budget = RequestFormValues(budget: request.budget).parsedBudget;
          final budgetText = budgetLabel(request);
          await _publisher.publishInquiry(
            session: session,
            kind: 'request',
            cardData: {
              'id': request.id,
              'description': request.description,
              'buyerId': buyerId,
              if (budgetText.isNotEmpty) ...{
                'budget': budgetText,
                'budget_min': budget.min,
                'budget_max': budget.max,
                'budget_currency': request.currency,
              },
            },
            content: intro,
          );
          _shared.add(key);
        }
      }
    } catch (e) {
      AppLogger.w('Share request to chat failed', e);
    }
    if (!isClosed) emit(state.copyWith(clearOpening: true));
    return true;
  }

  // ------------------------------------------------------------------ helpers

  /// "100 USD" / "120–150 USD"; không có ngân sách → ''.
  static String budgetLabel(SentRequest r) {
    final b = RequestFormValues(budget: r.budget).parsedBudget;
    if (b.min == null && b.max == null) return '';
    String n(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
    final range = b.min != null && b.max != null && b.min != b.max
        ? '${n(b.min!)}–${n(b.max!)}'
        : n(b.max ?? b.min!);
    return '$range ${r.currency}'.trim();
  }

  static const _deliveryEn = {
    RequestDeliveryType.remote: 'remote / online',
    RequestDeliveryType.atHome: 'at home',
    RequestDeliveryType.atClinic: 'at a clinic',
    RequestDeliveryType.atOffice: 'at office',
  };

  /// Câu gửi trợ lý: mô tả + lựa chọn ở form (phần thêm viết tiếng Anh, như web).
  static String requestQuery(SentRequest r) {
    final budget = budgetLabel(r);
    final prefs = [
      if (r.deliveryTypes.isNotEmpty)
        'where: ${r.deliveryTypes.map((d) => _deliveryEn[d]).join(', ')}',
      if (budget.isNotEmpty) 'budget: $budget',
      if (r.sellerLanguages.isNotEmpty)
        'languages: ${r.sellerLanguages.map(languageLabel).join(', ')}',
    ];
    final text = r.description.trim();
    return prefs.isEmpty ? text : '$text\n\nPreferences: ${prefs.join('; ')}.';
  }

  /// Điều kiện LLM đã hiểu + lựa chọn ở form làm bộ lọc cứng; null nếu LLM đã đủ.
  static Map<String, dynamic>? withFormFilters(
    Map<String, dynamic>? u,
    SentRequest r,
  ) {
    if (u == null) return null;
    List<String> list(Object? v) =>
        v is List ? v.map((e) => '$e').toList() : const [];
    final wantDelivery = [
      for (final d in r.deliveryTypes)
        d == RequestDeliveryType.atClinic ? 'at_office' : d.apiValue,
    ];
    final haveDelivery = list(u['delivery_types']);
    final wantLangs = r.sellerLanguages.map((l) => l.toLowerCase()).toList();
    final haveLangs = list(u['languages']).map((l) => l.toLowerCase()).toList();
    final haveCats = u['category_ids'] is List
        ? u['category_ids'] as List
        : const [];
    final missingDelivery = wantDelivery.any((d) => !haveDelivery.contains(d));
    final missingLangs = wantLangs.any((l) => !haveLangs.contains(l));
    final missingCats = haveCats.isEmpty && r.categoryIds.isNotEmpty;
    if (!missingDelivery && !missingLangs && !missingCats) return null;
    return {
      ...u,
      'delivery_types': missingDelivery ? wantDelivery : haveDelivery,
      'languages': missingLangs
          ? {...haveLangs, ...wantLangs}.toList()
          : haveLangs,
      'category_ids': missingCats ? r.categoryIds : haveCats,
      'relax': true,
    };
  }

  /// Thẻ seller + thẻ service → danh sách chuyên gia (mỗi người một dòng): seller
  /// trước, rồi người cung cấp service chưa có; bỏ chính người đăng.
  static List<RequestMatch> toMatches(AssistantResult? result, int? selfId) {
    final out = <RequestMatch>[];
    final seen = <int>{?selfId};
    void add(RequestMatch m) {
      if (out.length >= maxMatches || !seen.add(m.userId)) return;
      out.add(m);
    }

    final cards = result?.raw['cards'];
    List<Map> group(String kind) => cards is Map && cards[kind] is List
        ? (cards[kind] as List).whereType<Map>().toList()
        : const [];
    int? id(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    String? text(Object? v) {
      final s = '${v ?? ''}'.trim();
      return s.isEmpty ? null : s;
    }

    for (final c in group('sellers')) {
      final userId = id(c['user_id']);
      if (userId == null) continue;
      add(
        RequestMatch(
          userId: userId,
          name: text(c['title']) ?? '',
          avatar: text(c['image']),
          country: text(c['country']),
          flag: MarketMapper.flagUrl(c['country_flag'], c['country_code']),
          verified: c['verified'] == true,
        ),
      );
    }
    for (final c in group('services')) {
      final userId = id(c['user_id']);
      if (userId == null) continue;
      add(
        RequestMatch(
          userId: userId,
          name: text(c['provider']) ?? text(c['title']) ?? '',
          avatar: text(c['provider_avatar']),
          country: text(c['country']),
          flag: MarketMapper.flagUrl(c['country_flag'], c['country_code']),
          serviceId: id(c['id']),
          serviceTitle: text(c['title']),
          verified: c['verified'] == true,
        ),
      );
    }
    return out;
  }
}

class _RateLimited implements Exception {
  const _RateLimited();
}
