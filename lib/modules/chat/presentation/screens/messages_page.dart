import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/components/initials_avatar.dart';
import 'package:strongbody_buyer/core/domain/global_dependencies.dart';
import 'package:strongbody_buyer/core/l10n/locale_keys.g.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/modules/auth/presentation/widgets/auth_sheet.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/voice_request_page_args.dart';
import 'package:strongbody_buyer/core/themes/app_text_style.dart';

import '../bloc/conversations/conversations_bloc.dart';
import '../chat_page_args.dart';
import '../widgets/conversation_tile.dart';

/// Tab "Messages" — danh sách hội thoại (Multime `ChatHomepage`) + tìm nhà cung cấp.
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final p = _scroll.position;
      if (p.pixels >= p.maxScrollExtent - 300) {
        context.read<ConversationsBloc>().add(const ConversationsLoadMore());
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openChat(ChatPageArgs args) async {
    final bloc = context.read<ConversationsBloc>();
    await context.push(RouteName.chat, extra: args);
    // Quay lại: số chưa đọc / tin cuối đã đổi.
    if (mounted) bloc.add(const ConversationsStarted());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.surface(context),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.messagesTitle.tr(),
                      style: AppTextStyle.lightHeadingMedium.copyWith(
                        color: theme.textPrimary(context),
                      ),
                    ),
                    Gap(12.h),
                    _SearchField(
                      controller: _search,
                      onChanged: (q) => context.read<ConversationsBloc>().add(
                        ConversationsQueryChanged(q),
                      ),
                      // Mic đỏ = màn nói yêu cầu như Home (nút Speak).
                      onMic: () => context.push(
                        RouteName.voiceRequest,
                        extra: const VoiceRequestPageArgs(source: 'messages'),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.border(context)),
              Expanded(
                child: BlocBuilder<ConversationsBloc, ConversationsState>(
                  builder: (context, state) {
                    if (state.isFirstLoad) {
                      return const Center(child: CupertinoActivityIndicator());
                    }
                    final items = state.visibleItems;
                    final people = state.visiblePeople;
                    final searching = state.query.trim().length >= 2;
                    final me = gs.userId ?? 0;
                    final empty =
                        items.isEmpty && people.isEmpty && !state.isSearching;
                    return RefreshIndicator(
                      onRefresh: () async => context
                          .read<ConversationsBloc>()
                          .add(const ConversationsStarted()),
                      child: empty
                          ? _EmptyState(state: state, searching: searching)
                          : ListView(
                              controller: _scroll,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.only(bottom: 16.h),
                              children: [
                                for (final c in items)
                                  ConversationTile(
                                    key: ValueKey(c.channelId),
                                    conversation: c,
                                    myUserId: me,
                                    onTap: () => _openChat(
                                      ChatPageArgs(
                                        partnerId: c.partnerId,
                                        name: c.partnerName,
                                        avatar: c.partnerAvatar,
                                        source: 'messages',
                                      ),
                                    ),
                                  ),
                                if (state.isLoadingMore)
                                  Padding(
                                    padding: EdgeInsets.all(12.r),
                                    child: const CupertinoActivityIndicator(),
                                  ),
                                if (searching) ...[
                                  if (people.isNotEmpty || state.isSearching)
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        16.w,
                                        16.h,
                                        16.w,
                                        4.h,
                                      ),
                                      child: Text(
                                        LocaleKeys.messagesPeople.tr(),
                                        style: AppTextStyle.lightBodySmallBold
                                            .copyWith(
                                              color: theme.textSecondary(
                                                context,
                                              ),
                                            ),
                                      ),
                                    ),
                                  if (state.isSearching)
                                    Padding(
                                      padding: EdgeInsets.all(12.r),
                                      child: const CupertinoActivityIndicator(),
                                    ),
                                  for (final p in people)
                                    ListTile(
                                      key: ValueKey('user_${p.id}'),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                      ),
                                      leading: InitialsAvatar(
                                        name: p.name,
                                        imageUrl: p.avatar,
                                        colorSeed: p.id,
                                        size: 42.r,
                                      ),
                                      title: Text(
                                        p.name.isEmpty ? '—' : p.name,
                                        style: AppTextStyle.lightBodyMediumBold
                                            .copyWith(
                                              color: theme.textPrimary(context),
                                            ),
                                      ),
                                      onTap: () => _openChat(
                                        ChatPageArgs(
                                          partnerId: p.id,
                                          name: p.name,
                                          avatar: p.avatar,
                                          source: 'messages_search',
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onMic;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44.h,
      decoration: BoxDecoration(
        color: theme.muted(context),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Gap(12.w),
          Icon(
            Icons.search_rounded,
            size: 22.r,
            color: theme.textSecondary(context),
          ),
          Gap(8.w),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: AppTextStyle.lightBodyMediumRegular.copyWith(
                color: theme.textPrimary(context),
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: LocaleKeys.messagesSearchHint.tr(),
                hintStyle: AppTextStyle.lightBodyMediumRegular.copyWith(
                  color: theme.textSecondary(context),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onMic,
            icon: Icon(
              Icons.mic_none_rounded,
              size: 22.r,
              color: theme.primary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ConversationsState state;
  final bool searching;

  const _EmptyState({required this.state, required this.searching});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedOut = state.status == ConversationsStatus.signedOut;
    final failed = state.status == ConversationsStatus.failure;
    final title = signedOut || failed || searching
        ? null
        : LocaleKeys.messagesEmptyTitle.tr();
    final message = signedOut
        ? LocaleKeys.messagesSignedOut.tr()
        : failed
        ? LocaleKeys.messagesLoadError.tr()
        : searching
        ? LocaleKeys.messagesNoMatch.tr(args: [state.query.trim()])
        : LocaleKeys.messagesEmptyMessage.tr();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 56.h),
      children: [
        if (title != null) ...[
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyle.lightBodyXLargeBold.copyWith(
              color: theme.textPrimary(context),
            ),
          ),
          Gap(6.h),
        ],
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyle.lightBodyMediumRegular.copyWith(
            height: 1.45,
            color: theme.textSecondary(context),
          ),
        ),
        if (signedOut) ...[
          Gap(16.h),
          Center(
            child: FilledButton(
              onPressed: () async {
                final bloc = context.read<ConversationsBloc>();
                if (await showAuthSheet(context, source: 'messages')) {
                  bloc.add(const ConversationsStarted());
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.secondary(context),
              ),
              child: Text(LocaleKeys.authSignIn.tr()),
            ),
          ),
        ],
      ],
    );
  }
}
