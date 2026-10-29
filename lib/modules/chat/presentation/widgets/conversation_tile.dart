import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/components/initials_avatar.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/conversation_entity.dart';
import '../chat_formatters.dart';

/// Một dòng hội thoại: avatar, tên, giờ, xem trước tin cuối, badge chưa đọc.
class ConversationTile extends StatelessWidget {
  final ConversationEntity conversation;
  final int myUserId;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.myUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale.languageCode;
    final c = conversation;
    final unread = c.unreadCount;
    final isVoice = c.lastType == ChatMessageType.voice;
    final fromPartner = c.lastSenderId != myUserId;
    final source = ChatFormatters.languageName(c.lastSourceLang, locale);
    final showAutoTranslated =
        fromPartner &&
        source != null &&
        !(c.lastSourceLang ?? '').startsWith(locale);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialsAvatar(
              name: c.partnerName,
              imageUrl: c.partnerAvatar,
              colorSeed: c.partnerId,
              size: 46.r,
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.partnerName.isEmpty ? '—' : c.partnerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.lightBodyMediumBold.copyWith(
                            color: theme.textPrimary(context),
                          ),
                        ),
                      ),
                      if (c.lastAt != null)
                        Text(
                          ChatFormatters.listTime(c.lastAt!, locale),
                          style: AppTextStyle.lightBodySmallRegular.copyWith(
                            color: theme.textSecondary(context),
                          ),
                        ),
                    ],
                  ),
                  Gap(3.h),
                  Row(
                    children: [
                      if (isVoice) ...[
                        Icon(
                          Icons.mic_none_rounded,
                          size: 15.r,
                          color: theme.textPrimary(context),
                        ),
                        Gap(3.w),
                      ],
                      Expanded(
                        child: Text(
                          ChatFormatters.preview(c, myUserId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.lightBodyMediumRegular.copyWith(
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: theme.textPrimary(context),
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        Gap(8.w),
                        Container(
                          constraints: BoxConstraints(minWidth: 20.r),
                          height: 20.r,
                          padding: EdgeInsets.symmetric(horizontal: 6.w),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.textPrimary(context),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: AppTextStyle.lightBodyXSmallBold.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (showAutoTranslated) ...[
                    Gap(2.h),
                    Text(
                      LocaleKeys.messagesAutoTranslated.tr(args: [source]),
                      style: AppTextStyle.lightBodySmallRegular.copyWith(
                        color: theme.textSecondary(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
