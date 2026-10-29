import 'dart:ui' show PlatformDispatcher;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_formatters.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../domain/entities/typing_suggestion.dart';

/// "Suggestions" khi đang gõ: tối đa 3 câu, phần khớp chữ đã gõ in đậm.
/// Chạm dòng → gửi luôn; mũi tên ↖ → điền vào ô để sửa tiếp.
class HomeTypingSuggestions extends StatelessWidget {
  final TypingSuggestionSeed seed;
  final ValueChanged<String> onSend;
  final ValueChanged<String> onFill;

  const HomeTypingSuggestions({
    super.key,
    required this.seed,
    required this.onSend,
    required this.onFill,
  });

  /// Ngôn ngữ người dùng nói: chọn ở Account, không thì ngôn ngữ máy.
  static String _speakingLanguage(String uiLocale) {
    final code =
        getIt<UserPreferences>().speakingLanguage ??
        PlatformDispatcher.instance.locale.languageCode;
    return ChatFormatters.languageName(code, uiLocale) ?? code;
  }

  List<String> _suggestions(String uiLocale) {
    final second = seed.secondary ?? seed.primary;
    final concern = seed.concern;
    final items = [
      LocaleKeys.homeSuggestNearMe.tr(args: [seed.primary]),
      concern != null
          ? LocaleKeys.homeSuggestForAtHome.tr(args: [second, concern])
          : LocaleKeys.homeSuggestAtHome.tr(args: [second]),
      LocaleKeys.homeSuggestSpeaks.tr(
        args: [seed.query, _speakingLanguage(uiLocale)],
      ),
    ];
    final seen = <String>{};
    return items.where((s) => seen.add(s.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) => HomeSuggestionRows(
    title: LocaleKeys.homeSuggestionsLabel.tr(),
    icon: Icons.search_rounded,
    items: _suggestions(context.locale.languageCode),
    query: seed.query,
    onSend: onSend,
    onFill: onFill,
  );
}

/// "Recent searches" khi focus ô nhập mà chưa gõ (prototype): icon đồng hồ.
class HomeRecentSearches extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onSend;
  final ValueChanged<String> onFill;

  const HomeRecentSearches({
    super.key,
    required this.items,
    required this.onSend,
    required this.onFill,
  });

  @override
  Widget build(BuildContext context) => HomeSuggestionRows(
    title: LocaleKeys.homeRecentSearches.tr(),
    icon: Icons.schedule_rounded,
    items: items,
    query: '',
    onSend: onSend,
    onFill: onFill,
  );
}

/// Danh sách dòng gợi ý: icon · chữ (in đậm phần khớp) · ↖ điền vào ô.
class HomeSuggestionRows extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final String query;
  final ValueChanged<String> onSend;
  final ValueChanged<String> onFill;

  const HomeSuggestionRows({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    required this.query,
    required this.onSend,
    required this.onFill,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 8.w, 6.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 4.h),
            child: Text(
              title,
              style: AppTextStyle.lightBodySmallSemiBold.copyWith(
                color: theme.textSecondary(context),
              ),
            ),
          ),
          for (final text in items)
            InkWell(
              onTap: () => onSend(text),
              borderRadius: BorderRadius.circular(8.r),
              child: Row(
                children: [
                  Icon(icon, size: 19.r, color: theme.textSecondary(context)),
                  Gap(10.w),
                  Expanded(
                    child: _Highlighted(text: text, query: query),
                  ),
                  IconButton(
                    onPressed: () => onFill(text),
                    tooltip: LocaleKeys.homeSuggestFill.tr(),
                    icon: Icon(
                      Icons.north_west_rounded,
                      size: 18.r,
                      color: theme.textTertiary(context),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// In đậm đoạn khớp chữ đã gõ (không phân biệt hoa thường).
class _Highlighted extends StatelessWidget {
  final String text;
  final String query;

  const _Highlighted({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: theme.textPrimary(context),
    );
    final start = text.toLowerCase().indexOf(query.toLowerCase());
    if (query.isEmpty || start < 0) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    final end = start + query.length;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
