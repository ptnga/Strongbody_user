import 'package:flutter/foundation.dart';

/// "Type instead" ở màn nói: về Home, mở bàn phím ở ô "Ask StrongBody" (giữ file đính kèm).
/// Giữ yêu cầu tới khi Home nhận (Home có thể đang dựng lại sau `go('/')`).
abstract final class HomeComposerFocus {
  static final pending = ValueNotifier<List<String>?>(null);

  static void request(List<String> attachments) =>
      pending.value = [...attachments];

  /// Home lấy yêu cầu đang chờ (null = không có).
  static List<String>? take() {
    final value = pending.value;
    pending.value = null;
    return value;
  }
}
