/// Danh sách tiền tệ của form request (giống web `CURRENCIES`).
const List<String> requestCurrencies = [
  'USD',
  'EUR',
  'GBP',
  'VND',
  'JPY',
  'KRW',
  'CNY',
  'SGD',
  'AUD',
  'CAD',
  'THB',
  'INR',
];

class RequestLanguageOption {
  final String code;
  final String name;
  final String nativeName;

  const RequestLanguageOption(this.code, this.name, this.nativeName);
}

/// Ngôn ngữ provider (giống web `SUPPORTED_LANGUAGES` trong `utils/chat-languages.ts`).
const List<RequestLanguageOption> requestLanguages = [
  RequestLanguageOption('en', 'English', 'English'),
  RequestLanguageOption('vi', 'Vietnamese', 'Tiếng Việt'),
  RequestLanguageOption('zh-CN', 'Chinese (Simplified)', '简体中文'),
  RequestLanguageOption('zh-TW', 'Chinese (Traditional)', '繁體中文'),
  RequestLanguageOption('ja', 'Japanese', '日本語'),
  RequestLanguageOption('ko', 'Korean', '한국어'),
  RequestLanguageOption('th', 'Thai', 'ไทย'),
  RequestLanguageOption('id', 'Indonesian', 'Bahasa Indonesia'),
  RequestLanguageOption('fr', 'French', 'Français'),
  RequestLanguageOption('es', 'Spanish', 'Español'),
  RequestLanguageOption('de', 'German', 'Deutsch'),
  RequestLanguageOption('pt', 'Portuguese', 'Português'),
  RequestLanguageOption('ru', 'Russian', 'Русский'),
  RequestLanguageOption('ar', 'Arabic', 'العربية'),
  RequestLanguageOption('hi', 'Hindi', 'हिन्दी'),
  RequestLanguageOption('it', 'Italian', 'Italiano'),
  RequestLanguageOption('nl', 'Dutch', 'Nederlands'),
  RequestLanguageOption('pl', 'Polish', 'Polski'),
  RequestLanguageOption('tr', 'Turkish', 'Türkçe'),
  RequestLanguageOption('sv', 'Swedish', 'Svenska'),
];

RequestLanguageOption? requestLanguageByCode(String code) {
  for (final language in requestLanguages) {
    if (language.code == code) return language;
  }
  return null;
}
