import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_draft_entity.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/request_formatters.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_ui.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/medical_travel_widgets.dart';

import '../../domain/entities/assistant_entities.dart';
import 'assistant_results.dart';
import 'assistant_rich_text.dart';

TextStyle get _bodyStyle => AppTextStyle.lightBodyLargeRegular.copyWith(
  color: Colour.textPrimary,
  height: 1.55,
);

TextStyle get _metaStyle =>
    AppTextStyle.lightBodyMediumRegular.copyWith(color: Colour.textSecondary);

/// Bong bóng câu khách gửi (phải, nền hồng nhạt).
class AssistantUserBubble extends StatelessWidget {
  final String text;

  const AssistantUserBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 300.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colour.brand50,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(text, semanticsLabel: text, style: _bodyStyle),
      ),
    ),
  );
}

/// Lượt trả lời của trợ lý (web `AssistantMessage`): chữ / trạng thái đang chạy, lỗi + thử
/// lại, khu vực đã tìm, thẻ kết quả, form request điền sẵn, nút đăng request khi không ai
/// khớp, câu hỏi gợi ý.
class AssistantReply extends StatelessWidget {
  final AssistantReplyTurn turn;
  final bool isLast;
  final ValueChanged<String> onAsk;
  final VoidCallback onRetry;
  final VoidCallback onPostRequest;
  final void Function(RequestDraftEntity draft, String origin) onReviewRequest;

  const AssistantReply({
    super.key,
    required this.turn,
    required this.isLast,
    required this.onAsk,
    required this.onRetry,
    required this.onPostRequest,
    required this.onReviewRequest,
  });

  @override
  Widget build(BuildContext context) {
    final r = turn.result;
    final branch = r?.branch ?? turn.branch;
    final text = turn.text.isNotEmpty
        ? turn.text
        : branch == 'out_of_scope'
        ? (r?.reason ?? LocaleKeys.assistantOutOfScope.tr())
        : '';
    final searchLike = branch == 'search' || branch == 'request';
    final noResults =
        branch == 'search' && r != null && !r.hasCards && !turn.streaming;

    final children = <Widget>[
      if (turn.streaming && text.isEmpty)
        _StatusCard(branch: turn.branch)
      else if (text.isNotEmpty)
        MarketCard(
          padding: EdgeInsets.all(16.r),
          child: AssistantRichText(
            text: text,
            style: _bodyStyle,
            trailing: turn.streaming
                ? SizedBox.square(
                    dimension: 14.r,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colour.textTertiary,
                    ),
                  )
                : null,
          ),
        ),
      if (turn.error != null) _ErrorCard(error: turn.error!, onRetry: onRetry),
      if (r != null && r.near != null && branch == 'search' && r.hasCards)
        _NearLine(result: r),
      if (r != null && r.needsLocation && isLast && !turn.streaming)
        const _LocationHint(),
      if (r != null && branch == 'request' && r.requestDraft != null)
        AssistantRequestDraftPanel(
          draft: r.requestDraft!,
          onReview: (d) => onReviewRequest(d, 'request_branch'),
        ),
      if (r != null && searchLike && r.hasCards)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (branch == 'request') ...[
              Text(
                LocaleKeys.assistantRequestProviders.tr(),
                style: AppTextStyle.lightBodyLargeSemiBold.copyWith(
                  color: Colour.textPrimary,
                ),
              ),
              Gap(12.h),
            ],
            AssistantResultGroups(result: r, groups: r.cards),
          ],
        ),
      if (r != null && branch == 'search' && r.hasCloseMatches)
        AssistantResultGroups(
          result: r,
          groups: r.closeMatches,
          limit: 3,
          close: true,
        ),
      if (turn.requestDraft case final draft?)
        AssistantRequestDraftPanel(
          draft: draft,
          onReview: (d) => onReviewRequest(d, 'no_results'),
        ),
      if (noResults && turn.requestDraft == null)
        Align(
          alignment: Alignment.centerLeft,
          child: _IconButton(
            icon: Icons.add_rounded,
            label: LocaleKeys.assistantPostRequestCta.tr(),
            onPressed: onPostRequest,
          ),
        ),
      if (r != null &&
          (branch == 'out_of_scope' || branch == 'smalltalk') &&
          r.suggestions.isNotEmpty)
        _Suggestions(items: r.suggestions, onAsk: onAsk),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) Gap(12.h),
          child,
        ],
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String? branch;

  const _StatusCard({required this.branch});

  String get _status => switch (branch) {
    'account' || 'info' => LocaleKeys.assistantStatusReading.tr(),
    'results' => LocaleKeys.assistantStatusThinking.tr(),
    'request' => LocaleKeys.assistantStatusRequest.tr(),
    'search' || 'refine' => LocaleKeys.assistantStatusSearching.tr(),
    _ => LocaleKeys.assistantStatusUnderstanding.tr(),
  };

  @override
  Widget build(BuildContext context) {
    Widget bar(double factor) => FractionallySizedBox(
      widthFactor: factor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 12.h,
        decoration: BoxDecoration(
          color: Colour.subtle,
          borderRadius: BorderRadius.circular(6.r),
        ),
      ),
    );
    return MarketCard(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18.r, color: Colour.primary),
              Gap(8.w),
              Expanded(child: Text(_status, style: _metaStyle)),
            ],
          ),
          Gap(12.h),
          bar(0.92),
          Gap(8.h),
          bar(0.75),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final AssistantTurnError error;
  final VoidCallback onRetry;

  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => MarketCard(
    padding: EdgeInsets.all(16.r),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 18.r, color: Colour.error),
            Gap(8.w),
            Expanded(
              child: Text(
                error == AssistantTurnError.rateLimited
                    ? LocaleKeys.assistantErrorsRateLimited.tr()
                    : LocaleKeys.assistantErrorsFailed.tr(),
                style: AppTextStyle.lightBodyMediumRegular.copyWith(
                  color: Colour.error,
                ),
              ),
            ),
          ],
        ),
        Gap(12.h),
        _IconButton(
          icon: Icons.refresh_rounded,
          label: LocaleKeys.assistantRetry.tr(),
          onPressed: onRetry,
          outline: true,
        ),
      ],
    ),
  );
}

/// "Quanh Hoàng Mai" / "Gần bạn"; đã nới vị trí thì nói rõ kết quả ở xa hơn / online.
class _NearLine extends StatelessWidget {
  final AssistantResult result;

  const _NearLine({required this.result});

  @override
  Widget build(BuildContext context) {
    final near = result.near!;
    // Không hiện bán kính; chỉ 2 phần đầu của địa chỉ.
    final label = near.label.split(',').take(2).join(',').trim();
    final args = {'label': label};
    final text = result.nearRelaxed
        ? (near.fromGps
              ? LocaleKeys.assistantNearYouRelaxed.tr()
              : LocaleKeys.assistantNearRelaxed.tr(namedArgs: args))
        : (near.fromGps
              ? LocaleKeys.assistantNearYou.tr()
              : LocaleKeys.assistantNear.tr(namedArgs: args));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 18.r,
          color: Colour.textTertiary,
        ),
        Gap(6.w),
        Expanded(child: Text(text, style: _metaStyle)),
      ],
    );
  }
}

/// Câu "gần tôi": web xin quyền vị trí của trình duyệt; app chưa có định vị → gợi ý
/// khách nói tên khu vực (cách web gợi ý khi không lấy được vị trí).
class _LocationHint extends StatelessWidget {
  const _LocationHint();

  @override
  Widget build(BuildContext context) => MarketCard(
    padding: EdgeInsets.all(16.r),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on_outlined, size: 20.r, color: Colour.primary),
        Gap(10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.assistantLocationTitle.tr(),
                style: AppTextStyle.lightBodyLargeMedium.copyWith(
                  color: Colour.textPrimary,
                ),
              ),
              Gap(4.h),
              Text(LocaleKeys.assistantLocationHint.tr(), style: _metaStyle),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Suggestions extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onAsk;

  const _Suggestions({required this.items, required this.onAsk});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        LocaleKeys.assistantTryAsking.tr(),
        style: AppTextStyle.lightBodyMediumMedium.copyWith(
          color: Colour.textSecondary,
        ),
      ),
      Gap(8.h),
      Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          for (final s in items)
            MarketFilterChip(label: s, selected: false, onTap: () => onAsk(s)),
        ],
      ),
    ],
  );
}

/// Form Post Request điền sẵn từ câu khách nói (web `RequestDraftPanel` nhúng form ngay
/// trong chat). App tóm tắt bản nháp ở đây, bấm nút thì mở màn Review để sửa + đăng.
class AssistantRequestDraftPanel extends StatelessWidget {
  final RequestDraftEntity draft;
  final ValueChanged<RequestDraftEntity> onReview;

  const AssistantRequestDraftPanel({
    super.key,
    required this.draft,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final v = draft.values;
    final locale = context.locale.languageCode;
    final rows = <(String, String?)>[
      (
        LocaleKeys.heardRowCategory.tr(),
        RequestFormatters.categories(draft.assistant.categoryIds),
      ),
      (LocaleKeys.heardRowWhere.tr(), RequestFormatters.where(v)),
      (LocaleKeys.heardRowWhen.tr(), RequestFormatters.when(v, locale)),
      (LocaleKeys.heardRowBudget.tr(), RequestFormatters.budget(v)),
    ];
    final suggestion = draft.assistant.suggestion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (suggestion.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: Colour.mutedWeb,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  size: 18.r,
                  color: Colour.primary,
                ),
                Gap(8.w),
                Expanded(
                  child: Text(
                    LocaleKeys.assistantRequestSuggestion.tr(
                      namedArgs: {'text': suggestion},
                    ),
                    style: _metaStyle,
                  ),
                ),
              ],
            ),
          ),
          Gap(12.h),
        ],
        MarketCard(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                LocaleKeys.heardRowWhat.tr(),
                style: AppTextStyle.lightBodySmallMedium.copyWith(
                  color: Colour.textSecondary,
                ),
              ),
              Gap(4.h),
              Text(
                v.description,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle,
              ),
              for (final (label, value) in rows) ...[
                Gap(10.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96.w,
                      child: Text(
                        label,
                        style: AppTextStyle.lightBodyMediumRegular.copyWith(
                          color: Colour.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value ?? LocaleKeys.heardNotSpecified.tr(),
                        style: AppTextStyle.lightBodyMediumMedium.copyWith(
                          color: value == null
                              ? Colour.textTertiary
                              : Colour.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              Gap(16.h),
              MarketButton(
                label: LocaleKeys.assistantReviewRequest.tr(),
                onPressed: () => onReview(draft),
                large: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nút nhỏ có icon (primary / viền).
class _IconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool outline;

  const _IconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyle.lightBodyMediumMedium;
    final padding = EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18.r),
        Gap(6.w),
        Text(label),
      ],
    );
    return outline
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colour.textPrimary,
              side: const BorderSide(color: Colour.lineStrong),
              padding: padding,
              shape: shape,
              textStyle: style,
            ),
            child: child,
          )
        : FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colour.buttonPrimary,
              foregroundColor: Colors.white,
              padding: padding,
              shape: shape,
              textStyle: style,
            ),
            child: child,
          );
  }
}
