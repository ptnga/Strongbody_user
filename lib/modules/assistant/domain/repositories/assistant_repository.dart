import 'package:dio/dio.dart';

import '../entities/assistant_entities.dart';

abstract class AssistantRepository {
  /// Một lượt chat (web `streamAssistantChat`). Lỗi ném ra trong stream:
  /// `AssistantRateLimitException` khi vượt lượt, còn lại là lỗi chung.
  Stream<AssistantEvent> chat({
    required List<AssistantTurn> history,
    required String language,
    String? timezone,
    Map<String, dynamic>? previous,
    String? previousText,

    /// Điều kiện đã gộp sẵn (bỏ qua LLM, tìm thẳng) — web trang matches lượt 2.
    Map<String, dynamic>? understanding,
    CancelToken? cancelToken,
  });

  List<AssistantTurn> loadTurns();

  Future<void> saveTurns(List<AssistantTurn> turns);

  Future<void> clearTurns();
}
