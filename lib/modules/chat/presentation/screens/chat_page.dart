import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';
import 'package:strongbody_buyer/modules/auth/presentation/widgets/auth_sheet.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../domain/entities/chat_message_entity.dart';
import '../bloc/chat/chat_bloc.dart';
import '../chat_formatters.dart';
import '../chat_page_args.dart';
import '../chat_read_aloud.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_header.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_offer_strip.dart';

/// Chat 1:1 với provider — nói / gõ bằng ngôn ngữ của mình, dịch tự động khi bật.
class ChatPage extends StatefulWidget {
  final ChatPageArgs args;

  const ChatPage({super.key, required this.args});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _scroll = ScrollController();

  /// Account › Read replies aloud: chỉ đọc tin partner tới sau lúc mở màn.
  ChatReadAloud? _readAloud;
  final _openedAt = DateTime.now();
  final _readIds = <String>{};
  int _shownNoticeId = 0;

  static const _background = Color(0xFFF4F6F9);

  @override
  void initState() {
    super.initState();
    AppAnalytics.capture(AnalyticsEvents.chatOpened, {
      'source': widget.args.source,
      'partner_id': widget.args.partnerId,
      'from_offer': widget.args.focusOfferId != null,
    });
    _scroll.addListener(() {
      final p = _scroll.position;
      // reverse: true → cuối cuộn = tin cũ nhất.
      if (p.pixels >= p.maxScrollExtent - 300) {
        context.read<ChatBloc>().add(const ChatOlderRequested());
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _readAloud?.dispose();
    super.dispose();
  }

  void _readNewReplies(ChatState state) {
    if (!getIt<UserPreferences>().readRepliesAloud) return;
    final partnerId = state.session?.partner.id;
    for (final message in state.messages.take(5)) {
      if (message.senderId != partnerId ||
          message.isPending ||
          !message.createdAt.isAfter(_openedAt) ||
          !_readIds.add(message.id)) {
        continue;
      }
      // Đang dịch: chờ bản dịch tới (kênh `_translation`) rồi đọc bản tốt nhất có.
      Future.delayed(
        state.autoTranslate ? const Duration(seconds: 3) : Duration.zero,
        () {
          if (!mounted) return;
          final current = context.read<ChatBloc>().state;
          final t = current.autoTranslate
              ? current.translations[message.id]
              : null;
          final reader = _readAloud ??= getIt<ChatReadAloud>();
          if (message.type == ChatMessageType.voice) {
            reader.enqueue(audioUrl: t?.audioUrl ?? message.voice?.url);
          } else {
            reader.enqueue(
              text: t?.text ?? message.text,
              language: t?.text != null ? context.locale.languageCode : null,
            );
          }
        },
      );
    }
  }

  void _onNotice(ChatNotice notice) {
    ToastUtil.showError(switch (notice) {
      ChatNotice.sendFailed => LocaleKeys.chatSendFailed.tr(),
      ChatNotice.voiceFailed => LocaleKeys.chatVoiceFailed.tr(),
      ChatNotice.micDenied => LocaleKeys.chatMicDenied.tr(),
      ChatNotice.voiceTooShort => LocaleKeys.chatVoiceTooShort.tr(),
      ChatNotice.translateFailed => LocaleKeys.chatTranslateFailed.tr(),
    });
  }

  /// Bật dịch cần đồng ý chia sẻ tin cho dịch vụ dịch AI (BE chặn nếu chưa có consent).
  Future<void> _toggleTranslate(ChatState state) async {
    final bloc = context.read<ChatBloc>();
    if (state.autoTranslate) {
      bloc.add(const ChatTranslateToggled());
      return;
    }
    final language =
        ChatFormatters.languageName(
          context.locale.languageCode,
          context.locale.languageCode,
        ) ??
        context.locale.languageCode;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.chatConsentTitle.tr()),
        content: Text(LocaleKeys.chatConsentMessage.tr(args: [language])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(LocaleKeys.chatCancel.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(LocaleKeys.chatConsentAgree.tr()),
          ),
        ],
      ),
    );
    if (agreed == true) bloc.add(const ChatTranslateToggled());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.languageCode;
    return BlocConsumer<ChatBloc, ChatState>(
      listenWhen: (a, b) =>
          (a.noticeId != b.noticeId && b.notice != null) ||
          a.messages != b.messages,
      listener: (context, state) {
        if (state.notice != null && state.noticeId != _shownNoticeId) {
          _shownNoticeId = state.noticeId;
          _onNotice(state.notice!);
        }
        _readNewReplies(state);
      },
      builder: (context, state) {
        final session = state.session;
        final partnerName = (session?.partner.name.isNotEmpty ?? false)
            ? session!.partner.name
            : (widget.args.name ?? '');
        final partnerAvatar = session?.partner.avatar ?? widget.args.avatar;
        final language = ChatFormatters.languageName(
          state.partnerLanguage,
          locale,
        );
        final subtitle = [
          if (widget.args.profession case final p? when p.isNotEmpty) p,
          if (language != null) LocaleKeys.chatSpeaks.tr(args: [language]),
        ].join(' · ');
        final first = ChatFormatters.firstName(partnerName);
        final footer = [
          LocaleKeys.chatFooterAny.tr(),
          if (language != null && first.isNotEmpty)
            LocaleKeys.chatFooterHears.tr(args: [first, language]),
        ].join(' · ');
        final ready = state.status == ChatStatus.ready;

        return Scaffold(
          backgroundColor: _background,
          body: Column(
            children: [
              Container(
                color: theme.surface(context),
                child: SafeArea(
                  bottom: false,
                  child: ChatHeader(
                    partnerId: widget.args.partnerId,
                    name: partnerName,
                    avatar: partnerAvatar,
                    subtitle: subtitle,
                    translateOn: state.autoTranslate,
                    translateBusy: state.savingSettings,
                    onTranslate: ready ? () => _toggleTranslate(state) : null,
                    onBack: () => context.pop(),
                  ),
                ),
              ),
              if (state.offer != null)
                ChatOfferStrip(offer: state.offer!, partner: session?.partner)
              else
                Divider(height: 1, color: theme.border(context)),
              Expanded(child: _body(context, state, partnerName)),
              if (ready)
                ChatComposer(
                  hint: first.isEmpty
                      ? LocaleKeys.chatComposerHintGeneric.tr()
                      : LocaleKeys.chatComposerHint.tr(args: [first]),
                  footer: footer,
                  enabled: ready,
                  recording: state.recording,
                  recordElapsed: state.recordElapsed,
                  onSend: (text) =>
                      context.read<ChatBloc>().add(ChatTextSent(text)),
                  onRecordStart: () =>
                      context.read<ChatBloc>().add(const ChatRecordStarted()),
                  onRecordSend: () =>
                      context.read<ChatBloc>().add(const ChatRecordFinished()),
                  onRecordCancel: () =>
                      context.read<ChatBloc>().add(const ChatRecordCancelled()),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, ChatState state, String partnerName) {
    final theme = Theme.of(context);
    final locale = context.locale.languageCode;
    switch (state.status) {
      case ChatStatus.connecting:
        return const Center(child: CupertinoActivityIndicator());
      case ChatStatus.signedOut || ChatStatus.failure:
        final signedOut = state.status == ChatStatus.signedOut;
        return Center(
          child: Padding(
            padding: EdgeInsets.all(32.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  signedOut
                      ? LocaleKeys.chatSignedOut.tr()
                      : LocaleKeys.chatConnectError.tr(),
                  textAlign: TextAlign.center,
                  style: AppTextStyle.lightBodyMediumRegular.copyWith(
                    color: theme.textSecondary(context),
                  ),
                ),
                Gap(16.h),
                FilledButton(
                  onPressed: () async {
                    final bloc = context.read<ChatBloc>();
                    if (signedOut &&
                        !await showAuthSheet(context, source: 'chat')) {
                      return;
                    }
                    bloc.add(const ChatStarted());
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.secondary(context),
                  ),
                  child: Text(
                    signedOut
                        ? LocaleKeys.authSignIn.tr()
                        : LocaleKeys.chatRetry.tr(),
                  ),
                ),
              ],
            ),
          ),
        );
      case ChatStatus.ready:
        break;
    }

    final messages = state.messages;
    final me = state.session?.myUserId;
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.r),
          child: Text(
            LocaleKeys.chatEmpty.tr(
              args: [ChatFormatters.firstName(partnerName)],
            ),
            textAlign: TextAlign.center,
            style: AppTextStyle.lightBodyMediumRegular.copyWith(
              height: 1.45,
              color: theme.textSecondary(context),
            ),
          ),
        ),
      );
    }
    final readId = state.readMessageId;
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      itemCount: messages.length + (state.loadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return Padding(
            padding: EdgeInsets.all(12.r),
            child: const CupertinoActivityIndicator(),
          );
        }
        final message = messages[index];
        final older = index + 1 < messages.length ? messages[index + 1] : null;
        final newDay =
            older == null ||
            !ChatFormatters.sameDay(older.createdAt, message.createdAt);
        final mine = message.senderId == me;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (newDay)
              _DaySeparator(
                label: ChatFormatters.dayLabel(message.createdAt, locale),
              ),
            Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: ChatMessageBubble(
                  key: ValueKey(message.id),
                  message: message,
                  mine: mine,
                  translation: state.autoTranslate
                      ? state.translations[message.id]
                      : null,
                  showOriginal: state.showOriginal.contains(message.id),
                  read: message.id == readId,
                  partner: state.session?.partner,
                  onToggleOriginal: () => context.read<ChatBloc>().add(
                    ChatOriginalToggled(message.id),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DaySeparator extends StatelessWidget {
  final String label;

  const _DaySeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: theme.border(context).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: AppTextStyle.lightBodySmallRegular.copyWith(
              color: theme.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}
