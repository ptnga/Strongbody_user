/// Timetoken chat-server: chuỗi 17 chữ số, đơn vị 100 ns (kiểu PubNub).
class ChatTimetoken {
  ChatTimetoken._();

  static DateTime toDateTime(String timetoken) {
    final value = int.tryParse(timetoken);
    if (value == null) return DateTime.now();
    return DateTime.fromMicrosecondsSinceEpoch(value ~/ 10);
  }

  /// Timetoken tạm cho tin đang gửi (đủ 17 chữ số, khác lỗi 13 chữ số của Multime).
  static String fromDateTime(DateTime time) =>
      '${time.microsecondsSinceEpoch * 10}';
}
