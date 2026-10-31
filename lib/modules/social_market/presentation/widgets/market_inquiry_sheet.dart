import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/components/initials_avatar.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';
import 'package:strongbody_buyer/modules/auth/presentation/widgets/auth_sheet.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_page_args.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_options.dart';

import '../../data/mappers/market_mapper.dart';
import '../../domain/entities/market_inquiry.dart';
import '../bloc/inquiry/inquiry_cubit.dart';
import '../market_formatters.dart';
import 'market_ui.dart';

/// Item đang hỏi (web `InquiryItem`): người nhận + card đính kèm tin nhắn.
class InquiryTarget {
  final InquiryKind kind;
  final int id;
  final int recipientUserId;
  final String title;
  final String? image;
  final String? price;
  final String? recipientName;
  final String? recipientShop;
  final String? recipientAvatar;
  final Map<String, dynamic> cardData;

  const InquiryTarget({
    required this.kind,
    required this.id,
    required this.recipientUserId,
    required this.title,
    required this.cardData,
    this.image,
    this.price,
    this.recipientName,
    this.recipientShop,
    this.recipientAvatar,
  });
}

/// Popup "Send your request" (web `InquiryDialog` + `RequestForm` variant 'send'):
/// 1 lần gửi = inquiry + request private + card và lời nhắn trong chat → mở chat.
Future<void> showMarketInquirySheet(
  BuildContext context,
  InquiryTarget target,
) async {
  final storage = getIt<GlobalStorage>();
  if (!storage.isLoggedIn) {
    // Chưa đăng nhập: mở popup auth TRƯỚC, không mở form (web `requireAuth`).
    final ok = await showAuthSheet(context, source: 'social_market_inquiry');
    if (!ok || !context.mounted) return;
  }
  if (storage.userId == target.recipientUserId) {
    ToastUtil.showError(LocaleKeys.marketInquiryOwnListing.tr());
    return;
  }
  final router = GoRouter.of(context);
  final recipient = await showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colour.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (_) => BlocProvider(
      create: (_) => getIt<InquiryCubit>(),
      child: _InquirySheet(target: target),
    ),
  );
  if (recipient == null) return;
  router.push(
    RouteName.chat,
    extra: ChatPageArgs(
      partnerId: recipient,
      name: target.recipientShop ?? target.recipientName,
      avatar: target.recipientAvatar,
      source: 'social_market_inquiry',
    ),
  );
}

class _InquirySheet extends StatefulWidget {
  final InquiryTarget target;

  const _InquirySheet({required this.target});

  @override
  State<_InquirySheet> createState() => _InquirySheetState();
}

class _InquirySheetState extends State<_InquirySheet> {
  static const _supportTypes = ['remote', 'at_home', 'at_clinic'];

  final _description = TextEditingController();
  final _budget = TextEditingController();
  String _currency = 'USD';
  final List<PlatformFile> _files = [];
  final Set<String> _delivery = {};
  bool _more = false;
  DateTime? _deadline;
  final Set<String> _days = {};
  TimeOfDay _from = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    _description.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _description.dispose();
    _budget.dispose();
    super.dispose();
  }

  /// "80" → 80–80, "120-150" → 120–150 (web `parseBudget`).
  static ({double? min, double? max}) _parseBudget(String text) {
    final nums = text
        .trim()
        .replaceAll(RegExp('[–—]'), '-')
        .split('-')
        .map((s) => double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), '')))
        .nonNulls
        .where((n) => n >= 0)
        .toList();
    if (nums.isEmpty) return (min: null, max: null);
    if (nums.length == 1) return (min: nums.first, max: nums.first);
    final a = nums[0], b = nums[1];
    return (min: a < b ? a : b, max: a < b ? b : a);
  }

  static String _hm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    setState(() => _files.addAll(result.files.where((f) => f.path != null)));
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline ?? now),
    );
    if (!mounted) return;
    setState(
      () => _deadline = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      ),
    );
  }

  Future<void> _pickTime(bool from) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: from ? _from : _to,
    );
    if (picked == null) return;
    setState(() => from ? _from = picked : _to = picked);
  }

  void _submit() {
    final t = widget.target;
    final description = _description.text.trim();
    if (description.isEmpty) return;
    final budget = _parseBudget(_budget.text);
    final hasBudget = budget.min != null || budget.max != null;
    final currency = hasBudget ? _currency : null;
    String? budgetText;
    if (hasBudget) {
      budgetText = budget.min == budget.max
          ? MarketMapper.formatMoney(budget.min!, _currency)
          : '${MarketMapper.formatMoney(budget.min!, _currency)} – ${MarketMapper.formatMoney(budget.max!, _currency)}';
    }
    final schedule = _days.isEmpty
        ? null
        : {
            for (final d in MarketFormatters.weekDays)
              if (_days.contains(d))
                d: [
                  {'from': _hm(_from), 'to': _hm(_to)},
                ],
          };
    context.read<InquiryCubit>().send(
      MarketInquiry(
        kind: t.kind,
        itemId: t.id,
        recipientUserId: t.recipientUserId,
        content: description,
        cardData: budgetText == null
            ? t.cardData
            : {...t.cardData, 'budget': budgetText},
        budgetFrom: budget.min,
        budgetTo: budget.max,
        budgetCurrency: currency ?? 'USD',
        // Nhiều cách nhận → BE nhận 1 giá trị 'all'.
        deliveryType: _delivery.isEmpty
            ? null
            : _delivery.length == 1
            ? _delivery.first
            : 'all',
        // `{mon:[{from,to}]}` như web `JSON.stringify(values.schedule)`.
        schedule: schedule == null ? null : jsonEncode(schedule),
        deadline: _deadline?.toUtc().toIso8601String(),
        attachmentPaths: _files.map((f) => f.path!).toList(),
        itemTitle: t.title,
        itemImage: t.image,
        itemPrice: t.price,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.target;
    final labelStyle = AppTextStyle.lightBodyMediumMedium.copyWith(
      color: Colour.textPrimary,
    );
    final helpStyle = AppTextStyle.lightBodyMediumRegular.copyWith(
      color: Colour.textSecondary,
    );
    final recipientName = t.recipientName ?? t.recipientShop;

    return BlocConsumer<InquiryCubit, InquiryState>(
      listener: (context, state) {
        if (state.status == InquiryStatus.success) {
          ToastUtil.showSuccess(LocaleKeys.marketToastRequestSent.tr());
          Navigator.of(context).pop(state.recipientUserId);
        } else if (state.status == InquiryStatus.failure) {
          ToastUtil.showError(LocaleKeys.marketToastRequestSendFailed.tr());
        }
      },
      builder: (context, state) {
        final sending = state.status == InquiryStatus.sending;
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
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 8.w, 12.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          LocaleKeys.marketInquiryTitle.tr(),
                          style: AppTextStyle.lightHeadingSmall.copyWith(
                            color: Colour.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colour.lineSubtle),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
                    children: [
                      _TargetHeader(target: t),
                      Gap(24.h),
                      Text(
                        recipientName == null
                            ? LocaleKeys.marketFormDetailHelp.tr()
                            : LocaleKeys.marketFormDetailHelpNamed.tr(
                                namedArgs: {'name': recipientName},
                              ),
                        style: helpStyle,
                      ),
                      Gap(8.h),
                      TextField(
                        controller: _description,
                        minLines: 5,
                        maxLines: 8,
                        decoration: InputDecoration(
                          hintText: t.kind == InquiryKind.service
                              ? LocaleKeys.marketInquiryPlaceholderService.tr()
                              : LocaleKeys.marketInquiryPlaceholderOffer.tr(),
                        ),
                      ),
                      Gap(24.h),
                      Text(
                        LocaleKeys.marketFormBudgetLabel.tr(),
                        style: labelStyle,
                      ),
                      Gap(4.h),
                      Text(
                        LocaleKeys.marketFormBudgetHelp.tr(),
                        style: helpStyle,
                      ),
                      Gap(8.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _budget,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                hintText: LocaleKeys.marketFormBudgetPlaceholder
                                    .tr(),
                              ),
                            ),
                          ),
                          Gap(8.w),
                          SizedBox(
                            width: 104.w,
                            child: DropdownButtonFormField<String>(
                              initialValue: _currency,
                              isExpanded: true,
                              items: [
                                for (final c in requestCurrencies)
                                  DropdownMenuItem(value: c, child: Text(c)),
                              ],
                              onChanged: (v) =>
                                  setState(() => _currency = v ?? 'USD'),
                            ),
                          ),
                        ],
                      ),
                      Gap(24.h),
                      Text(
                        LocaleKeys.marketFormAttachmentsHelp.tr(),
                        style: helpStyle,
                      ),
                      Gap(8.h),
                      for (final (i, f) in _files.indexed)
                        Container(
                          margin: EdgeInsets.only(bottom: 6.h),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colour.mutedWeb,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  f.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyle.lightBodyMediumRegular,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _files.removeAt(i)),
                                child: Icon(
                                  Icons.close,
                                  size: 16.r,
                                  color: Colour.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(LocaleKeys.marketFormAddFiles.tr()),
                      ),
                      Gap(24.h),
                      Text(
                        LocaleKeys.marketFormSupportLabel.tr(),
                        style: labelStyle,
                      ),
                      Gap(4.h),
                      Text(
                        LocaleKeys.marketFormSupportHelp.tr(),
                        style: helpStyle,
                      ),
                      Gap(8.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [
                          for (final type in _supportTypes)
                            FilterChip(
                              label: Text(MarketFormatters.formDelivery(type)),
                              avatar: Icon(switch (type) {
                                'remote' => Icons.videocam_outlined,
                                'at_home' => Icons.home_outlined,
                                _ => Icons.local_hospital_outlined,
                              }, size: 16.r),
                              selected: _delivery.contains(type),
                              showCheckmark: false,
                              selectedColor: Colour.seller50,
                              onSelected: (on) => setState(
                                () => on
                                    ? _delivery.add(type)
                                    : _delivery.remove(type),
                              ),
                            ),
                        ],
                      ),
                      Gap(16.h),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _more = !_more),
                          icon: Icon(
                            _more ? Icons.expand_less : Icons.expand_more,
                          ),
                          label: Text(
                            _more
                                ? LocaleKeys.marketFormFewerDetails.tr()
                                : LocaleKeys.marketFormMoreDetail.tr(),
                          ),
                        ),
                      ),
                      if (_more) ...[
                        Gap(8.h),
                        Text(
                          LocaleKeys.marketFormDeadlineLabel.tr(),
                          style: labelStyle,
                        ),
                        Gap(4.h),
                        Text(
                          LocaleKeys.marketFormOptional.tr(),
                          style: helpStyle,
                        ),
                        Gap(8.h),
                        InkWell(
                          onTap: _pickDeadline,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              suffixIcon: _deadline == null
                                  ? const Icon(Icons.event_outlined)
                                  : IconButton(
                                      onPressed: () =>
                                          setState(() => _deadline = null),
                                      icon: const Icon(Icons.close),
                                    ),
                            ),
                            child: Text(
                              _deadline == null
                                  ? LocaleKeys.marketFormDeadlinePlaceholder
                                        .tr()
                                  : DateFormat.yMd(
                                      context.locale.toString(),
                                    ).add_Hm().format(_deadline!),
                              style: AppTextStyle.lightBodyLargeRegular
                                  .copyWith(
                                    color: _deadline == null
                                        ? Colour.textTertiary
                                        : Colour.textPrimary,
                                  ),
                            ),
                          ),
                        ),
                        Gap(24.h),
                        Text(
                          LocaleKeys.marketFormScheduleLabel.tr(),
                          style: labelStyle,
                        ),
                        Gap(4.h),
                        Text(
                          LocaleKeys.marketFormScheduleHelp.tr(),
                          style: helpStyle,
                        ),
                        Gap(8.h),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: [
                            for (final d in MarketFormatters.weekDays)
                              ChoiceChip(
                                label: Text(MarketFormatters.weekDay(d)),
                                selected: _days.contains(d),
                                showCheckmark: false,
                                selectedColor: Colour.textPrimary,
                                labelStyle: AppTextStyle.lightBodyMediumMedium
                                    .copyWith(
                                      color: _days.contains(d)
                                          ? Colors.white
                                          : Colour.textSecondary,
                                    ),
                                onSelected: (on) => setState(
                                  () => on ? _days.add(d) : _days.remove(d),
                                ),
                              ),
                          ],
                        ),
                        Gap(12.h),
                        Row(
                          children: [
                            Text(
                              LocaleKeys.marketFormTimeFrom.tr(),
                              style: helpStyle,
                            ),
                            Gap(8.w),
                            OutlinedButton(
                              onPressed: () => _pickTime(true),
                              child: Text(_hm(_from)),
                            ),
                            Gap(12.w),
                            Text(
                              LocaleKeys.marketFormTimeTo.tr(),
                              style: helpStyle,
                            ),
                            Gap(8.w),
                            OutlinedButton(
                              onPressed: () => _pickTime(false),
                              child: Text(_hm(_to)),
                            ),
                          ],
                        ),
                        Gap(8.h),
                        Text(
                          _days.isEmpty
                              ? LocaleKeys.marketFormScheduleSelectDays.tr()
                              : LocaleKeys.marketFormScheduleSameTime.tr(),
                          style: helpStyle,
                        ),
                      ],
                    ],
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
                  child: MarketButton(
                    large: true,
                    label: sending
                        ? LocaleKeys.marketInquirySending.tr()
                        : LocaleKeys.marketFormSendSubmit.tr(),
                    onPressed: _description.text.trim().isEmpty || sending
                        ? null
                        : _submit,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "To: [avatar] Tên | Shop" + item đính kèm (web `InquiryTarget`).
class _TargetHeader extends StatelessWidget {
  final InquiryTarget target;

  const _TargetHeader({required this.target});

  @override
  Widget build(BuildContext context) {
    final t = target;
    final hasRecipient = t.recipientName != null || t.recipientShop != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasRecipient) ...[
          Row(
            children: [
              Text(
                LocaleKeys.marketInquiryTo.tr(),
                style: AppTextStyle.lightBodyMediumMedium.copyWith(
                  color: Colour.textPrimary,
                ),
              ),
              Gap(8.w),
              if (t.recipientAvatar != null) ...[
                InitialsAvatar(
                  name: t.recipientName ?? '',
                  imageUrl: t.recipientAvatar,
                  colorSeed: 3,
                  size: 24.r,
                ),
                Gap(8.w),
              ],
              if (t.recipientName != null)
                Flexible(
                  child: Text(
                    t.recipientName!,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.lightBodyMediumMedium.copyWith(
                      color: Colour.textPrimary,
                    ),
                  ),
                ),
              if (t.recipientShop != null &&
                  t.recipientShop != t.recipientName) ...[
                Text(
                  '  |  ',
                  style: AppTextStyle.lightBodyMediumRegular.copyWith(
                    color: Colour.textTertiary,
                  ),
                ),
                Flexible(
                  child: Text(
                    t.recipientShop!,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.lightBodyMediumRegular.copyWith(
                      color: Colour.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Gap(16.h),
        ],
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colour.mutedWeb,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: SizedBox(
                  width: 56.r,
                  height: 56.r,
                  child: t.image == null
                      ? const ColoredBox(
                          color: Colour.subtle,
                          child: Icon(
                            Icons.description_outlined,
                            color: Colour.textSecondary,
                          ),
                        )
                      : Image.network(
                          t.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Colour.subtle),
                        ),
                ),
              ),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.lightBodyMediumMedium.copyWith(
                        color: Colour.textPrimary,
                      ),
                    ),
                    if (t.price != null) ...[
                      Gap(2.h),
                      Text(
                        t.price!,
                        style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                          color: Colour.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
