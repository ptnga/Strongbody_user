import 'package:flutter/material.dart';

import '../design_tokens/colour.dart';

/// Gắn vào `MaterialApp.scaffoldMessengerKey` để hiện toast ở mọi nơi.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class ToastUtil {
  ToastUtil._();

  static void showSuccess(String message) => _show(message, Colour.success);

  static void showError(String message) => _show(message, Colour.error);

  static void showInfo(String message) => _show(message, Colour.secondary);

  static void _show(String message, Color background) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }
}
