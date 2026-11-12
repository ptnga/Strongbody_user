import 'package:dio/dio.dart';

import '../entities/assistant_entities.dart';
import '../repositories/assistant_repository.dart';

class AssistantChatParams {
  final List<AssistantTurn> history;
  final String language;

  /// Điều kiện của lần tìm gần nhất: khách nói "rẻ hơn" thì BE sửa tiếp trên đó.
  final Map<String, dynamic>? previous;
  final String? previousText;

  /// Điều kiện đã gộp sẵn → BE bỏ qua LLM, tìm thẳng.
  final Map<String, dynamic>? understanding;
  final CancelToken? cancelToken;

  const AssistantChatParams({
    required this.history,
    required this.language,
    this.previous,
    this.previousText,
    this.understanding,
    this.cancelToken,
  });
}

/// Một lượt chat dạng stream (không bọc `Either`: lỗi đi trong stream).
class StreamAssistantChatUseCase {
  final AssistantRepository _repository;

  StreamAssistantChatUseCase(this._repository);

  Stream<AssistantEvent> call(AssistantChatParams params) => _repository.chat(
    history: params.history,
    language: params.language,
    previous: params.previous,
    previousText: params.previousText,
    understanding: params.understanding,
    cancelToken: params.cancelToken,
  );
}

/// Hội thoại lưu trên máy (web localStorage `sb_search_assistant_chat_v1`).
class AssistantHistoryUseCase {
  final AssistantRepository _repository;

  AssistantHistoryUseCase(this._repository);

  List<AssistantTurn> load() => _repository.loadTurns();

  Future<void> save(List<AssistantTurn> turns) => _repository.saveTurns(turns);

  Future<void> clear() => _repository.clearTurns();
}
