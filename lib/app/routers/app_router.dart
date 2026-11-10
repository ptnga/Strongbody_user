import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:strongbody_buyer/app/routers/app_navigator_key.dart';
import 'package:strongbody_buyer/app/routers/routers_name.dart';
import 'package:strongbody_buyer/components/app_bottom_nav.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
import 'package:strongbody_buyer/core/di/locator.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/modules/account/presentation/bloc/account/account_bloc.dart';
import 'package:strongbody_buyer/modules/account/presentation/bloc/lion_points/lion_points_bloc.dart';
import 'package:strongbody_buyer/modules/account/presentation/screens/account_page.dart';
import 'package:strongbody_buyer/modules/account/presentation/screens/lion_points_page.dart';
import 'package:strongbody_buyer/modules/assistant/presentation/assistant_page_args.dart';
import 'package:strongbody_buyer/modules/assistant/presentation/bloc/assistant_chat_cubit.dart';
import 'package:strongbody_buyer/modules/assistant/presentation/screens/assistant_chat_page.dart';
import 'package:strongbody_buyer/modules/chat/presentation/bloc/chat/chat_bloc.dart';
import 'package:strongbody_buyer/modules/chat/presentation/bloc/conversations/conversations_bloc.dart';
import 'package:strongbody_buyer/modules/chat/presentation/chat_page_args.dart';
import 'package:strongbody_buyer/modules/chat/presentation/screens/chat_page.dart';
import 'package:strongbody_buyer/modules/chat/presentation/screens/messages_page.dart';
import 'package:strongbody_buyer/modules/home/presentation/bloc/home/home_bloc.dart';
import 'package:strongbody_buyer/modules/home/presentation/screens/home_page.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/provider_keyword.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/matching_providers/matching_providers_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/my_requests/my_requests_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/post_request_flow/post_request_flow_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/request_offers/request_offers_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/voice_request/voice_request_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/matching_providers_page_args.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/post_request_flow_args.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/request_offers_page_args.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/screens/matching_providers_page.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/screens/my_requests_page.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/request_matches/request_matches_cubit.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/screens/post_request_page.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/screens/request_offers_page.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/screens/request_matches_page.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/screens/voice_request_page.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/voice_request_page_args.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_category.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_feed_entities.dart';
import 'package:strongbody_buyer/modules/social_market/domain/entities/market_listing_entities.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/category_market/category_market_bloc.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/engagement/engagement_cubit.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/market_listing/market_listing_bloc.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/screens/category_market_page.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/screens/market_listing_page.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/market_navigation.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/medical_travel/destination_cubit.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/bloc/medical_travel/service_detail_cubit.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/screens/destination_page.dart';
import 'package:strongbody_buyer/modules/social_market/presentation/screens/market_service_detail_page.dart';
import 'package:strongbody_buyer/modules/splash/presentation/screens/splash_page.dart';
import 'package:strongbody_buyer/modules/user_block/presentation/bloc/blocked_users_bloc.dart';
import 'package:strongbody_buyer/modules/user_block/presentation/screens/blocked_users_page.dart';

/// Điều hướng: `context.push/go(RouteName.x, extra: ...)`.
/// `Navigator.pop` chỉ dùng cho dialog/bottom sheet.
class AppRoutes {
  AppRoutes._();

  static final GoRouter router = GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: RouteName.splash,
    // PostHog screen view; ShellRoute có navigator riêng nên cần observer riêng.
    observers: [AppAnalytics.observer()],
    routes: [
      GoRoute(
        path: RouteName.splash,
        builder: (context, state) => const SplashPage(),
      ),
      // 4 tab giữ state riêng (Multime `LazyIndexedStack`); màn phụ bên dưới đè lên trên.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppTabShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteName.rootScreen,
                builder: (context, state) => BlocProvider(
                  create: (_) => getIt<HomeBloc>()..add(const HomeStarted()),
                  child: TabActivation(
                    tab: AppTab.home,
                    onActivated: (context) =>
                        context.read<HomeBloc>().add(const HomeStarted()),
                    child: const HomePage(),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteName.myRequests,
                builder: (context, state) => BlocProvider(
                  create: (_) =>
                      getIt<MyRequestsBloc>()..add(const MyRequestsStarted()),
                  child: TabActivation(
                    tab: AppTab.requests,
                    onActivated: (context) => context
                        .read<MyRequestsBloc>()
                        .add(const MyRequestsStarted()),
                    child: const MyRequestsPage(),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteName.messages,
                builder: (context, state) => BlocProvider(
                  create: (_) =>
                      getIt<ConversationsBloc>()
                        ..add(const ConversationsStarted()),
                  child: TabActivation(
                    tab: AppTab.messages,
                    onActivated: (context) => context
                        .read<ConversationsBloc>()
                        .add(const ConversationsStarted()),
                    child: const MessagesPage(),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteName.account,
                builder: (context, state) => BlocProvider(
                  create: (_) =>
                      getIt<AccountBloc>()..add(const AccountStarted()),
                  child: TabActivation(
                    tab: AppTab.account,
                    onActivated: (context) =>
                        context.read<AccountBloc>().add(const AccountStarted()),
                    child: const AccountPage(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RouteName.voiceRequest,
        builder: (context, state) {
          final args = VoiceRequestPageArgs.fromExtra(state.extra);
          return BlocProvider(
            create: (_) => getIt<VoiceRequestBloc>()
              ..add(
                VoiceRequestStarted(
                  recordVoiceNote:
                      !args.refine &&
                      !args.toAssistant &&
                      getIt<UserPreferences>().attachVoiceToRequests,
                  initialLanguage: getIt<UserPreferences>().speakingLanguage,
                ),
              ),
            child: VoiceRequestPage(args: args),
          );
        },
      ),
      GoRoute(
        path: RouteName.assistant,
        builder: (context, state) {
          final args = AssistantPageArgs.fromExtra(state.extra);
          return BlocProvider(
            create: (_) => getIt<AssistantChatCubit>()
              ..start(
                language: context.locale.languageCode,
                text: args.text,
                source: args.source,
              ),
            child: AssistantChatPage(args: args),
          );
        },
      ),
      GoRoute(
        path: RouteName.requestOffers,
        redirect: (context, state) =>
            state.extra is RequestOffersPageArgs ? null : RouteName.myRequests,
        builder: (context, state) {
          final args = state.extra! as RequestOffersPageArgs;
          return BlocProvider(
            create: (_) => getIt<RequestOffersBloc>()
              ..add(
                RequestOffersStarted(
                  args.requestId,
                  initialOffers: args.offers,
                ),
              ),
            child: RequestOffersPage(args: args),
          );
        },
      ),
      GoRoute(
        path: RouteName.lionPoints,
        builder: (context, state) => BlocProvider(
          create: (_) =>
              getIt<LionPointsBloc>()..add(const LionPointsStarted()),
          child: const LionPointsPage(),
        ),
      ),
      GoRoute(
        path: RouteName.blockedUsers,
        builder: (context, state) => BlocProvider(
          create: (_) =>
              getIt<BlockedUsersBloc>()..add(const BlockedUsersStarted()),
          child: const BlockedUsersPage(),
        ),
      ),
      GoRoute(
        path: RouteName.chat,
        redirect: (context, state) =>
            state.extra is ChatPageArgs ? null : RouteName.messages,
        builder: (context, state) {
          final args = state.extra! as ChatPageArgs;
          return BlocProvider(
            create: (_) =>
                getIt<ChatBloc>(param1: args)..add(const ChatStarted()),
            child: ChatPage(args: args),
          );
        },
      ),
      // Medical Travel (Social Market): trang category chung (web `CategoryPage`) +
      // listing + chi tiết service + destination.
      // Khai TRƯỚC `/socialMarket/:category` để không bị bắt nhầm làm category.
      GoRoute(
        path: '${RouteName.socialMarket}/medical-travel',
        builder: (context, state) =>
            _categoryPage(context, MarketPageScope.medicalTravel),
        routes: [
          ..._listingRoutes((_) => MarketPageScope.medicalTravel),
          GoRoute(
            path: 'service/:id',
            redirect: (context, state) =>
                int.tryParse(state.pathParameters['id'] ?? '') == null
                ? RouteName.rootScreen
                : null,
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return BlocProvider(
                create: (_) => getIt<ServiceDetailCubit>()..load(id),
                child: MarketServiceDetailPage(serviceId: id),
              );
            },
          ),
          GoRoute(
            path: 'destination/:code',
            builder: (context, state) {
              final code = state.pathParameters['code']!;
              return BlocProvider(
                create: (_) => getIt<DestinationCubit>()..load(code),
                child: DestinationPage(code: code),
              );
            },
          ),
        ],
      ),
      // Social Market (menu ☰): trang category + listing "View all" — web `(HOME_CATEGORY)`.
      GoRoute(
        path: '${RouteName.socialMarket}/:category',
        redirect: (context, state) =>
            MarketCategory.fromRoute(state.pathParameters['category']) == null
            ? RouteName.rootScreen
            : null,
        builder: (context, state) => _categoryPage(
          context,
          MarketPageScope.of(
            MarketCategory.fromRoute(state.pathParameters['category'])!,
          ),
        ),
        routes: _listingRoutes(
          (state) => MarketPageScope.of(
            MarketCategory.fromRoute(state.pathParameters['category'])!,
          ),
        ),
      ),
      GoRoute(
        path: RouteName.postRequest,
        builder: (context, state) {
          final args = PostRequestFlowArgs.fromExtra(state.extra);
          return BlocProvider(
            create: (_) => getIt<PostRequestFlowBloc>()
              ..add(
                PostRequestFlowStarted(
                  args: args,
                  locale: context.locale.languageCode,
                ),
              ),
            child: PostRequestPage(args: args),
          );
        },
      ),
      GoRoute(
        path: RouteName.requestMatches,
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<RequestMatchesCubit>()
            ..start(
              int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              language: context.locale.languageCode,
            ),
          child: const RequestMatchesPage(),
        ),
      ),
      GoRoute(
        path: RouteName.matchingProviders,
        builder: (context, state) {
          final args = MatchingProvidersPageArgs.fromExtra(state.extra);
          final text = args.text.trim();
          return BlocProvider(
            create: (_) => getIt<MatchingProvidersBloc>()
              ..add(
                MatchingProvidersStarted(
                  keyword: text.isEmpty
                      ? ''
                      : ProviderKeyword.fromText(text, const []) ??
                            ProviderKeyword.fromSearch(text),
                ),
              ),
            child: MatchingProvidersPage(args: args),
          );
        },
      ),
    ],
  );
}

/// Trang category của Social Market (web `CategoryPage`), ngôn ngữ giao diện cho mục
/// "Care that speaks your language".
Widget _categoryPage(BuildContext context, MarketPageScope scope) =>
    BlocProvider(
      create: (_) => getIt<CategoryMarketBloc>()
        ..add(
          CategoryMarketStarted(scope, language: context.locale.languageCode),
        ),
      child: CategoryMarketPage(scope: scope),
    );

/// Listing "View all" của trang category: `services` (`?lang=` = ngôn ngữ seller) và
/// `providers` (web `/services/{category}`, `/providers/{category}`).
List<RouteBase> _listingRoutes(
  MarketPageScope Function(GoRouterState state) scopeOf,
) => [
  GoRoute(
    path: 'services',
    builder: (context, state) {
      final scope = scopeOf(state);
      return MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => getIt<MarketListingBloc<MarketServiceEntity>>(
              param1: scope,
              param2: state.uri.queryParameters[MarketRoutes
                  .listingLanguageParam],
            )..add(const MarketListingStarted()),
          ),
          BlocProvider(
            create: (_) =>
                getIt<EngagementCubit>(param1: EngagementTarget.service),
          ),
        ],
        child: MarketServicesListingPage(scope: scope),
      );
    },
  ),
  GoRoute(
    path: 'providers',
    builder: (context, state) {
      final scope = scopeOf(state);
      return MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => getIt<MarketListingBloc<MarketExpertEntity>>(
              param1: scope,
            )..add(const MarketListingStarted()),
          ),
          BlocProvider(
            create: (_) =>
                getIt<EngagementCubit>(param1: EngagementTarget.sellerProfile),
          ),
        ],
        child: MarketProvidersListingPage(scope: scope),
      );
    },
  ),
];
