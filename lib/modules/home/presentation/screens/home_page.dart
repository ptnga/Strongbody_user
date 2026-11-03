import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/modules/assistant/presentation/assistant_page_args.dart';

import '../bloc/home/home_bloc.dart';
import '../bloc/home_menu/home_menu_cubit.dart';
import '../home_composer_focus.dart';
import '../widgets/home_greeting.dart';
import '../widgets/home_menu_drawer.dart';
import '../widgets/home_new_offers_pill.dart';
import '../widgets/home_request_composer.dart';
import '../widgets/home_suggestion_list.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/home_typing_suggestions.dart';

/// Trang chủ = hero "What do you need today?" của web (home-marketplace). Như web live-v1
/// (hero → `/ai-assistant`): gõ / nói / chọn gợi ý / thẻ gợi ý → chat trợ lý AI (tìm
/// provider, form request điền sẵn, hỏi về StrongBody); menu ☰ → My requests / Messages /
/// Browse providers / Recent.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _composerKey = GlobalKey<HomeRequestComposerState>();

  @override
  void initState() {
    super.initState();
    HomeComposerFocus.pending.addListener(_focusComposer);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusComposer());
  }

  @override
  void dispose() {
    HomeComposerFocus.pending.removeListener(_focusComposer);
    super.dispose();
  }

  void _focusComposer() {
    if (HomeComposerFocus.pending.value == null || !mounted) return;
    // Chờ màn nói đóng xong rồi mới mở bàn phím.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final attachments = HomeComposerFocus.take();
      if (attachments == null || !mounted) return;
      _composerKey.currentState?.focusForTyping(attachments);
    });
  }

  /// Thẻ gợi ý → chat trợ lý với câu đó.
  void _openPrompt(String text) {
    AppAnalytics.capture(AnalyticsEvents.homePromptTapped, {'prompt': text});
    context.push(
      RouteName.assistant,
      extra: AssistantPageArgs(text: text, source: 'home_card'),
    );
  }

  /// Gõ / chọn gợi ý / tìm gần đây → chat trợ lý AI với câu đó (web hero → `/ai-assistant`).
  void _search(
    String text,
    List<String> attachments, {
    String source = 'composer',
  }) {
    AppAnalytics.capture(AnalyticsEvents.homeSearchSubmitted, {
      'source': source,
      'query_length': text.trim().length,
      'attachments_count': attachments.length,
    });
    context.read<HomeBloc>().add(HomeSearchRecorded(text));
    context.push(
      RouteName.assistant,
      extra: AssistantPageArgs(
        text: text,
        attachmentPaths: attachments,
        source: source == 'composer' ? 'home' : source,
      ),
    );
  }

  List<String> _takeAttachments() =>
      _composerKey.currentState?.takeAttachments() ?? const [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: BlocProvider(
        create: (_) => getIt<HomeMenuCubit>(),
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: theme.surface(context),
            resizeToAvoidBottomInset: true,
            drawer: const HomeMenuDrawer(),
            onDrawerChanged: (open) {
              if (open) context.read<HomeMenuCubit>().load();
            },
            body: SafeArea(
              child: Column(
                children: [
                  const HomeTopBar(),
                  BlocSelector<HomeBloc, HomeState, int>(
                    selector: (state) => state.newOffersCount,
                    builder: (context, count) => HomeNewOffersPill(
                      count: count,
                      onTap: () {
                        AppAnalytics.capture(
                          AnalyticsEvents.homeNewOffersTapped,
                          {'count': count},
                        );
                        context.go(RouteName.myRequests);
                      },
                    ),
                  ),
                  // Đang gõ → "Suggestions"; focus mà chưa gõ → "Recent searches";
                  // còn lại → lời chào + thẻ gợi ý.
                  Expanded(
                    child: BlocBuilder<HomeBloc, HomeState>(
                      buildWhen: (a, b) =>
                          a.typing != b.typing ||
                          a.showRecent != b.showRecent ||
                          a.recentSearches != b.recentSearches,
                      builder: (context, state) {
                        final typing = state.typing;
                        final Widget? list = typing != null
                            ? HomeTypingSuggestions(
                                seed: typing,
                                onSend: (text) => _search(
                                  text,
                                  _takeAttachments(),
                                  source: 'typing_suggestion',
                                ),
                                onFill: (text) =>
                                    _composerKey.currentState?.setText(text),
                              )
                            : state.showRecent
                            ? HomeRecentSearches(
                                items: state.recentSearches,
                                onSend: (text) => _search(
                                  text,
                                  _takeAttachments(),
                                  source: 'recent_search',
                                ),
                                onFill: (text) =>
                                    _composerKey.currentState?.setText(text),
                              )
                            : null;
                        if (list == null) {
                          return Column(
                            children: [
                              const Expanded(child: HomeGreeting()),
                              HomeSuggestionList(onSelected: _openPrompt),
                            ],
                          );
                        }
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: SingleChildScrollView(
                            reverse: true,
                            child: list,
                          ),
                        );
                      },
                    ),
                  ),
                  HomeRequestComposer(
                    key: _composerKey,
                    voiceToAssistant: true,
                    onSend: _search,
                    onTextChanged: (text) =>
                        context.read<HomeBloc>().add(HomeQueryChanged(text)),
                    onFocusChanged: (focused) => context.read<HomeBloc>().add(
                      HomeComposerFocusChanged(focused),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
