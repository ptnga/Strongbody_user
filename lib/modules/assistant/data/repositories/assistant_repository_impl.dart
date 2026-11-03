import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';

import '../../domain/entities/assistant_entities.dart';
import '../../domain/repositories/assistant_repository.dart';
import '../datasources/remote/assistant_remote_datasource.dart';
import '../mappers/assistant_mapper.dart';

class AssistantRepositoryImpl implements AssistantRepository {
  final AssistantRemoteDataSource _remote;
  final UserPreferences _preferences;

  AssistantRepositoryImpl(this._remote, this._preferences);

  /// Web giữ 30 lượt gần nhất (`MAX_STORED_TURNS`).
  static const maxStoredTurns = 30;

  @override
  Stream<AssistantEvent> chat({
    required List<AssistantTurn> history,
    required String language,
    String? timezone,
    Map<String, dynamic>? previous,
    String? previousText,
    CancelToken? cancelToken,
  }) => _remote
      .streamChat({
        'messages': AssistantMapper.historyMessages(history),
        'language': language,
        'timezone': ?timezone,
        'previous': ?previous,
        if (previousText != null && previousText.isNotEmpty)
          'previous_text': previousText,
      }, cancelToken: cancelToken)
      .map(AssistantMapper.event)
      .where((e) => e != null)
      .cast<AssistantEvent>();

  @override
  List<AssistantTurn> loadTurns() {
    try {
      final raw = jsonDecode(_preferences.assistantChat ?? '[]');
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((j) => AssistantMapper.turn(Map<String, dynamic>.from(j)))
          .nonNulls
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveTurns(List<AssistantTurn> turns) {
    final kept = turns.length > maxStoredTurns
        ? turns.sublist(turns.length - maxStoredTurns)
        : turns;
    return _preferences.setAssistantChat(
      jsonEncode(kept.map(AssistantMapper.turnJson).toList()),
    );
  }

  @override
  Future<void> clearTurns() => _preferences.setAssistantChat(null);
}
