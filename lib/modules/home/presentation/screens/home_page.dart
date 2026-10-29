import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/themes/theme.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/matching_providers_page_args.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/post_request_flow_args.dart';

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

/// Trang chủ = hero "What do you need today?" của web (home-marketplace), luồng theo
/// prototype: nói → "Here's what I heard"; gõ / gợi ý → danh sách provider; thẻ gợi ý →
/// "Here's what I heard"; menu ☰ → My requests / Messages / Browse providers / Recent.
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

  /// Thẻ gợi ý → thẳng "Here's what I heard" (prototype: prompt → Understood).
  void _openHeard(String text) {
    context.push(
      RouteName.requestHeard,
      extra: PostRequestFlowArgs(text: text),
    );
  }

  /// Gõ / chọn gợi ý / tìm gần đây → danh sách provider cho câu đó (prototype "Voice
  /// search results"); AI vẫn phân tích nền, back về "Here's what I heard".
  void _search(String text, List<String> attachments) {
    context.read<HomeBloc>().add(HomeSearchRecorded(text));
    context.push(
      RouteName.matchingProviders,
      extra: MatchingProvidersPageArgs(
        start: PostRequestFlowArgs(text: text, attachmentPaths: attachments),
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
                      onTap: () => context.go(RouteName.myRequests),
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
                                onSend: (text) =>
                                    _search(text, _takeAttachments()),
                                onFill: (text) =>
                                    _composerKey.currentState?.setText(text),
                              )
                            : state.showRecent
                            ? HomeRecentSearches(
                                items: state.recentSearches,
                                onSend: (text) =>
                                    _search(text, _takeAttachments()),
                                onFill: (text) =>
                                    _composerKey.currentState?.setText(text),
                              )
                            : null;
                        if (list == null) {
                          return Column(
                            children: [
                              const Expanded(child: HomeGreeting()),
                              HomeSuggestionList(onSelected: _openHeard),
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
