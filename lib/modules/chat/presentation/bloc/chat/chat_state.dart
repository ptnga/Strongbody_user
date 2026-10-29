part of 'chat_bloc.dart';

enum ChatStatus { connecting, ready, failure, signedOut }

/// Thông báo một lần (toast) — UI đọc rồi bỏ qua theo [ChatState.noticeId].
enum ChatNotice {
  sendFailed,
  voiceFailed,
  micDenied,
  voiceTooShort,
  translateFailed,
}

class ChatState extends Equatable {
  final ChatStatus status;
  final ChatSession? session;

  /// Mới nhất trước (index 0 = tin cuối) — như Multime, hợp `ListView(reverse: true)`.
  final List<ChatMessageEntity> messages;
  final String? historyCursor;
  final bool loadingOlder;
  final Map<String, ChatTranslation> translations;
  final Set<String> showOriginal;
  final ChatTranslationSettings? settings;
  final bool savingSettings;
  final ChatReadReceipt? readReceipt;

  /// Offer mới nhất provider gửi trong hội thoại — dải trạng thái ở đầu chat.
  final ChatOfferEntity? offer;
  final bool recording;
  final Duration recordElapsed;
  final ChatNotice? notice;
  final int noticeId;

  const ChatState({
    this.status = ChatStatus.connecting,
    this.session,
    this.messages = const [],
    this.historyCursor,
    this.loadingOlder = false,
    this.translations = const {},
    this.showOriginal = const {},
    this.settings,
    this.savingSettings = false,
    this.readReceipt,
    this.offer,
    this.recording = false,
    this.recordElapsed = Duration.zero,
    this.notice,
    this.noticeId = 0,
  });

  bool get autoTranslate => settings?.autoTranslate ?? false;
  bool get hasOlder => historyCursor != null;

  /// Ngôn ngữ partner nói — lấy từ tin gần nhất có `source_lang`.
  String? get partnerLanguage {
    final partnerId = session?.partner.id;
    for (final m in messages) {
      if (m.senderId != partnerId) continue;
      final lang = m.voice?.sourceLang ?? translations[m.id]?.sourceLang;
      if (lang != null && lang.isNotEmpty) return lang;
    }
    return null;
  }

  /// Tin của mình mà partner đã đọc tới (hiện "Read").
  String? get readMessageId {
    final receipt = readReceipt;
    final me = session?.myUserId;
    if (receipt == null || !receipt.readByPartner || me == null) return null;
    // Receipt trỏ vào tin mới nhất lúc đánh dấu; "Read" gắn vào tin của mình mới nhất ≤ mốc đó.
    for (final m in messages) {
      if (m.senderId == me &&
          !m.isPending &&
          m.id.compareTo(receipt.timetoken) <= 0) {
        return m.id;
      }
    }
    return null;
  }

  ChatState copyWith({
    ChatStatus? status,
    ChatSession? session,
    List<ChatMessageEntity>? messages,
    String? historyCursor,
    bool clearCursor = false,
    bool? loadingOlder,
    Map<String, ChatTranslation>? translations,
    Set<String>? showOriginal,
    ChatTranslationSettings? settings,
    bool? savingSettings,
    ChatReadReceipt? readReceipt,
    ChatOfferEntity? offer,
    bool? recording,
    Duration? recordElapsed,
    ChatNotice? notice,
  }) {
    return ChatState(
      status: status ?? this.status,
      session: session ?? this.session,
      messages: messages ?? this.messages,
      historyCursor: clearCursor ? null : (historyCursor ?? this.historyCursor),
      loadingOlder: loadingOlder ?? this.loadingOlder,
      translations: translations ?? this.translations,
      showOriginal: showOriginal ?? this.showOriginal,
      settings: settings ?? this.settings,
      savingSettings: savingSettings ?? this.savingSettings,
      readReceipt: readReceipt ?? this.readReceipt,
      offer: offer ?? this.offer,
      recording: recording ?? this.recording,
      recordElapsed: recordElapsed ?? this.recordElapsed,
      notice: notice ?? this.notice,
      noticeId: notice != null ? noticeId + 1 : noticeId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    session,
    messages,
    historyCursor,
    loadingOlder,
    translations,
    showOriginal,
    settings,
    savingSettings,
    readReceipt,
    offer,
    recording,
    recordElapsed,
    notice,
    noticeId,
  ];
}
