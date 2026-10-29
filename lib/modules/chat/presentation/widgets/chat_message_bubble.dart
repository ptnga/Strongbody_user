import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/request_formatters.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/widgets/common/voice_note_player.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/chat_session_entity.dart';
import '../chat_formatters.dart';
import 'chat_offer_strip.dart';

/// Bong bóng tin: của mình (nền tối, bên phải) / của partner (nền trắng, bên trái).
/// Tin partner có bản dịch → hiện bản dịch + "Translated from X · show original".
class ChatMessageBubble extends StatelessWidget {
  final ChatMessageEntity message;
  final bool mine;
  final ChatTranslation? translation;
  final bool showOriginal;
  final bool read;
  final VoidCallback onToggleOriginal;

  /// Provider của hội thoại (thanh toán offer trong chat).
  final ChatPartner? partner;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.onToggleOriginal,
    this.translation,
    this.showOriginal = false,
    this.read = false,
    this.partner,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.languageCode;
    final t = translation;
    final hasTranslation =
        !mine && t != null && (t.text != null || t.audioUrl != null);
    final translated = hasTranslation && !showOriginal;
    final voice = message.voice;
    final original = message.type == ChatMessageType.voice
        ? (voice?.transcript ?? '')
        : message.text;
    final body = translated && t.text != null ? t.text! : original;
    final audio = translated && t.audioUrl != null ? t.audioUrl! : voice?.url;
    final foreground = mine ? Colors.white : theme.textPrimary(context);
    final source = ChatFormatters.languageName(
      t?.sourceLang ?? voice?.sourceLang,
      locale,
    );

    final content = <Widget>[
      if (message.type == ChatMessageType.voice && audio != null)
        VoiceNotePlayer(
          key: ValueKey(audio),
          path: audio,
          duration: voice?.duration,
          onDark: mine,
        ),
      if (message.type == ChatMessageType.offer && message.offer != null)
        _OfferContent(offer: message.offer!, mine: mine, partner: partner)
      else if (message.type == ChatMessageType.image ||
          message.type == ChatMessageType.file)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              message.type == ChatMessageType.image
                  ? Icons.image_outlined
                  : Icons.attach_file_rounded,
              size: 18.r,
              color: foreground,
            ),
            Gap(6.w),
            Flexible(
              child: Text(
                message.fileName ??
                    (message.type == ChatMessageType.image
                        ? LocaleKeys.messagesPhoto.tr()
                        : LocaleKeys.messagesFile.tr()),
                style: AppTextStyle.lightBodyMediumRegular.copyWith(
                  color: foreground,
                ),
              ),
            ),
          ],
        )
      else if (body.isNotEmpty) ...[
        if (message.type == ChatMessageType.voice) Gap(10.h),
        Text(
          body,
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            height: 1.4,
            color: foreground,
          ),
        ),
      ] else if (message.type == ChatMessageType.other)
        Text(
          LocaleKeys.messagesOtherType.tr(),
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            fontStyle: FontStyle.italic,
            color: foreground,
          ),
        ),
      if (hasTranslation) ...[
        Gap(8.h),
        GestureDetector(
          onTap: onToggleOriginal,
          child: Text(
            [
              source != null
                  ? LocaleKeys.chatTranslatedFrom.tr(args: [source])
                  : LocaleKeys.chatTranslated.tr(),
              showOriginal
                  ? LocaleKeys.chatShowTranslation.tr()
                  : LocaleKeys.chatShowOriginal.tr(),
            ].join(' · '),
            style: AppTextStyle.lightBodySmallRegular.copyWith(
              color: theme.textSecondary(context),
              decoration: TextDecoration.underline,
              decorationColor: theme.textSecondary(context),
            ),
          ),
        ),
      ],
    ];

    final meta = [
      if (message.isPending)
        LocaleKeys.chatSending.tr()
      else
        ChatFormatters.time(message.createdAt, locale),
      if (mine && read && !message.isPending) LocaleKeys.chatRead.tr(),
    ].join(' · ');

    final radius = Radius.circular(16.r);
    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: Opacity(
            opacity: message.isPending ? 0.7 : 1,
            child: Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: mine ? theme.secondary(context) : theme.surface(context),
                border: mine ? null : Border.all(color: theme.border(context)),
                borderRadius: BorderRadius.only(
                  topLeft: radius,
                  topRight: radius,
                  bottomLeft: mine ? radius : Radius.circular(4.r),
                  bottomRight: mine ? Radius.circular(4.r) : radius,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: content,
              ),
            ),
          ),
        ),
        Gap(4.h),
        Text(
          meta,
          style: AppTextStyle.lightBodyXSmallRegular.copyWith(
            color: theme.textSecondary(context),
          ),
        ),
      ],
    );
  }
}

class _OfferContent extends StatelessWidget {
  final ChatOfferEntity offer;
  final bool mine;
  final ChatPartner? partner;

  const _OfferContent({required this.offer, required this.mine, this.partner});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = mine ? Colors.white : theme.textPrimary(context);
    final (label, _) = offerStatusLabel(offer);
    return GestureDetector(
      onTap: () => openChatOffer(context, offer, partner: partner),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${LocaleKeys.chatOfferTitle.tr()} · $label',
            style: AppTextStyle.lightBodySmallSemiBold.copyWith(
              color: mine
                  ? Colors.white.withValues(alpha: 0.8)
                  : theme.textSecondary(context),
            ),
          ),
          Gap(4.h),
          if (offer.title.isNotEmpty)
            Text(
              offer.title,
              style: AppTextStyle.lightBodyMediumBold.copyWith(color: color),
            ),
          if (offer.price case final p? when p > 0)
            Text(
              RequestFormatters.money(p, 'USD'),
              style: AppTextStyle.lightBodyXLargeBold.copyWith(color: color),
            ),
        ],
      ),
    );
  }
}
