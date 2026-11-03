import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';

import '../../data/datasources/remote/assistant_remote_datasource.dart';
import '../../data/mappers/assistant_mapper.dart';
import '../../domain/entities/assistant_entities.dart';
import '../../domain/usecases/assistant_use_cases.dart';

class AssistantChatState extends Equatable {
  final List<AssistantTurn> turns;

  /// Đang chạy một lượt (nút gửi thành nút Dừng).
  final bool busy;

  const AssistantChatState({this.turns = const [], this.busy = false});

  AssistantChatState copyWith({List<AssistantTurn>? turns, bool? busy}) =>
      AssistantChatState(turns: turns ?? this.turns, busy: busy ?? this.busy);

  @override
  List<Object?> get props => [turns, busy];
}

/// Chat trợ lý tìm kiếm (web `AssistantChatClient`): mỗi lượt gửi cả lịch sử, BE chọn
/// nhánh (tìm kiếm / đăng request / hỏi về StrongBody / hỏi tiếp về kết quả) và trả
/// từng event; hỏi tiếp bao nhiêu lượt cũng được, các lượt sau hiểu theo ngữ cảnh.
class AssistantChatCubit extends Cubit<AssistantChatState> {
  final StreamAssistantChatUseCase _chat;
  final AssistantHistoryUseCase _history;

  CancelToken? _token;
  String _language = 'en';

  AssistantChatCubit({
    required StreamAssistantChatUseCase chat,
    required AssistantHistoryUseCase history,
  }) : _chat = chat,
       _history = history,
       super(const AssistantChatState());

  /// Mở màn: nạp hội thoại cũ rồi gửi câu vừa nhập ở Home / hero (nếu có).
  void start({required String language, String? text, String? source}) {
    _language = language;
    emit(state.copyWith(turns: _history.load()));
    final first = text?.trim() ?? '';
    if (first.isNotEmpty) ask(first, source: source ?? 'entry');
  }

  /// Lần tìm gần nhất trong chat (web `lastSearch`).
  static ({Map<String, dynamic> understanding, String text})? lastSearch(
    List<AssistantTurn> turns,
  ) {
    for (final t in turns.reversed) {
      if (t is AssistantReplyTurn &&
          t.result?.branch == 'search' &&
          t.result?.understanding != null) {
        return (
          understanding: t.result!.understanding!,
          text: t.saidText ?? '',
        );
      }
    }
    return null;
  }

  Future<void> ask(
    String raw, {
    List<AssistantTurn>? base,
    String source = 'composer',
  }) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    final history = base ?? state.turns;
    final prev = lastSearch(history);
    final saidText = prev != null && prev.text.isNotEmpty
        ? _lastThree('${prev.text} · $text')
        : text;
    final next = [...history, AssistantUserTurn(text)];
    AppAnalytics.capture(AnalyticsEvents.assistantMessageSent, {
      'source': source,
      'query_length': text.length,
      'turn': next.whereType<AssistantUserTurn>().length,
    });
    emit(
      state.copyWith(
        turns: [
          ...next,
          AssistantReplyTurn(streaming: true, saidText: saidText),
        ],
      ),
    );
    await _stream(
      next,
      previous: prev?.understanding,
      previousText: prev?.text,
    );
  }

  static String _lastThree(String said) {
    final parts = said.split(' · ');
    return parts.sublist(parts.length > 3 ? parts.length - 3 : 0).join(' · ');
  }

  /// Chạy 1 lượt và đổ event vào lượt trợ lý cuối (đã thêm sẵn, đang stream).
  Future<void> _stream(
    List<AssistantTurn> next, {
    Map<String, dynamic>? previous,
    String? previousText,
  }) async {
    _token?.cancel();
    final token = CancelToken();
    _token = token;
    // Chỉ lượt đang chạy mới được sửa lượt cuối (lượt cũ bị huỷ vì khách gửi câu mới thì thôi).
    bool mine() => identical(_token, token) && !isClosed;
    void patch(AssistantReplyTurn Function(AssistantReplyTurn) fn) {
      if (mine()) _patchLast(fn);
    }

    emit(state.copyWith(busy: true));
    try {
      final events = _chat(
        AssistantChatParams(
          history: next,
          language: _language,
          previous: previous,
          previousText: previousText,
          cancelToken: token,
        ),
      );
      await for (final event in events) {
        if (!mine()) break;
        switch (event) {
          case AssistantRouteEvent(:final branch):
            patch((t) => t.copyWith(branch: branch));
          case AssistantResultEvent(:final result):
            final rag = result.branch == 'account' || result.branch == 'info';
            patch(
              (t) => t.copyWith(
                result: result,
                branch: result.branch,
                // Nhánh tài liệu: chữ đến sau qua delta; nhánh request: form là phần chính.
                text: rag || result.branch == 'request'
                    ? t.text
                    : (result.answer ?? t.text),
                error: result.branch == 'error'
                    ? AssistantTurnError.failed
                    : null,
              ),
            );
          case AssistantDeltaEvent(:final text):
            patch((t) => t.copyWith(text: t.text + text));
          case AssistantDoneEvent(:final branch, :final historyText):
            patch(
              (t) => t.copyWith(
                streaming: false,
                branch: branch,
                history: historyText ?? t.text,
              ),
            );
          case AssistantErrorEvent():
            patch((t) => t.copyWith(error: AssistantTurnError.failed));
        }
      }
    } catch (error) {
      if (!token.isCancelled) {
        patch(
          (t) => t.copyWith(
            error: error is AssistantRateLimitException
                ? AssistantTurnError.rateLimited
                : AssistantTurnError.failed,
          ),
        );
      }
    } finally {
      if (mine()) {
        final last = state.turns.lastOrNull;
        if (token.isCancelled && last is AssistantReplyTurn && last.isEmpty) {
          // Bấm Dừng trước khi có gì để hiện: bỏ lượt trống (câu hỏi vẫn còn, gửi lại được).
          emit(
            state.copyWith(
              turns: state.turns.sublist(0, state.turns.length - 1),
            ),
          );
        } else {
          _patchLast((t) => t.copyWith(streaming: false));
        }
        emit(state.copyWith(busy: false));
        _track();
        await _history.save(state.turns);
      }
    }
  }

  void _track() {
    final last = state.turns.lastOrNull;
    if (last is! AssistantReplyTurn) return;
    AppAnalytics.capture(AnalyticsEvents.assistantReplyReceived, {
      'branch': last.result?.branch ?? last.branch,
      'has_cards': last.result?.hasCards ?? false,
      'error': last.error?.name,
    });
  }

  void _patchLast(AssistantReplyTurn Function(AssistantReplyTurn) fn) {
    final turns = state.turns;
    final last = turns.lastOrNull;
    if (last is! AssistantReplyTurn) return; // vừa bấm "New chat"
    emit(
      state.copyWith(turns: [...turns.sublist(0, turns.length - 1), fn(last)]),
    );
  }

  /// Nút Dừng.
  void stop() => _token?.cancel();

  /// Gửi lại câu hỏi của lượt lỗi cuối.
  void retry() {
    final turns = state.turns;
    final at = turns.lastIndexWhere((t) => t is AssistantUserTurn);
    if (at < 0 || state.busy) return;
    ask(
      (turns[at] as AssistantUserTurn).content,
      base: turns.sublist(0, at),
      source: 'retry',
    );
  }

  /// Không ai khớp → form Post Request ngay dưới câu trả lời, điền từ điều kiện AI đã hiểu
  /// (không gọi AI lại).
  void postRequest(int index) {
    final turns = [...state.turns];
    final turn = turns.elementAtOrNull(index);
    if (turn is! AssistantReplyTurn) return;
    final said = turns
        .take(index)
        .whereType<AssistantUserTurn>()
        .lastOrNull
        ?.content;
    turns[index] = turn.copyWith(
      requestDraft: AssistantMapper.understandingToDraft(
        turn.result?.understanding,
        said ?? '',
      ),
    );
    emit(state.copyWith(turns: turns));
    if (!state.busy) _history.save(turns);
  }

  /// "New chat": huỷ lượt đang chạy, xoá hội thoại khỏi máy.
  Future<void> startNew() async {
    _token?.cancel();
    _token = null;
    AppAnalytics.capture(AnalyticsEvents.assistantNewChat, {
      'turns': state.turns.whereType<AssistantUserTurn>().length,
    });
    emit(const AssistantChatState());
    await _history.clear();
  }

  @override
  Future<void> close() {
    // Rời màn → huỷ lượt đang chạy (như web).
    _token?.cancel();
    return super.close();
  }
}
