import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../data/mappers/market_mapper.dart';
import '../../domain/entities/medical_travel_entities.dart';
import '../bloc/medical_travel/appointment_cubit.dart';
import 'market_ui.dart';

/// Dữ liệu tối thiểu để mở form ngay (card chỉ có tên service, tên cơ sở, nước).
class AppointmentSeed {
  final int serviceId;
  final String title;
  final String? organization;
  final String? location;
  final MarketServiceDetail? detail;

  const AppointmentSeed({
    required this.serviceId,
    required this.title,
    this.organization,
    this.location,
    this.detail,
  });
}

/// "Request an appointment" (web `RequestAppointmentModal`): 1. thời điểm → 2. thông tin
/// liên hệ → 3. "Request sent". Khách gửi được, không bắt đăng nhập.
Future<void> showAppointmentSheet(BuildContext context, AppointmentSeed seed) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colour.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (_) => BlocProvider(
      create: (_) =>
          getIt<AppointmentCubit>()
            ..init(serviceId: seed.serviceId, detail: seed.detail),
      child: _AppointmentSheet(seed: seed),
    ),
  );
}

enum _Timing {
  asap('asap'),
  within3Months('within_3_months'),
  date('specific_date'),
  notSure('not_sure');

  final String api;

  const _Timing(this.api);

  String get label => switch (this) {
    asap => LocaleKeys.marketMtAppointmentFormTimingAsap.tr(),
    within3Months => LocaleKeys.marketMtAppointmentFormTimingWithin3Months.tr(),
    date => LocaleKeys.marketMtAppointmentFormTimingDate.tr(),
    notSure => LocaleKeys.marketMtAppointmentFormTimingNotSure.tr(),
  };

  String get hint => switch (this) {
    asap => LocaleKeys.marketMtAppointmentFormTimingAsapHint.tr(),
    within3Months =>
      LocaleKeys.marketMtAppointmentFormTimingWithin3MonthsHint.tr(),
    date => LocaleKeys.marketMtAppointmentFormTimingDateHint.tr(),
    notSure => LocaleKeys.marketMtAppointmentFormTimingNotSureHint.tr(),
  };
}

enum _Method {
  email('email'),
  whatsapp('whatsapp'),
  phone('phone_call');

  final String api;

  const _Method(this.api);

  String get label => switch (this) {
    email => LocaleKeys.marketMtAppointmentFormContactMethodEmail.tr(),
    whatsapp => LocaleKeys.marketMtAppointmentFormContactMethodWhatsapp.tr(),
    phone => LocaleKeys.marketMtAppointmentFormContactMethodPhone.tr(),
  };
}

class _AppointmentSheet extends StatefulWidget {
  final AppointmentSeed seed;

  const _AppointmentSheet({required this.seed});

  @override
  State<_AppointmentSheet> createState() => _AppointmentSheetState();
}

class _AppointmentSheetState extends State<_AppointmentSheet> {
  static const _custom = 'custom';
  static const _fallbackLanguages = ['en', 'vi', 'th'];
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _e164 = RegExp(r'^\+[1-9]\d{7,14}$');

  int _step = 1;
  _Timing? _timing;
  DateTime? _date;
  late final _name = TextEditingController(
    text: getIt<GlobalStorage>().userName ?? '',
  );
  late final _mail = TextEditingController(
    text: getIt<GlobalStorage>().userEmail ?? '',
  );
  final _phone = TextEditingController();
  final _message = TextEditingController();
  _Method _method = _Method.email;
  String _dial = '+1';
  String _language = '';
  bool _consent = true;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _name.dispose();
    _mail.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  void _pickTiming(_Timing t) {
    setState(() => _timing = t);
    if (t != _Timing.date) setState(() => _step = 2);
  }

  /// Số E.164; '' khi không hợp lệ (web `normalizedPhone` / `toE164`).
  String _normalizedPhone() {
    final raw = _phone.text.trim();
    if (_dial == _custom) {
      final full = '+${raw.replaceAll(RegExp(r'\D'), '')}';
      return raw.startsWith('+') && _e164.hasMatch(full) ? full : '';
    }
    final dial = _dial.replaceAll(RegExp(r'\D'), '');
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (!raw.startsWith('+') && digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith(dial) && digits.length - dial.length >= 6) {
      digits = digits.substring(dial.length);
    }
    digits = digits.replaceFirst(RegExp('^0+'), '');
    final e164 = '+$dial$digits';
    return digits.length >= 4 && _e164.hasMatch(e164) && e164.length <= 16
        ? e164
        : '';
  }

  void _submit(MarketServiceDetail? detail) {
    final timing = _timing;
    if (timing == null) return;
    final errors = <String, String>{};
    if (_name.text.trim().isEmpty) {
      errors['name'] = LocaleKeys.marketMtAppointmentFormErrorsNameRequired
          .tr();
    }
    if (!_email.hasMatch(_mail.text.trim())) {
      errors['email'] = LocaleKeys.marketMtAppointmentFormErrorsEmailInvalid
          .tr();
    }
    final needsPhone = _method != _Method.email;
    final phone = needsPhone ? _normalizedPhone() : '';
    if (needsPhone && phone.isEmpty) {
      errors['phone'] = LocaleKeys.marketMtAppointmentFormErrorsPhoneInvalid
          .tr();
    }
    if (!_consent) {
      errors['consent'] = LocaleKeys
          .marketMtAppointmentFormErrorsConsentRequired
          .tr();
    }
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    context.read<AppointmentCubit>().submit(
      AppointmentRequest(
        serviceId: widget.seed.serviceId,
        timeframe: timing.api,
        preferredFrom: timing == _Timing.date && _date != null
            ? DateFormat('yyyy-MM-dd').format(_date!)
            : null,
        firstName: _name.text.trim(),
        email: _mail.text.trim(),
        contactPreference: _method.api,
        phone: phone.isEmpty ? null : phone,
        preferredLanguage: _language.isEmpty ? null : _language,
        notes: _message.text.trim(),
      ),
    );
  }

  String _timingText(BuildContext context) {
    if (_timing == _Timing.date && _date != null) {
      return DateFormat.yMMMd(context.locale.toString()).format(_date!);
    }
    return _timing?.label ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppointmentCubit, AppointmentState>(
      listenWhen: (a, b) =>
          a.status != b.status || a.phoneCodes != b.phoneCodes,
      listener: (context, state) {
        if (state.status == AppointmentStatus.sent) setState(() => _step = 3);
        if (state.status == AppointmentStatus.failure) {
          setState(
            () => _errors = {
              'submit':
                  state.error ??
                  LocaleKeys.marketMtAppointmentFormErrorsFailed.tr(),
            },
          );
        }
        // Mã vùng mặc định +1 (web DEFAULT_PHONE_CODE), không có thì mục đầu.
        final codes = state.phoneCodes.map((c) => c.code);
        if (codes.isNotEmpty && !codes.contains(_dial) && _dial != _custom) {
          setState(() => _dial = codes.first);
        }
      },
      builder: (context, state) {
        final detail = state.detail;
        final organization =
            detail?.organizationName ?? widget.seed.organization;
        final location = detail?.locationTitle ?? widget.seed.location;
        final providerLine = [?organization, ?location].join(' · ');
        final title = switch (_step) {
          3 => LocaleKeys.marketMtAppointmentFormSuccessTitle.tr(),
          2 => LocaleKeys.marketMtAppointmentFormStepsContact.tr(),
          _ => LocaleKeys.marketMtAppointmentFormTitle.tr(),
        };
        final sending = state.status == AppointmentStatus.sending;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.92,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 12.w, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyle.lightHeadingSmall.copyWith(
                            color: Colour.textPrimary,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: Colour.subtle,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colour.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_step != 3) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
                    child: Text(
                      _step == 1
                          ? LocaleKeys.marketMtAppointmentFormIntro.tr()
                          : LocaleKeys.marketMtAppointmentFormContactIntro.tr(),
                      style: AppTextStyle.lightBodyMediumRegular.copyWith(
                        color: Colour.textSecondary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
                    child: _ServiceBox(
                      title: widget.seed.title,
                      providerLine: providerLine,
                    ),
                  ),
                ],
                const Divider(height: 1, color: Colour.lineSubtle),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
                    child: switch (_step) {
                      1 => _timingStep(context),
                      2 => _contactStep(context, state),
                      _ => _successStep(context, organization),
                    },
                  ),
                ),
                const Divider(height: 1, color: Colour.lineSubtle),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20.w,
                    12.h,
                    20.w,
                    12.h + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: switch (_step) {
                    3 => MarketButton(
                      large: true,
                      label: LocaleKeys.marketMtAppointmentFormSuccessDone.tr(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    2 => Row(
                      children: [
                        MarketButton(
                          large: true,
                          variant: MarketButtonVariant.outline,
                          label: LocaleKeys.marketMtAppointmentFormBack.tr(),
                          onPressed: () => setState(() => _step = 1),
                        ),
                        Gap(12.w),
                        Expanded(
                          child: MarketButton(
                            large: true,
                            label: sending
                                ? LocaleKeys.marketMtAppointmentFormSending.tr()
                                : LocaleKeys.marketMtAppointmentFormSend.tr(),
                            onPressed: sending ? null : () => _submit(detail),
                          ),
                        ),
                      ],
                    ),
                    _ => Text(
                      LocaleKeys.marketMtAppointmentFormFootnote.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyle.lightBodyMediumRegular.copyWith(
                        color: Colour.textSecondary,
                      ),
                    ),
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _timingStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.marketMtAppointmentFormTimingQuestion.tr(),
          style: AppTextStyle.lightBodyXLargeSemiBold.copyWith(
            color: Colour.textPrimary,
          ),
        ),
        Gap(4.h),
        Text(
          LocaleKeys.marketMtAppointmentFormTimingHelp.tr(),
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            color: Colour.textSecondary,
          ),
        ),
        Gap(16.h),
        for (final t in _Timing.values) ...[
          _RadioCard(
            checked: _timing == t,
            title: t.label,
            hint: t.hint,
            onTap: () => _pickTiming(t),
          ),
          if (t == _Timing.date && _timing == _Timing.date) ...[
            Gap(8.h),
            _InlineCalendar(
              value: _date,
              onPick: (d) => setState(() {
                _date = d;
                _step = 2;
              }),
            ),
          ],
          Gap(10.h),
        ],
      ],
    );
  }

  Widget _contactStep(BuildContext context, AppointmentState state) {
    final labelStyle = AppTextStyle.lightBodyMediumMedium.copyWith(
      color: Colour.textPrimary,
    );
    final secondary = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );
    final errorStyle = AppTextStyle.lightBodySmallRegular.copyWith(
      color: Colour.error,
    );
    Widget error(String key) => _errors[key] == null
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(_errors[key]!, style: errorStyle),
          );
    final detail = state.detail;
    final languages = detail != null && detail.languages.isNotEmpty
        ? detail.languages
        : [
            for (final code in _fallbackLanguages)
              (code: code, label: MarketMapper.languageName(code)),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colour.mutedWeb,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.marketMtAppointmentFormContactChosenTiming
                          .tr(),
                      style: secondary,
                    ),
                    Text(
                      _timingText(context),
                      style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                        color: Colour.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              MarketButton(
                label: LocaleKeys.marketMtAppointmentFormContactEdit.tr(),
                variant: MarketButtonVariant.link,
                onPressed: () => setState(() => _step = 1),
              ),
            ],
          ),
        ),
        Gap(20.h),
        Text(
          LocaleKeys.marketMtAppointmentFormContactFullName.tr(),
          style: labelStyle,
        ),
        Gap(6.h),
        TextField(
          controller: _name,
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            counterText: '',
            hintText: LocaleKeys
                .marketMtAppointmentFormContactFullNamePlaceholder
                .tr(),
          ),
        ),
        error('name'),
        Gap(16.h),
        Text(
          LocaleKeys.marketMtAppointmentFormContactEmail.tr(),
          style: labelStyle,
        ),
        Gap(6.h),
        TextField(
          controller: _mail,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: LocaleKeys.marketMtAppointmentFormContactEmailPlaceholder
                .tr(),
          ),
        ),
        error('email'),
        Gap(16.h),
        Text(
          LocaleKeys.marketMtAppointmentFormContactMethod.tr(),
          style: labelStyle,
        ),
        Gap(8.h),
        Row(
          children: [
            for (final (i, m) in _Method.values.indexed) ...[
              if (i > 0) Gap(8.w),
              Expanded(
                child: _Pill(
                  label: m.label,
                  selected: _method == m,
                  onTap: () => setState(() {
                    _method = m;
                    _errors.remove('phone');
                  }),
                ),
              ),
            ],
          ],
        ),
        if (_method != _Method.email) ...[
          Gap(16.h),
          Text(
            _method == _Method.whatsapp
                ? LocaleKeys.marketMtAppointmentFormContactWhatsapp.tr()
                : LocaleKeys.marketMtAppointmentFormContactPhone.tr(),
            style: labelStyle,
          ),
          Gap(6.h),
          Row(
            children: [
              SizedBox(
                width: 116.w,
                child: DropdownButtonFormField<String>(
                  initialValue: _dial,
                  isExpanded: true,
                  items: [
                    for (final c in state.phoneCodes)
                      DropdownMenuItem(value: c.code, child: Text(c.label)),
                    if (!state.phoneCodes.any((c) => c.code == _dial) &&
                        _dial != _custom)
                      DropdownMenuItem(value: _dial, child: Text(_dial)),
                    DropdownMenuItem(
                      value: _custom,
                      child: Text(
                        LocaleKeys.marketMtAppointmentFormContactDialOther.tr(),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _dial = v ?? _dial),
                ),
              ),
              Gap(8.w),
              Expanded(
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 25,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: _dial == _custom
                        ? '+49 123 456 789'
                        : LocaleKeys
                              .marketMtAppointmentFormContactPhonePlaceholder
                              .tr(),
                  ),
                ),
              ),
            ],
          ),
          if (_errors['phone'] != null)
            error('phone')
          else
            Padding(
              padding: EdgeInsets.only(top: 6.h),
              child: Text(
                _dial == _custom
                    ? LocaleKeys.marketMtAppointmentFormContactOtherHint.tr()
                    : _method == _Method.whatsapp
                    ? LocaleKeys.marketMtAppointmentFormContactWhatsappHint.tr()
                    : LocaleKeys.marketMtAppointmentFormContactPhoneHint.tr(),
                style: AppTextStyle.lightBodySmallRegular.copyWith(
                  color: Colour.textSecondary,
                ),
              ),
            ),
        ],
        Gap(16.h),
        Text.rich(
          TextSpan(
            text: LocaleKeys.marketMtAppointmentFormContactLanguage.tr(),
            children: [
              TextSpan(
                text:
                    ' · ${LocaleKeys.marketMtAppointmentFormContactOptional.tr()}',
                style: secondary,
              ),
            ],
          ),
          style: labelStyle,
        ),
        Gap(8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final option in [
              (
                code: '',
                label: LocaleKeys.marketMtAppointmentFormContactNoPreference
                    .tr(),
              ),
              ...languages,
            ])
              _Pill(
                label: option.label,
                selected: _language == option.code,
                onTap: () => setState(() => _language = option.code),
              ),
          ],
        ),
        Gap(16.h),
        Text.rich(
          TextSpan(
            text: LocaleKeys.marketMtAppointmentFormContactMessage.tr(),
            children: [
              TextSpan(
                text:
                    ' · ${LocaleKeys.marketMtAppointmentFormContactOptional.tr()}',
                style: secondary,
              ),
            ],
          ),
          style: labelStyle,
        ),
        Gap(6.h),
        TextField(
          controller: _message,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          decoration: InputDecoration(
            hintText: LocaleKeys
                .marketMtAppointmentFormContactMessagePlaceholder
                .tr(),
          ),
        ),
        Gap(8.h),
        InkWell(
          onTap: () => setState(() {
            _consent = !_consent;
            _errors.remove('consent');
          }),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _consent,
                activeColor: Colour.seller,
                onChanged: (v) => setState(() {
                  _consent = v ?? false;
                  _errors.remove('consent');
                }),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 12.h),
                  child: Text(
                    LocaleKeys.marketMtAppointmentFormContactConsent.tr(),
                    style: AppTextStyle.lightBodyMediumRegular.copyWith(
                      color: Colour.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 48.w),
          child: Text(
            LocaleKeys.marketMtAppointmentFormContactLegal.tr(),
            style: AppTextStyle.lightBodySmallRegular.copyWith(
              color: Colour.textSecondary,
            ),
          ),
        ),
        if (_errors['consent'] != null || _errors['submit'] != null)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Text(
              _errors['consent'] ?? _errors['submit']!,
              style: errorStyle,
            ),
          ),
      ],
    );
  }

  Widget _successStep(BuildContext context, String? organization) {
    final method = _method.label;
    final secondary = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );
    Widget row(String label, String value) => Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Text(label, style: secondary),
          Gap(12.w),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                color: Colour.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        Container(
          width: 56.r,
          height: 56.r,
          decoration: const BoxDecoration(
            color: Colour.seller50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, color: Colour.seller, size: 30.r),
        ),
        Gap(16.h),
        Text(
          LocaleKeys.marketMtAppointmentFormSuccessHeading.tr(),
          style: AppTextStyle.lightBodyXLargeSemiBold.copyWith(
            color: Colour.textPrimary,
          ),
        ),
        Gap(8.h),
        Text(
          LocaleKeys.marketMtAppointmentFormSuccessSentTo.tr(),
          textAlign: TextAlign.center,
          style: secondary,
        ),
        if (organization != null)
          Text(
            organization,
            textAlign: TextAlign.center,
            style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
              color: Colour.textPrimary,
            ),
          ),
        Gap(8.h),
        Text(
          LocaleKeys.marketMtAppointmentFormSuccessVia.tr(
            namedArgs: {'method': method.toLowerCase()},
          ),
          textAlign: TextAlign.center,
          style: secondary,
        ),
        Gap(20.h),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colour.border),
          ),
          child: Column(
            children: [
              row(
                LocaleKeys.marketMtAppointmentFormContactChosenTiming.tr(),
                _timingText(context),
              ),
              const Divider(height: 1, color: Colour.lineSubtle),
              row(
                method,
                _method == _Method.email
                    ? _mail.text.trim()
                    : _normalizedPhone(),
              ),
            ],
          ),
        ),
        Gap(16.h),
        Text(
          LocaleKeys.marketMtAppointmentFormSuccessNotice.tr(),
          textAlign: TextAlign.center,
          style: secondary,
        ),
      ],
    );
  }
}

/// Tên service + "Cơ sở · Nước" ở đầu form.
class _ServiceBox extends StatelessWidget {
  final String title;
  final String providerLine;

  const _ServiceBox({required this.title, required this.providerLine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colour.mutedWeb,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              color: Colour.brand50,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.local_hospital_outlined,
              color: Colour.primary,
              size: 22.r,
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                    color: Colour.textPrimary,
                  ),
                ),
                if (providerLine.isNotEmpty)
                  Text(
                    providerLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.lightBodySmallRegular.copyWith(
                      color: Colour.textSecondary,
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

/// Lựa chọn dạng thẻ có nút radio (web: viền seller khi chọn).
class _RadioCard extends StatelessWidget {
  final bool checked;
  final String title;
  final String hint;
  final VoidCallback onTap;

  const _RadioCard({
    required this.checked,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: checked ? Colour.seller25 : Colour.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(
          color: checked ? Colour.seller : Colour.border,
          width: checked ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Row(
            children: [
              Icon(
                checked
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18.r,
                color: checked ? Colour.seller : Colour.textTertiary,
              ),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                        color: Colour.textPrimary,
                      ),
                    ),
                    Gap(2.h),
                    Text(
                      hint,
                      style: AppTextStyle.lightBodySmallRegular.copyWith(
                        color: Colour.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip chọn một (kênh liên hệ / ngôn ngữ) — tone seller như web.
class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colour.seller50 : Colour.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? Colour.seller.withValues(alpha: 0.3)
              : Colour.border,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyle.lightBodyMediumMedium.copyWith(
              color: selected ? Colour.seller800 : Colour.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Lịch 1 tháng, tuần bắt đầu thứ Hai; ngày đã qua bị khoá (web `InlineCalendar`).
class _InlineCalendar extends StatefulWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  const _InlineCalendar({required this.value, required this.onPick});

  @override
  State<_InlineCalendar> createState() => _InlineCalendarState();
}

class _InlineCalendarState extends State<_InlineCalendar> {
  late DateTime _month = DateTime(
    (widget.value ?? DateTime.now()).year,
    (widget.value ?? DateTime.now()).month,
  );

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstOfThisMonth = DateTime(now.year, now.month);
    final offset = (_month.weekday + 6) % 7;
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    final canGoBack = _month.isAfter(firstOfThisMonth);
    // 2024-01-01 là thứ Hai.
    final weekdays = [
      for (var i = 0; i < 7; i++)
        DateFormat.E(locale).format(DateTime(2024, 1, 1 + i)),
    ];
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colour.mutedWeb,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.yMMMM(locale).format(_month),
                  style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                    color: Colour.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: canGoBack
                    ? () => setState(
                        () => _month = DateTime(_month.year, _month.month - 1),
                      )
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Row(
            children: [
              for (final d in weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: AppTextStyle.lightBodySmallRegular.copyWith(
                        color: Colour.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Gap(4.h),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4.r,
            crossAxisSpacing: 4.r,
            children: [
              for (var i = 0; i < offset; i++) const SizedBox.shrink(),
              for (var d = 1; d <= count; d++)
                Builder(
                  builder: (context) {
                    final day = DateTime(_month.year, _month.month, d);
                    final past = day.isBefore(today);
                    final selected = widget.value == day;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: past ? null : () => widget.onPick(day),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected ? Colour.seller : null,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$d',
                          style: AppTextStyle.lightBodyMediumRegular.copyWith(
                            color: selected
                                ? Colors.white
                                : past
                                ? Colour.textTertiary.withValues(alpha: 0.5)
                                : Colour.textPrimary,
                            decoration: day == today
                                ? TextDecoration.underline
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
