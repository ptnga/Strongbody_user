import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

class _Suggestion {
  final String titleKey;
  final String subtitleKey;

  const _Suggestion(this.titleKey, this.subtitleKey);
}

/// Thẻ gợi ý cuộn ngang phía trên ô nhập. Chạm → điền câu vào ô nhập để sửa rồi gửi.
class HomeSuggestionList extends StatefulWidget {
  final ValueChanged<String> onSelected;

  const HomeSuggestionList({super.key, required this.onSelected});

  @override
  State<HomeSuggestionList> createState() => _HomeSuggestionListState();
}

class _HomeSuggestionListState extends State<HomeSuggestionList> {
  final _controller = ScrollController();

  static const _suggestions = [
    _Suggestion(
      LocaleKeys.homeSuggestion1Title,
      LocaleKeys.homeSuggestion1Subtitle,
    ),
    _Suggestion(
      LocaleKeys.homeSuggestion2Title,
      LocaleKeys.homeSuggestion2Subtitle,
    ),
    _Suggestion(
      LocaleKeys.homeSuggestion3Title,
      LocaleKeys.homeSuggestion3Subtitle,
    ),
    _Suggestion(
      LocaleKeys.homeSuggestion4Title,
      LocaleKeys.homeSuggestion4Subtitle,
    ),
    _Suggestion(
      LocaleKeys.homeSuggestion5Title,
      LocaleKeys.homeSuggestion5Subtitle,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 102.h,
      child: RawScrollbar(
        controller: _controller,
        thumbVisibility: true,
        trackVisibility: true,
        thickness: 8.h,
        radius: Radius.circular(8.r),
        thumbColor: theme.textSecondary(context).withValues(alpha: 0.8),
        trackColor: theme.muted(context),
        trackRadius: Radius.circular(8.r),
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: ListView.separated(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 18.h),
          itemCount: _suggestions.length,
          separatorBuilder: (_, _) => Gap(10.w),
          itemBuilder: (context, index) {
            final suggestion = _suggestions[index];
            final title = suggestion.titleKey.tr();
            final subtitle = suggestion.subtitleKey.tr();
            return _SuggestionCard(
              title: title,
              subtitle: subtitle,
              onTap: () => widget.onSelected('$title $subtitle'),
            );
          },
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: theme.border(context)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: 166.w,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.lightBodyMediumBold.copyWith(
                  color: theme.textPrimary(context),
                ),
              ),
              Gap(2.h),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.lightBodySmallRegular.copyWith(
                  color: theme.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
