import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/chat_message_entity.dart';
import '../entities/chat_session_entity.dart';
import '../entities/conversation_entity.dart';
import '../repositories/chat_connection.dart';
import '../repositories/chat_repository.dart';

typedef ConversationPage = ({List<ConversationEntity> items, bool hasMore});

/// Param = số trang (bắt đầu 1, 10 dòng/trang như Multime).
class GetConversationsUseCase implements UseCase<ConversationPage, int> {
  final ChatRepository _repository;
  GetConversationsUseCase(this._repository);

  @override
  Future<Either<Failure, ConversationPage>> call(int page) =>
      _repository.getConversations(page: page);
}

class GetChatUnreadTotalUseCase implements UseCase<int, NoParams> {
  final ChatRepository _repository;
  GetChatUnreadTotalUseCase(this._repository);

  @override
  Future<Either<Failure, int>> call(NoParams params) =>
      _repository.getUnreadTotal();
}

class SearchChatUsersUseCase implements UseCase<List<ChatUserEntity>, String> {
  final ChatRepository _repository;
  SearchChatUsersUseCase(this._repository);

  @override
  Future<Either<Failure, List<ChatUserEntity>>> call(String query) =>
      _repository.searchUsers(query);
}

class ConnectChatUpdatesUseCase
    implements UseCase<ChatUpdatesConnection, NoParams> {
  final ChatRepository _repository;
  ConnectChatUpdatesUseCase(this._repository);

  @override
  Future<Either<Failure, ChatUpdatesConnection>> call(NoParams params) =>
      _repository.connectUpdates();
}

/// Param = user id của provider.
class OpenChatSessionUseCase implements UseCase<ChatSession, int> {
  final ChatRepository _repository;
  OpenChatSessionUseCase(this._repository);

  @override
  Future<Either<Failure, ChatSession>> call(int partnerId) =>
      _repository.openSession(partnerId);
}

class RefreshChatSessionUseCase implements UseCase<ChatSession, ChatSession> {
  final ChatRepository _repository;
  RefreshChatSessionUseCase(this._repository);

  @override
  Future<Either<Failure, ChatSession>> call(ChatSession session) =>
      _repository.refreshSession(session);
}

/// Mở WS của kênh (đồng bộ — chỉ tạo client).
class ConnectChatUseCase {
  final ChatRepository _repository;
  ConnectChatUseCase(this._repository);

  ChatConnection call(ChatSession session) => _repository.connect(session);
}

/// Param = channel id. Kết quả null = chưa có cài đặt (tắt).
class GetTranslationSettingsUseCase
    implements UseCase<ChatTranslationSettings?, String> {
  final ChatRepository _repository;
  GetTranslationSettingsUseCase(this._repository);

  @override
  Future<Either<Failure, ChatTranslationSettings?>> call(String channelId) =>
      _repository.getTranslationSettings(channelId);
}

class SaveTranslationSettingsUseCase
    implements
        UseCase<
          ChatTranslationSettings,
          ({String channelId, ChatTranslationSettings settings})
        > {
  final ChatRepository _repository;
  SaveTranslationSettingsUseCase(this._repository);

  @override
  Future<Either<Failure, ChatTranslationSettings>> call(
    ({String channelId, ChatTranslationSettings settings}) params,
  ) => _repository.saveTranslationSettings(params.channelId, params.settings);
}

/// Bản dịch đã có: text (tin text của partner) + audio (tin voice của partner).
class GetChatTranslationsUseCase
    implements
        UseCase<
          List<ChatTranslation>,
          ({String channelId, List<String> textIds, List<String> voiceIds})
        > {
  final ChatRepository _repository;
  GetChatTranslationsUseCase(this._repository);

  @override
  Future<Either<Failure, List<ChatTranslation>>> call(
    ({String channelId, List<String> textIds, List<String> voiceIds}) params,
  ) async {
    final results = await Future.wait([
      _repository.getTextTranslations(params.channelId, params.textIds),
      _repository.getVoiceTranslations(params.voiceIds),
    ]);
    // Một nguồn lỗi vẫn giữ nguồn còn lại.
    return Right([
      for (final result in results) ...result.getOrElse((_) => const []),
    ]);
  }
}

class TranslateChatTextUseCase
    implements
        UseCase<
          ChatTranslation,
          ({
            String channelId,
            String messageId,
            String text,
            String targetLanguage,
          })
        > {
  final ChatRepository _repository;
  TranslateChatTextUseCase(this._repository);

  @override
  Future<Either<Failure, ChatTranslation>> call(
    ({String channelId, String messageId, String text, String targetLanguage})
    params,
  ) => _repository.translateText(
    channelId: params.channelId,
    messageId: params.messageId,
    text: params.text,
    targetLanguage: params.targetLanguage,
  );
}

class SendChatVoiceUseCase
    implements
        UseCase<
          ChatMessageEntity,
          ({ChatSession session, String filePath, Duration duration})
        > {
  final ChatRepository _repository;
  SendChatVoiceUseCase(this._repository);

  @override
  Future<Either<Failure, ChatMessageEntity>> call(
    ({ChatSession session, String filePath, Duration duration}) params,
  ) => _repository.sendVoice(
    session: params.session,
    filePath: params.filePath,
    duration: params.duration,
  );
}

class MarkChatReadUseCase
    implements
        UseCase<ChatReadReceipt, ({String channelId, String timetoken})> {
  final ChatRepository _repository;
  MarkChatReadUseCase(this._repository);

  @override
  Future<Either<Failure, ChatReadReceipt>> call(
    ({String channelId, String timetoken}) params,
  ) => _repository.markRead(params.channelId, params.timetoken);
}

/// Offer của provider: trong hội thoại (`/user/offer/conversation`) + cho request của mình,
/// gộp theo id, mới nhất trước.
class GetChatOffersUseCase
    implements
        UseCase<List<ChatOfferEntity>, ({String channelId, int partnerId})> {
  final ChatRepository _repository;
  GetChatOffersUseCase(this._repository);

  @override
  Future<Either<Failure, List<ChatOfferEntity>>> call(
    ({String channelId, int partnerId}) params,
  ) async {
    final results = await Future.wait([
      _repository.getConversationOffers(params.channelId),
      _repository.getPartnerRequestOffers(params.partnerId),
    ]);
    final byId = <int, ChatOfferEntity>{};
    for (final result in results) {
      for (final offer in result.getOrElse((_) => const [])) {
        // Bản từ request có requestId / lịch → ưu tiên.
        final known = byId[offer.id];
        byId[offer.id] = known == null || offer.requestId != null
            ? offer
            : known;
      }
    }
    final offers = byId.values.toList()
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
    return Right(offers);
  }
}
