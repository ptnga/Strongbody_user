/// Mở chat với một provider (`extra` của route chat). Header lấy tên/ảnh từ server,
/// các field ở đây chỉ để hiện ngay trong lúc kết nối.
class ChatPageArgs {
  final int partnerId;
  final String? name;
  final String? avatar;

  /// "Physiotherapist" — chat-server không có nghề nên truyền từ màn trước.
  final String? profession;

  /// Mở từ "Reply" / "Message" của một offer → dải trên đầu chat hiện offer này.
  final int? focusOfferId;

  const ChatPageArgs({
    required this.partnerId,
    this.name,
    this.avatar,
    this.profession,
    this.focusOfferId,
  });
}
