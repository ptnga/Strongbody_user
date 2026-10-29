import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../../domain/entities/voice_language_option.dart';
import '../../bloc/voice_request/voice_request_bloc.dart';

/// Chip "文A Auto-detect" / "文A Tiếng Việt" — chạm để chọn ngôn ngữ đang nói.
class VoiceLanguageChip extends StatelessWidget {
  const VoiceLanguageChip({super.key});

  Future<void> _openPicker(BuildContext context) async {
    final bloc = context.read<VoiceRequestBloc>();
    final state = bloc.state;
    // Sheet trả về: '' = Auto-detect, mã ngôn ngữ = chọn, null = đóng không chọn.
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LanguageSheet(
        languages: state.languages,
        selectedCode: state.languageCode,
      ),
    );
    if (picked == null) return;
    bloc.add(VoiceRequestLanguageSelected(picked.isEmpty ? null : picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocSelector<VoiceRequestBloc, VoiceRequestState, String>(
      selector: (state) =>
          state.selectedLanguage?.nativeName ??
          LocaleKeys.voiceRequestAutoDetect.tr(),
      builder: (context, label) => Material(
        color: theme.surface(context),
        shape: StadiumBorder(side: BorderSide(color: theme.border(context))),
        child: InkWell(
          onTap: () => _openPicker(context),
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  AppSvg.translate,
                  size: 17.r,
                  color: theme.textPrimary(context),
                ),
                Gap(6.w),
                Text(
                  label,
                  style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                    color: theme.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageSheet extends StatelessWidget {
  final List<VoiceLanguageOption> languages;
  final String? selectedCode;

  const _LanguageSheet({required this.languages, required this.selectedCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget tile({
      required String title,
      String? subtitle,
      required bool selected,
      required String result,
    }) {
      return ListTile(
        onTap: () => Navigator.of(context).pop(result),
        leading: AppIcon(
          AppSvg.translate,
          size: 24.r,
          color: selected
              ? theme.primary(context)
              : theme.textSecondary(context),
        ),
        title: Text(
          title,
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: theme.textPrimary(context),
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: AppTextStyle.lightBodySmallRegular.copyWith(
                  color: theme.textSecondary(context),
                ),
              ),
        trailing: selected
            ? AppIcon(AppSvg.check, size: 24.r, color: theme.primary(context))
            : null,
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 0.75.sh),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
              child: Text(
                LocaleKeys.voiceRequestLanguageTitle.tr(),
                style: AppTextStyle.lightBodyXLargeBold.copyWith(
                  color: theme.textPrimary(context),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  tile(
                    title: LocaleKeys.voiceRequestAutoDetect.tr(),
                    subtitle: LocaleKeys.voiceRequestAutoDetectHint.tr(),
                    selected: selectedCode == null,
                    result: '',
                  ),
                  for (final language in languages)
                    tile(
                      title: language.nativeName,
                      selected: language.code == selectedCode,
                      result: language.code,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
