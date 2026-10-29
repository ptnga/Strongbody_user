import 'package:equatable/equatable.dart';

/// Loại payload trên chat-server (`message.type`). Ngoài phạm vi app → [other].
enum ChatMessageType {
  text,
  voice,
  offer,
  image,
  file,
  other;

  static ChatMessageType fromApi(String? value) => switch (value) {
    'text' || null || '' => text,
    'voice' => voice,
    'offer' => offer,
    'image' => image,
    'file' => file,
    _ => other,
  };
}

/// `message.voice` — file ghi âm do server publish sau `POST /user/chat-server/voice`.
class ChatVoice extends Equatable {
  /// URL https (hoặc đường dẫn file trên máy khi đang gửi).
  final String url;
  final String? gcsPath;

  /// Ngôn ngữ server nhận ra trong bản ghi (vd `vi`).
  final String? sourceLang;

  /// Bản chép lời server tạo ra.
  final String? transcript;
  final Duration? duration;

  const ChatVoice({
    required this.url,
    this.gcsPath,
    this.sourceLang,
    this.transcript,
    this.duration,
  });

  @override
  List<Object?> get props => [url, gcsPath, sourceLang, transcript, duration];
}

/// Offer gửi trong chat (`type: offer`).
class ChatOfferEntity extends Equatable {
  final int id;
  final String title;
  final String description;
  final double? price;

  /// pending | accepted | rejected | completed | cancelled
  final String status;

  /// paid | … (rỗng = chưa trả)
  final String paymentStatus;
  final String? orderNo;
  final DateTime? createdAt;
  final int? sellerId;

  /// Offer cho một request của mình → "Details" mở trang Offers của request đó.
  final int? requestId;

  /// Lịch + nơi lấy từ request ("Sat 24 Oct, 09:00 · at your home").
  final DateTime? scheduledAt;
  final String? deliveryType;

  const ChatOfferEntity({
    required this.id,
    this.title = '',
    this.description = '',
    this.price,
    this.status = 'pending',
    this.paymentStatus = '',
    this.orderNo,
    this.createdAt,
    this.sellerId,
    this.requestId,
    this.scheduledAt,
    this.deliveryType,
  });

  bool get isPaid => paymentStatus == 'paid';

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    price,
    status,
    paymentStatus,
    orderNo,
    createdAt,
    sellerId,
    requestId,
    scheduledAt,
    deliveryType,
  ];
}

/// Một tin trong hội thoại. [id] = timetoken (chuỗi 17 chữ số, đơn vị 100 ns).
class ChatMessageEntity extends Equatable {
  final String id;
  final int senderId;
  final ChatMessageType type;

  /// `content` (text) — bản gốc, chưa dịch.
  final String text;
  final ChatVoice? voice;
  final ChatOfferEntity? offer;
  final String? fileName;
  final DateTime createdAt;

  /// Đang gửi (optimistic), chưa thấy echo từ server.
  final bool isPending;

  /// Chỉ có trên máy: offer của provider cho request của mình, chèn vào chat
  /// (không có trên chat-server) — không đánh dấu đã đọc / không dịch.
  final bool isLocal;

  const ChatMessageEntity({
    required this.id,
    required this.senderId,
    required this.type,
    required this.createdAt,
    this.text = '',
    this.voice,
    this.offer,
    this.fileName,
    this.isPending = false,
    this.isLocal = false,
  });

  ChatMessageEntity copyWith({
    String? id,
    bool? isPending,
    ChatVoice? voice,
    ChatOfferEntity? offer,
  }) {
    return ChatMessageEntity(
      id: id ?? this.id,
      senderId: senderId,
      type: type,
      createdAt: createdAt,
      text: text,
      voice: voice ?? this.voice,
      offer: offer ?? this.offer,
      fileName: fileName,
      isPending: isPending ?? this.isPending,
      isLocal: isLocal,
    );
  }

  @override
  List<Object?> get props => [
    id,
    senderId,
    type,
    text,
    voice,
    offer,
    fileName,
    createdAt,
    isPending,
    isLocal,
  ];
}

/// Bản dịch của một tin: text (`{ch}_translation`, `/messages/translated`) hoặc audio
/// (`{ch}_voice_translation`, `/voice-translation/batch`).
class ChatTranslation extends Equatable {
  final String messageId;
  final String? text;
  final String? audioUrl;
  final String? sourceLang;
  final String? targetLang;

  const ChatTranslation({
    required this.messageId,
    this.text,
    this.audioUrl,
    this.sourceLang,
    this.targetLang,
  });

  ChatTranslation merge(ChatTranslation other) => ChatTranslation(
    messageId: messageId,
    text: other.text ?? text,
    audioUrl: other.audioUrl ?? audioUrl,
    sourceLang: other.sourceLang ?? sourceLang,
    targetLang: other.targetLang ?? targetLang,
  );

  @override
  List<Object?> get props => [
    messageId,
    text,
    audioUrl,
    sourceLang,
    targetLang,
  ];
}
