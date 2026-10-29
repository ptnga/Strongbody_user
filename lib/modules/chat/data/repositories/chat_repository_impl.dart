import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/network/exception.dart';

import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/chat_session_entity.dart';
import '../../domain/entities/chat_timetoken.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/repositories/chat_connection.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/remote/chat_remote_datasource.dart';
import '../mappers/chat_mapper.dart';
import '../services/chat_server_connection.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remote;
  final GlobalStorage _storage;

  ChatRepositoryImpl(this._remote, this._storage);

  int get _me => _storage.userId ?? 0;

  Future<Either<Failure, T>> _guard<T>(
    Future<T> Function() run,
    String fallback,
  ) async {
    try {
      return Right(await run());
    } catch (e) {
      return Left(_toFailure(e, fallback));
    }
  }

  Failure _toFailure(Object e, String fallback) {
    if (e is ChatApiException) {
      return e.code == 401 || e.code == 403
          ? UnauthorizedFailure(e.message, statusCode: e.code)
          : ServerFailure(e.message, statusCode: e.code);
    }
    if (e is DioException) {
      final data = e.response?.data;
      final message = data is Map ? data['message']?.toString() : null;
      final status = e.response?.statusCode;
      return status == 401 || status == 403
          ? UnauthorizedFailure(message ?? fallback, statusCode: status)
          : ServerFailure(message ?? fallback, statusCode: status);
    }
    if (e is NetworkException || e is SocketException) {
      return NetworkFailure(e.toString());
    }
    return Failure(e.toString());
  }

  @override
  Future<Either<Failure, ({List<ConversationEntity> items, bool hasMore})>>
  getConversations({required int page, int limit = 10}) => _guard(() async {
    final raw = await _remote.getConversations(page, limit);
    final items = raw.map(ChatMapper.conversation).nonNulls.toList();
    return (items: items, hasMore: raw.length >= limit);
  }, 'Cannot load conversations');

  @override
  Future<Either<Failure, int>> getUnreadTotal() => _guard(() async {
    final data = await _remote.getUnreadCounts();
    final total = data['total_unread_count'];
    return total is num ? total.toInt() : 0;
  }, 'Cannot load unread count');

  @override
  Future<Either<Failure, List<ChatUserEntity>>> searchUsers(String query) =>
      _guard(
        () async => ChatMapper.users(
          await _remote.searchUsers(query),
        ).where((u) => u.id != _me).toList(),
        'Search failed',
      );

  @override
  Future<Either<Failure, ChatSession>> openSession(int partnerId) =>
      _guard(() async {
        final data = await _remote.createChannel(partnerId);
        final session = ChatMapper.session(
          data,
          myUserId: _me,
          fallbackPartner: ChatPartner(id: partnerId, name: ''),
        );
        if (session == null) throw Exception('Cannot open chat');
        return session;
      }, 'Cannot open chat');

  @override
  Future<Either<Failure, ChatSession>> refreshSession(
    ChatSession session,
  ) async {
    try {
      final data = await _remote.refreshToken(session.channelId);
      final token = data['token']?.toString();
      if (token != null && token.isNotEmpty) {
        return Right(session.withToken(token));
      }
    } catch (_) {
      // Như Multime: refresh hỏng → tạo lại kênh.
    }
    return openSession(session.partner.id);
  }

  @override
  ChatConnection connect(ChatSession session) => ChatServerConnection(session);

  @override
  Future<Either<Failure, ChatUpdatesConnection>> connectUpdates() =>
      _guard(() async {
        final data = await _remote.personalUpdateToken(_me);
        final token = data['token']?.toString();
        if (token == null || token.isEmpty) throw Exception('No token');
        return ChatServerUpdatesConnection(
          userId: _me,
          token: token,
          channelId: data['channel_id']?.toString(),
        );
      }, 'Cannot connect');

  @override
  Future<Either<Failure, ChatTranslationSettings?>> getTranslationSettings(
    String channelId,
  ) => _guard(() async {
    final data = await _remote.getTranslationSettings(channelId);
    return data == null
        ? null
        : ChatMapper.settings(data, fallbackLanguage: _storage.locale);
  }, 'Cannot load translation settings');

  @override
  Future<Either<Failure, ChatTranslationSettings>> saveTranslationSettings(
    String channelId,
    ChatTranslationSettings settings,
  ) => _guard(() async {
    if (settings.autoTranslate) await _remote.grantTranslationConsent();
    final data = await _remote.saveTranslationSettings(channelId, {
      'target_language': settings.targetLanguage,
      'auto_translate': settings.autoTranslate,
    });
    return data.isEmpty
        ? settings
        : ChatMapper.settings(data, fallbackLanguage: settings.targetLanguage);
  }, 'Cannot update translation');

  @override
  Future<Either<Failure, List<ChatTranslation>>> getTextTranslations(
    String channelId,
    List<String> messageIds,
  ) => _guard(() async {
    if (messageIds.isEmpty) return const <ChatTranslation>[];
    final data = await _remote.getTextTranslations(channelId, messageIds);
    final list = data['messages'];
    return list is List
        ? list
              .whereType<Map>()
              .map((e) => ChatMapper.textTranslation(Map.from(e)))
              .nonNulls
              .toList()
        : const <ChatTranslation>[];
  }, 'Cannot load translations');

  @override
  Future<Either<Failure, List<ChatTranslation>>> getVoiceTranslations(
    List<String> messageIds,
  ) => _guard(() async {
    if (messageIds.isEmpty) return const <ChatTranslation>[];
    final data = await _remote.getVoiceTranslations(messageIds);
    final list = data['translations'];
    return list is List
        ? list
              .whereType<Map>()
              .map((e) => ChatMapper.voiceTranslation(Map.from(e)))
              .nonNulls
              .toList()
        : const <ChatTranslation>[];
  }, 'Cannot load translations');

  @override
  Future<Either<Failure, ChatTranslation>> translateText({
    required String channelId,
    required String messageId,
    required String text,
    required String targetLanguage,
  }) => _guard(() async {
    final data = await _remote.translateText(channelId, messageId, {
      'text': text,
      'target_language': targetLanguage,
    });
    final translation = ChatMapper.textTranslation({
      'message_id': messageId,
      ...data,
    });
    if (translation == null) throw Exception('Empty translation');
    return translation;
  }, 'Cannot translate');

  @override
  Future<Either<Failure, ChatMessageEntity>> sendVoice({
    required ChatSession session,
    required String filePath,
    required Duration duration,
  }) => _guard(() async {
    final seconds = duration.inSeconds.clamp(1, 600);
    final data = await _remote.sendVoice(
      channelId: session.channelId,
      senderId: session.myUserId,
      filePath: filePath,
      durationSeconds: seconds,
    );
    final timetoken = data['timetoken']?.toString();
    final url = data['audio_url']?.toString();
    if (timetoken == null || url == null || url.isEmpty) {
      throw Exception(data['message']?.toString() ?? 'Voice upload failed');
    }
    return ChatMessageEntity(
      id: timetoken,
      senderId: session.myUserId,
      type: ChatMessageType.voice,
      createdAt: ChatTimetoken.toDateTime(timetoken),
      voice: ChatVoice(
        url: url,
        gcsPath: data['gcs_path']?.toString(),
        duration: Duration(seconds: seconds),
      ),
    );
  }, 'Cannot send voice message');

  @override
  Future<Either<Failure, ChatReadReceipt>> markRead(
    String channelId,
    String timetoken,
  ) => _guard(() async {
    final receipt = ChatMapper.readReceipt(
      await _remote.markRead(channelId, timetoken),
      myUserId: _me,
    );
    if (receipt == null) throw Exception('No receipt');
    return receipt;
  }, 'Cannot mark read');

  @override
  Future<Either<Failure, List<ChatOfferEntity>>> getConversationOffers(
    String channelId,
  ) => _guard(
    () async => ChatMapper.conversationOffers(
      await _remote.getConversationOffers(channelId),
    ),
    'Cannot load offers',
  );

  @override
  Future<Either<Failure, List<ChatOfferEntity>>> getPartnerRequestOffers(
    int partnerId,
  ) => _guard(
    () async => ChatMapper.requestOffers(
      await _remote.getRequestOffers(),
      sellerId: partnerId,
    ),
    'Cannot load offers',
  );
}
