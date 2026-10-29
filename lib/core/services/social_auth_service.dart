import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/environment.dart';
import '../utils/app_logger.dart';

/// Người dùng tự huỷ hộp thoại Google / Apple — không báo lỗi.
class SocialAuthCancelled implements Exception {}

/// Bản build chưa cấu hình client ID / capability cho provider này.
class SocialAuthNotConfigured implements Exception {}

/// Lấy token từ SDK native (giống Multime `auth_services.dart`):
/// Google → `idToken` (backend `/public/auth/login-google-id-token`),
/// Apple → `authorizationCode` gửi ở field `id_token` (backend `/public/auth/login-apple`).
abstract class SocialAuthService {
  Future<String> googleIdToken();

  Future<String> appleAuthorizationCode();

  Future<void> signOut();
}

class SocialAuthServiceImpl implements SocialAuthService {
  bool _googleReady = false;

  @override
  Future<String> googleIdToken() async {
    final serverClientId = AppConfig.googleServerClientId;
    if (serverClientId.isEmpty ||
        (Platform.isIOS && AppConfig.googleIosClientId.isEmpty)) {
      throw SocialAuthNotConfigured();
    }
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(
        clientId: Platform.isIOS ? AppConfig.googleIosClientId : null,
        serverClientId: serverClientId,
      );
      _googleReady = true;
    }
    try {
      await google.signOut();
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw Exception('Missing Google id token');
      }
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw SocialAuthCancelled();
      }
      AppLogger.e('Google sign-in failed', e);
      rethrow;
    }
  }

  @override
  Future<String> appleAuthorizationCode() async {
    if (!Platform.isIOS || !AppConfig.appleSignInEnabled) {
      throw SocialAuthNotConfigured();
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      return credential.authorizationCode;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw SocialAuthCancelled();
      }
      AppLogger.e('Apple sign-in failed', e);
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    if (!_googleReady) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
