import 'package:flutter_dotenv/flutter_dotenv.dart';

enum Environment {
  dev,
  prod;

  /// `--flavor dev|prod` (Android productFlavors / iOS scheme) → môi trường.
  static Environment fromFlavor(String? flavor) =>
      flavor == 'prod' ? prod : dev;
}

class AppConfig {
  AppConfig._();

  static Environment _environment = Environment.dev;

  static void setEnvironment(Environment environment) {
    _environment = environment;
  }

  static Environment get environment => _environment;
  static bool get isDev => _environment == Environment.dev;
  static bool get isProd => _environment == Environment.prod;

  static Future<void> loadEnv() async {
    final fileName = isProd ? 'assets/env/.env.prod' : 'assets/env/.env.dev';
    await dotenv.load(fileName: fileName);
  }

  static String get appName => dotenv.env['APP_NAME'] ?? 'StrongBody Buyer';

  /// Base URL đã bao gồm `/v1` — endpoint không lặp lại `/v1`.
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://api-v2.strongbody.ai/v1';

  /// Key công khai cho các API `/public/*` cần header `X-API-KEY` (giống Multime).
  static String get publicApiKey =>
      dotenv.env['PUBLIC_API_KEY'] ?? 'your_api_key';

  /// Google Sign-In: Web client ID (backend kiểm `aud` của id_token theo ID này) + iOS client ID
  /// của bundle app. Rỗng = chưa cấu hình → nút Google báo chưa hỗ trợ.
  static String get googleServerClientId =>
      dotenv.env['GOOGLE_SERVER_CLIENT_ID'] ?? '';
  static String get googleIosClientId =>
      dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';

  /// Bật khi đã thêm capability "Sign in with Apple" cho bundle app.
  static bool get appleSignInEnabled =>
      dotenv.env['APPLE_SIGN_IN_ENABLED']?.toLowerCase() == 'true';

  /// Domain web (Next.js) — dùng cho các API route chỉ có ở web
  /// (vd `/api/ai/request-draft`, key LLM nằm phía server web).
  static String get webBaseUrl =>
      dotenv.env['WEB_BASE_URL'] ?? 'https://strongbody.ai';

  /// chat-server (PubNub clone) — WS `wss://…/v3/subscribe`, REST cùng host qua https.
  static String get chatServerUrl =>
      dotenv.env['CHAT_SERVER_URL'] ?? 'wss://chat.strongbody.ai';
  static String get chatServerTenant =>
      dotenv.env['CHAT_SERVER_TENANT'] ?? 'strongbody';

  /// Point service (Lion Points) — `{url}/v1/wallets/customer/{userId}`.
  static String get pointApiUrl =>
      dotenv.env['POINT_API_URL'] ?? 'https://point-api.strongbody.ai/api';

  /// Stripe publishable key (public) — thanh toán offer bằng thẻ như web checkout.
  static String get stripePublishableKey =>
      dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
}
