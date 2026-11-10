import 'dart:async';

import 'package:strongbody_chat_client/strongbody_chat_client.dart';

import 'package:strongbody_buyer/core/config/environment.dart';
import 'package:strongbody_buyer/core/utils/app_logger.dart';

import '../../domain/entities/chat_session_entity.dart';
import '../../domain/repositories/chat_connection.dart';
import '../api_config/chat_api_config.dart';
import '../mappers/chat_mapper.dart';

ChatPubNub _client(String uuid, String token) => ChatPubNub(
  endpoint: AppConfig.chatServerUrl,
  tenant: AppConfig.chatServerTenant,
  uuid: uuid,
  token: token,
);

Map<String, dynamic> _asMap(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

/// Một ChatPubNub với JWT của kênh — dùng cho `{ch}`, `{ch}_translation`,
/// `{ch}_voice_translation` (như Multime `ChatServerChannelService`).
class ChatServerConnection implements ChatConnection {
  final ChatSession session;
  final ChatPubNub _pubnub;
  final _events = StreamController<ChatRealtimeEvent>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _translations = false;

  ChatServerConnection(this.session)
    : _pubnub = _client('${session.myUserId}', session.token) {
    _subscriptions
      ..add(_pubnub.messages.listen(_onMessage))
      ..add(
        _pubnub.messageEdited.listen((e) {
          final message = ChatMapper.message(
            timetoken: e.timetoken,
            publisher: e.publisher,
            payload: e.message,
            myUserId: session.myUserId,
          );
          if (message != null) _events.add(ChatMessageEdited(message));
        }),
      )
      ..add(
        _pubnub.status.listen((e) {
          if (e.category == StatusCategory.accessDenied) {
            _events.add(const ChatAccessDenied());
          } else if (e.category == StatusCategory.reconnected) {
            _events.add(const ChatReconnected());
          }
        }),
      );
  }

  String get _textChannel =>
      ChatApiConfig.textTranslationChannel(session.channelId);
  String get _voiceChannel =>
      ChatApiConfig.voiceTranslationChannel(session.channelId);

  void _onMessage(MessageEvent e) {
    if (e.channel == _textChannel || e.channel == _voiceChannel) {
      final json = _asMap(e.message);
      final isVoice = e.channel == _voiceChannel;
      // Web `shouldApplyText/VoiceTranslation`: bỏ sự kiện loại khác trên kênh dịch.
      final type = json['type'];
      if (type != null &&
          type != (isVoice ? 'voice_translation' : 'text_translation')) {
        return;
      }
      // Sự kiện mới có `recipient_user_id` → chỉ áp bản dịch dành cho mình.
      final recipient = json['recipient_user_id'];
      if (recipient is num &&
          recipient > 0 &&
          recipient.toInt() != session.myUserId) {
        return;
      }
      final translation = isVoice
          ? ChatMapper.voiceTranslation(json)
          : ChatMapper.textTranslation(json);
      if (translation != null) {
        _events.add(
          ChatTranslationArrived(
            translation,
            // Sự kiện cũ (không có người nhận) → bloc lọc theo `target_lang`.
            legacy: !(recipient is num && recipient > 0),
          ),
        );
      }
      return;
    }
    if (e.channel != session.channelId) return;
    final message = ChatMapper.message(
      timetoken: e.timetoken,
      publisher: e.publisher,
      payload: e.message,
      myUserId: session.myUserId,
    );
    if (message != null) _events.add(ChatMessageArrived(message));
  }

  @override
  Stream<ChatRealtimeEvent> get events => _events.stream;

  /// Web `SettingContext`: kênh bản dịch giọng nói luôn nghe (không phụ thuộc
  /// auto-translate); kênh bản dịch chữ chỉ khi bật auto-translate.
  @override
  void subscribe({required bool withTranslations}) {
    _pubnub.subscribe(channels: {session.channelId, _voiceChannel});
    if (withTranslations && !_translations) {
      _pubnub.subscribe(channels: {_textChannel});
    } else if (!withTranslations && _translations) {
      _pubnub.unsubscribe(channels: {_textChannel});
    }
    _translations = withTranslations;
  }

  @override
  Future<ChatHistoryPage> history({String? cursor, int count = 20}) async {
    final result = await _pubnub.fetchMessages(
      channel: session.channelId,
      count: count,
      start: cursor,
    );
    final messages =
        result.messages
            .map(
              (m) => ChatMapper.message(
                timetoken: m.timetoken,
                publisher: m.publisher,
                payload: m.message,
                myUserId: session.myUserId,
              ),
            )
            .nonNulls
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id));
    return ChatHistoryPage(messages: messages, nextCursor: result.more?.start);
  }

  @override
  Future<String> sendText(String text, {String? senderName}) async {
    final result = await _pubnub.publish(
      channel: session.channelId,
      message: {
        'type': 'text',
        'content': text,
        'uuid': session.myUserId,
        'senderName': ?senderName,
      },
    );
    return result.timetoken;
  }

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _events.close();
    try {
      await _pubnub.disconnect();
    } catch (e) {
      AppLogger.w('Chat disconnect failed', e);
    }
  }
}

/// `user_{me}_updates` — JWT riêng từ `personal-update-token`.
class ChatServerUpdatesConnection implements ChatUpdatesConnection {
  final ChatPubNub _pubnub;
  final _updates = StreamController<ConversationUpdate>.broadcast();
  StreamSubscription<MessageEvent>? _subscription;
  StreamSubscription<StatusEvent>? _statusSubscription;

  ChatServerUpdatesConnection({
    required int userId,
    required String token,
    String? channelId,
  }) : _pubnub = _client('$userId', token) {
    _subscription = _pubnub.messages.listen((e) {
      final json = _asMap(e.message);
      final data = _asMap(json['data']);
      switch (json['type']) {
        case 'channel_list_update':
          final conversation = ChatMapper.conversationUpdate(
            data,
            myUserId: userId,
          );
          if (conversation != null) {
            _updates.add(ConversationChanged(conversation));
          }
        case 'global_unread_update':
          final total = data['total_unread_count'];
          _updates.add(UnreadChanged(total is num ? total.toInt() : null));
      }
    });
    _statusSubscription = _pubnub.status.listen((e) {
      if (e.category == StatusCategory.accessDenied && !_updates.isClosed) {
        _updates.add(const UpdatesAccessDenied());
      }
    });
    _pubnub.subscribe(
      channels: {channelId ?? ChatApiConfig.updatesChannel(userId)},
    );
  }

  @override
  Stream<ConversationUpdate> get updates => _updates.stream;

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _statusSubscription?.cancel();
    await _updates.close();
    try {
      await _pubnub.disconnect();
    } catch (e) {
      AppLogger.w('Chat updates disconnect failed', e);
    }
  }
}
