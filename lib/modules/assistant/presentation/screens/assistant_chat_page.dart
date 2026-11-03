import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/core/design_tokens/colour.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_draft_entity.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/post_request_flow_args.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/voice_request_page_args.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/market_ui.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/widgets/medical_travel_widgets.dart';

import '../../domain/entities/assistant_entities.dart';
import '../assistant_page_args.dart';
import '../bloc/assistant_chat_cubit.dart';
import '../widgets/assistant_composer.dart';
import '../widgets/assistant_message.dart';

/// Chat trợ lý AI (web `/ai-assistant`, ô hỏi ở hero trang chủ): tìm chuyên gia / dịch
/// vụ, đăng request với form điền sẵn, hỏi về StrongBody — hỏi tiếp bao nhiêu lượt cũng
/// được. Mở từ ô nhập ở Home và hero các trang Social Market.
class AssistantChatPage extends StatefulWidget {
  final AssistantPageArgs args;

  const AssistantChatPage({super.key, required this.args});

  @override
  State<AssistantChatPage> createState() => _AssistantChatPageState();
}

class _AssistantChatPageState extends State<AssistantChatPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Câu đầu được gửi ngay lúc tạo cubit (trước khi listener gắn) → cuộn xuống sau frame đầu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Có lượt mới → cuộn xuống cuối (web `endRef.scrollIntoView`).
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _voice(BuildContext context) async {
    final cubit = context.read<AssistantChatCubit>();
    final text = await context.push<String>(
      RouteName.voiceRequest,
      extra: const VoiceRequestPageArgs(refine: true, source: 'assistant'),
    );
    if (text != null && text.trim().isNotEmpty) {
      cubit.ask(text, source: 'voice');
    }
  }

  /// Bản nháp request (nhánh request / "Đăng yêu cầu") → màn Review để sửa rồi đăng.
  void _review(RequestDraftEntity draft, String origin) {
    AppAnalytics.capture(AnalyticsEvents.assistantRequestReviewOpened, {
      'origin': origin,
      'category_id': draft.assistant.categoryIds.firstOrNull,
    });
    context.push(
      RouteName.requestReview,
      extra: PostRequestFlowArgs(
        draft: draft,
        attachmentPaths: widget.args.attachmentPaths,
      ),
    );
  }

  Future<void> _confirmNew(BuildContext context) async {
    final cubit = context.read<AssistantChatCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.assistantNewChatTitle.tr()),
        content: Text(LocaleKeys.assistantNewChatBody.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(LocaleKeys.assistantCancel.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colour.error),
            child: Text(LocaleKeys.assistantConfirmNewChat.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.startNew();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colour.mutedWeb,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: BlocConsumer<AssistantChatCubit, AssistantChatState>(
            listenWhen: (a, b) => a.turns.length != b.turns.length,
            listener: (context, state) => _scrollToEnd(),
            builder: (context, state) {
              final cubit = context.read<AssistantChatCubit>();
              final turns = state.turns;
              return Column(
                children: [
                  _TopBar(
                    onNewChat: turns.isEmpty
                        ? null
                        : () => _confirmNew(context),
                  ),
                  Expanded(
                    child: turns.isEmpty && !state.busy
                        ? _EmptyChat(
                            onAsk: (t) => cubit.ask(t, source: 'example'),
                          )
                        : ListView.separated(
                            controller: _scroll,
                            padding: EdgeInsets.fromLTRB(
                              16.w,
                              16.h,
                              16.w,
                              24.h,
                            ),
                            itemCount: turns.length,
                            separatorBuilder: (_, _) => Gap(16.h),
                            itemBuilder: (context, i) => switch (turns[i]) {
                              AssistantUserTurn(:final content) =>
                                AssistantUserBubble(text: content),
                              final AssistantReplyTurn turn => AssistantReply(
                                turn: turn,
                                isLast: i == turns.length - 1,
                                onAsk: (t) =>
                                    cubit.ask(t, source: 'suggestion'),
                                onRetry: cubit.retry,
                                onPostRequest: () => cubit.postRequest(i),
                                onReviewRequest: _review,
                              ),
                            },
                          ),
                  ),
                  ColoredBox(
                    color: Colour.mutedWeb,
                    child: AssistantComposer(
                      busy: state.busy,
                      onSend: (t) => cubit.ask(t),
                      onVoice: () => _voice(context),
                      onStop: cubit.stop,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Back · "StrongBody assistant" · "New chat" (khi đã có hội thoại).
class _TopBar extends StatelessWidget {
  final VoidCallback? onNewChat;

  const _TopBar({required this.onNewChat});

  @override
  Widget build(BuildContext context) => Container(
    height: 52.h,
    color: Colour.surface,
    padding: EdgeInsets.symmetric(horizontal: 8.w),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20.r,
            color: Colour.textPrimary,
          ),
        ),
        Expanded(
          child: Text(
            LocaleKeys.assistantTitle.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.lightBodyXLargeBold.copyWith(
              color: Colour.textPrimary,
            ),
          ),
        ),
        if (onNewChat != null)
          TextButton.icon(
            onPressed: onNewChat,
            icon: Icon(Icons.add_rounded, size: 18.r),
            label: Text(LocaleKeys.assistantNewChat.tr()),
            style: TextButton.styleFrom(
              foregroundColor: Colour.textPrimary,
              textStyle: AppTextStyle.lightBodyMediumMedium,
            ),
          ),
      ],
    ),
  );
}

/// Chat trống: hướng dẫn + chip câu ví dụ (câu ví dụ của hero).
class _EmptyChat extends StatelessWidget {
  final ValueChanged<String> onAsk;

  const _EmptyChat({required this.onAsk});

  static final _ellipsis = RegExp(r'(\.{3}|…)$');

  @override
  Widget build(BuildContext context) {
    final examples = [
      LocaleKeys.assistantExample1.tr(),
      LocaleKeys.assistantExample2.tr(),
      LocaleKeys.assistantExample3.tr(),
      LocaleKeys.assistantExample4.tr(),
    ];
    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        MarketCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.assistantEmptyHint.tr(),
                style: AppTextStyle.lightBodyLargeRegular.copyWith(
                  color: Colour.textSecondary,
                  height: 1.5,
                ),
              ),
              Gap(16.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  for (final ex in examples)
                    MarketFilterChip(
                      label: ex,
                      selected: false,
                      onTap: () => onAsk(ex.replaceAll(_ellipsis, '')),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
