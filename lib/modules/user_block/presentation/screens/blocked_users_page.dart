import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:strongbody_buyer/components/initials_avatar.dart';
import 'package:strongbody_buyer/core/components/app_icon.dart';
import 'package:strongbody_buyer/core/constants/app_svg.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/core/utils/toast_util.dart';

import '../../domain/entities/blocked_user.dart';
import '../bloc/blocked_users_bloc.dart';

/// Account › Blocked users: danh sách đã chặn + bỏ chặn (`GET /buyer/user_blocks/my-blocked`).
class BlockedUsersPage extends StatelessWidget {
  const BlockedUsersPage({super.key});

  static const _background = Color(0xFFF4F6F9);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: theme.surface(context),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: AppIcon(
            AppSvg.arrowBack,
            size: 24.r,
            color: theme.textPrimary(context),
          ),
        ),
        title: Text(
          LocaleKeys.blockedUsersTitle.tr(),
          style: AppTextStyle.lightHeadingSmall.copyWith(
            color: theme.textPrimary(context),
          ),
        ),
      ),
      body: BlocConsumer<BlockedUsersBloc, BlockedUsersState>(
        listenWhen: (a, b) => a.noticeId != b.noticeId,
        listener: (context, state) {
          if (state.notice == BlockedUsersNotice.unblockFailed) {
            ToastUtil.showError(LocaleKeys.chatUnblockFailed.tr());
          }
        },
        builder: (context, state) {
          switch (state.status) {
            case BlockedUsersStatus.loading:
              return const Center(child: CupertinoActivityIndicator());
            case BlockedUsersStatus.failure:
              return _Message(LocaleKeys.blockedUsersError.tr());
            case BlockedUsersStatus.ready:
              break;
          }
          if (state.items.isEmpty) {
            return _Message(LocaleKeys.blockedUsersEmpty.tr());
          }
          return RefreshIndicator(
            onRefresh: () async =>
                context.read<BlockedUsersBloc>().add(const BlockedUsersStarted()),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
              itemCount: state.items.length,
              separatorBuilder: (_, _) => Gap(10.h),
              itemBuilder: (context, index) {
                final user = state.items[index];
                return _BlockedUserTile(
                  user: user,
                  busy: state.busyUserId == user.userId,
                  onUnblock: () => context.read<BlockedUsersBloc>().add(
                    BlockedUsersUnblockRequested(user),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  final BlockedUser user;
  final bool busy;
  final VoidCallback onUnblock;

  const _BlockedUserTile({
    required this.user,
    required this.busy,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: theme.surface(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: theme.border(context)),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            name: user.fullName,
            imageUrl: user.avatarUrl,
            colorSeed: user.userId,
            size: 44.r,
          ),
          Gap(12.w),
          Expanded(
            child: Text(
              user.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.lightBodyMediumSemiBold.copyWith(
                color: theme.textPrimary(context),
              ),
            ),
          ),
          Gap(8.w),
          OutlinedButton(
            onPressed: busy ? null : onUnblock,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.textPrimary(context),
              side: BorderSide(color: theme.border(context)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: busy
                ? const CupertinoActivityIndicator(radius: 8)
                : Text(LocaleKeys.blockedUsersUnblock.tr()),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;

  const _Message(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            color: theme.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
