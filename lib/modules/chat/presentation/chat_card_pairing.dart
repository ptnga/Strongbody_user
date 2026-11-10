import '../domain/entities/chat_message_entity.dart';

/// Web `pairCardWithText`: inquiry / chia sẻ item gửi 2 tin liền nhau (thẻ rồi lời nhắn).
/// Tin chữ đứng NGAY sau thẻ của cùng người gửi (trong 2 phút) hiện gộp một bong bóng;
/// thẻ được ẩn khỏi danh sách.
class ChatCardPairing {
  /// Tin chữ → thẻ đi kèm.
  final Map<String, ChatMessageEntity> attached;

  /// Thẻ đã gộp (không vẽ riêng).
  final Set<String> hidden;

  const ChatCardPairing._(this.attached, this.hidden);

  /// 2 phút, đơn vị timetoken (100 ns).
  static final BigInt _window = BigInt.from(120 * 10000000);

  static bool _isCard(ChatMessageEntity m) =>
      !m.isLocal && (m.card != null || (m.type.isCard && m.offer != null));

  /// [newestFirst] như [ChatState.messages] (index 0 = tin mới nhất).
  factory ChatCardPairing.of(List<ChatMessageEntity> newestFirst) {
    final attached = <String, ChatMessageEntity>{};
    final hidden = <String>{};
    for (var i = 0; i + 1 < newestFirst.length; i++) {
      final text = newestFirst[i];
      final card = newestFirst[i + 1];
      if (text.type != ChatMessageType.text || text.isLocal) continue;
      if (!_isCard(card) || card.senderId != text.senderId) continue;
      final a = BigInt.tryParse(card.id);
      final b = BigInt.tryParse(text.id);
      if (a == null || b == null) continue;
      final gap = b - a;
      if (gap.isNegative || gap > _window) continue;
      attached[text.id] = card;
      hidden.add(card.id);
    }
    return ChatCardPairing._(attached, hidden);
  }
}
