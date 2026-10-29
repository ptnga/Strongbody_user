import 'package:equatable/equatable.dart';

import 'provider_keyword.dart';
import 'request_options.dart';

/// Câu "refine by voice" ở màn Matching providers → bộ lọc.
/// Ví dụ: "speaks Vietnamese", "under $70", "top rated", "yoga teacher".
/// API chưa có giới tính provider nên "only women providers" được bỏ qua.
class ProviderRefineQuery extends Equatable {
  /// Từ khoá nghề mới (đổi danh sách tìm kiếm).
  final String? keyword;
  final String? languageCode;
  final double? maxBudget;
  final bool topRated;

  const ProviderRefineQuery({
    this.keyword,
    this.languageCode,
    this.maxBudget,
    this.topRated = false,
  });

  bool get isEmpty =>
      keyword == null && languageCode == null && maxBudget == null && !topRated;

  static final _budget = RegExp(
    r'(?:under|below|less than|max(?:imum)?|up to|dưới|không quá|tối đa)\s*\$?\s*(\d+(?:[.,]\d+)?)\s*(k)?',
    caseSensitive: false,
  );
  static final _topRated = RegExp(
    r'top[- ]rated|best[- ]rated|highest[- ]rated|best reviews|đánh giá cao|tốt nhất',
    caseSensitive: false,
  );

  factory ProviderRefineQuery.parse(String text) {
    final lower = text.toLowerCase();

    String? languageCode;
    for (final language in requestLanguages) {
      final names = {
        language.name.toLowerCase(),
        language.nativeName.toLowerCase(),
      };
      if (names.any(lower.contains)) {
        languageCode = language.code;
        break;
      }
    }

    double? maxBudget;
    final budget = _budget.firstMatch(lower);
    if (budget != null) {
      final value = double.tryParse(budget.group(1)!.replaceAll(',', '.'));
      if (value != null) {
        maxBudget = budget.group(2) == null ? value : value * 1000;
      }
    }

    return ProviderRefineQuery(
      keyword: ProviderKeyword.fromText(text, const []),
      languageCode: languageCode,
      maxBudget: maxBudget,
      topRated: _topRated.hasMatch(lower),
    );
  }

  @override
  List<Object?> get props => [keyword, languageCode, maxBudget, topRated];
}
