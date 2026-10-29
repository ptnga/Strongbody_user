import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../utils/app_logger.dart';

/// Quyền micro (+ nhận giọng nói trên iOS) cho màn nói yêu cầu.
abstract class MicrophonePermissionService {
  /// Người dùng đã từ chối (hoặc bị hạn chế) — cần bật lại trong Cài đặt.
  Future<bool> isBlocked();

  /// Mở trang Cài đặt của app.
  Future<void> openSettings();
}

class MicrophonePermissionServiceImpl implements MicrophonePermissionService {
  @override
  Future<bool> isBlocked() async {
    try {
      final permissions = [
        Permission.microphone,
        if (Platform.isIOS) Permission.speech,
      ];
      for (final permission in permissions) {
        if (await permission.isGranted) continue;
        // Đã chặn hẳn thì `request` trả ngay, không hiện hộp thoại.
        if (!(await permission.request()).isGranted) return true;
      }
      return false;
    } catch (e) {
      AppLogger.w('Microphone permission check failed', e);
      return false;
    }
  }

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
