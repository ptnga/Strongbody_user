import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../../domain/entities/request_form_values.dart';
import '../../../domain/entities/request_options.dart';
import '../../request_formatters.dart';

/// Nhãn field (web `Field`).
class RequestFieldLabel extends StatelessWidget {
  final String text;

  const RequestFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Text(
      text,
      style: AppTextStyle.lightBodyMediumMedium.copyWith(
        color: Colour.textPrimary,
      ),
    ),
  );
}

/// Dòng lỗi đỏ dưới ô.
class RequestFieldError extends StatelessWidget {
  final String text;

  const RequestFieldError(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 6.h),
    child: Text(
      text,
      style: AppTextStyle.lightBodySmallRegular.copyWith(color: Colour.error),
    ),
  );
}

InputDecoration requestInputDecoration({String? hint, bool error = false}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12.r),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: Colour.surface,
    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
    border: border(Colour.lineStrong),
    enabledBorder: border(error ? Colour.error : Colour.lineStrong),
    focusedBorder: border(error ? Colour.error : Colour.textSecondary),
    disabledBorder: border(Colour.border),
  );
}

/// "Where would you like to receive the service?" — chọn nhiều (web `MultiChipPicker`).
class RequestDeliveryPicker extends StatelessWidget {
  final List<RequestDeliveryType> value;
  final ValueChanged<List<RequestDeliveryType>> onChanged;

  const RequestDeliveryPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static IconData icon(RequestDeliveryType type) => switch (type) {
    RequestDeliveryType.remote => Icons.videocam_outlined,
    RequestDeliveryType.atOffice => Icons.apartment_outlined,
    RequestDeliveryType.atClinic => Icons.local_hospital_outlined,
    RequestDeliveryType.atHome => Icons.home_outlined,
  };

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8.w,
    runSpacing: 8.h,
    children: [
      for (final type in RequestDeliveryType.values)
        _Chip(
          icon: icon(type),
          label: RequestFormatters.deliveryOption(type),
          selected: value.contains(type),
          onTap: () => onChanged(
            value.contains(type)
                ? value.where((t) => t != type).toList()
                : [...value, type],
          ),
        ),
    ],
  );
}

class _Chip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colour.buttonPrimary : Colour.textPrimary;
    return Material(
      color: selected
          ? Colour.buttonPrimary.withValues(alpha: 0.08)
          : Colour.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? Colour.buttonPrimary : Colour.lineStrong,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18.r, color: color),
                Gap(6.w),
              ],
              Text(
                label,
                style: AppTextStyle.lightBodyMediumMedium.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Working language" — chọn nhiều ngôn ngữ (web `LanguageMultiSelect`).
class RequestLanguagePicker extends StatelessWidget {
  final List<String> value;
  final ValueChanged<List<String>> onChanged;

  const RequestLanguagePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static String name(String code) =>
      requestLanguageByCode(code)?.name ??
      requestLanguages
          .where((l) => l.code.toLowerCase() == code.toLowerCase())
          .firstOrNull
          ?.name ??
      code;

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LanguageSheet(selected: value),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colour.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.r),
      side: const BorderSide(color: Colour.lineStrong),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: () => _pick(context),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 8.w, 10.h),
        child: Row(
          children: [
            Expanded(
              child: value.isEmpty
                  ? Text(
                      LocaleKeys.postRequestSelectLanguages.tr(),
                      style: AppTextStyle.lightBodyMediumRegular.copyWith(
                        color: Colour.textTertiary,
                      ),
                    )
                  : Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        for (final code in value)
                          InputChip(
                            label: Text(name(code)),
                            labelStyle: AppTextStyle.lightBodySmallMedium
                                .copyWith(color: Colour.textPrimary),
                            backgroundColor: Colour.muted,
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                            onDeleted: () => onChanged(
                              value.where((c) => c != code).toList(),
                            ),
                          ),
                      ],
                    ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 22.r,
              color: Colour.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _LanguageSheet extends StatefulWidget {
  final List<String> selected;

  const _LanguageSheet({required this.selected});

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  late final _selected = [...widget.selected];
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final options = requestLanguages
        .where(
          (l) =>
              q.isEmpty ||
              l.name.toLowerCase().contains(q) ||
              l.nativeName.toLowerCase().contains(q),
        )
        .toList();
    return SafeArea(
      child: SizedBox(
        height: 0.7.sh,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: requestInputDecoration(
                  hint: LocaleKeys.postRequestSearchLanguages.tr(),
                ).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
              ),
            ),
            Gap(8.h),
            Expanded(
              child: ListView(
                children: [
                  for (final l in options)
                    CheckboxListTile(
                      value: _selected.contains(l.code),
                      activeColor: Colour.buttonPrimary,
                      title: Text(
                        l.name,
                        style: AppTextStyle.lightBodyMediumRegular.copyWith(
                          color: Colour.textPrimary,
                        ),
                      ),
                      subtitle: l.nativeName == l.name
                          ? null
                          : Text(
                              l.nativeName,
                              style: AppTextStyle.lightBodySmallRegular
                                  .copyWith(color: Colour.textSecondary),
                            ),
                      onChanged: (on) => setState(
                        () => on == true
                            ? _selected.add(l.code)
                            : _selected.remove(l.code),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
              child: SizedBox(
                width: double.infinity,
                height: 48.h,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: Text(LocaleKeys.commonDone.tr()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô chọn tiền tệ cạnh ô Budget (web `CurrencySelect`): danh sách bảng `currencies`;
/// chưa tải được thì dùng danh sách mặc định.
class RequestCurrencySelect extends StatelessWidget {
  final String value;
  final List<({String code, int? id})> options;
  final void Function(String code, int? id) onChanged;
  final bool enabled;

  const RequestCurrencySelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ...options,
      if (!options.any((o) => o.code == value)) (code: value, id: null),
    ];
    return Container(
      height: 50.h,
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: Colour.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colour.lineStrong),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          menuMaxHeight: 0.5.sh,
          dropdownColor: Colour.surface,
          style: AppTextStyle.lightBodyMediumMedium.copyWith(
            color: Colour.textPrimary,
          ),
          items: [
            for (final o in items)
              DropdownMenuItem(value: o.code, child: Text(o.code)),
          ],
          onChanged: enabled
              ? (code) {
                  if (code == null) return;
                  onChanged(
                    code,
                    items.where((o) => o.code == code).firstOrNull?.id,
                  );
                }
              : null,
        ),
      ),
    );
  }
}
