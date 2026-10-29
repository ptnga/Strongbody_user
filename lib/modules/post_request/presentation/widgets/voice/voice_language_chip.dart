import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';

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
                Icon(
                  Icons.translate_rounded,
                  size: 17.r,
                  color: theme.textPrimary(context),
                ),
                Gap(6.w),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
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
        leading: Icon(
          Icons.translate_rounded,
          color: selected
              ? theme.primary(context)
              : theme.textSecondary(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: theme.textPrimary(context),
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: theme.textSecondary(context),
                ),
              ),
        trailing: selected
            ? Icon(Icons.check_rounded, color: theme.primary(context))
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
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
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
