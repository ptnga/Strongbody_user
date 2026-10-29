import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/streams/auth_event_bus.dart';
import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/my_request_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/post_request_failure.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/provider_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_draft_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_form_values.dart';
import 'package:strongbody_buyer/modules/post_request/domain/repositories/post_request_repository.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/create_buyer_request_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/draft_request_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/get_my_requests_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/get_provider_extras_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/get_request_offers_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/search_providers_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/transcribe_audio_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/matching_providers/matching_providers_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/my_requests/my_requests_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/post_request_flow/post_request_flow_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/post_request_flow_args.dart';

class _Storage implements GlobalStorage {
  _Storage({this.loggedIn = true});

  bool loggedIn;
  Map<String, dynamic>? pending;

  @override
  bool get isLoggedIn => loggedIn;
  @override
  int? get userId => loggedIn ? 7 : null;
  @override
  Future<void> savePendingRequest(Map<String, dynamic> json) async =>
      pending = json;
  @override
  Future<void> clearPendingRequest() async => pending = null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderEntity _p(int id) =>
    ProviderEntity(id: id, userId: 500 + id, name: 'Provider $id');

MyRequestEntity _r(int id, {String status = 'active', int offers = 0}) =>
    MyRequestEntity(
      id: id,
      status: status,
      offersCount: offers,
      details: RequestFormValues(description: 'Request $id'),
    );

/// Fake cấu hình được: lỗi / trả chậm / đếm số lần gọi.
class _Repo implements PostRequestRepository {
  Either<Failure, String> transcribe = const Right('back pain at home');
  Either<Failure, RequestDraftEntity>? draft;
  Either<Failure, String?> create = const Right('42');
  Completer<void>? createGate;
  Completer<void>? draftGate;
  int createCalls = 0;
  final failSellers = <int>{};
  final postedSellers = <int>[];

  /// keyword → (trang → kết quả); `gates[keyword]` giữ phản hồi lại.
  final pages = <String, Map<int, Either<Failure, ProviderPage>>>{};
  final gates = <String, Completer<void>>{};

  List<Either<Failure, MyRequestPage>> myPages = [];
  final myGates = <int, Completer<void>>{};
  final offersCalls = <int>[];

  @override
  Future<Either<Failure, String>> transcribeAudio(String audioPath) async =>
      transcribe;

  @override
  Future<Either<Failure, RequestDraftEntity>> draftRequest({
    required String text,
    required String locale,
  }) async {
    await draftGate?.future;
    return draft ??
        Right(
          RequestDraftEntity(
            isEmpty: false,
            values: RequestFormValues(
              description: text,
              deliveryTypes: const [RequestDeliveryType.atHome],
            ),
            assistant: const RequestAssistantMeta(suggestion: ''),
          ),
        );
  }

  @override
  Future<Either<Failure, String?>> createBuyerRequest({
    required int userId,
    required RequestFormValues values,
    RequestAssistantMeta? assistant,
    List<int> sellerUserIds = const [],
    void Function(int sellerUserId)? onSellerPosted,
  }) async {
    createCalls++;
    await createGate?.future;
    for (final id in sellerUserIds) {
      if (failSellers.contains(id)) return Left(ServerFailure('seller $id'));
      postedSellers.add(id);
      onSellerPosted?.call(id);
    }
    return create;
  }

  @override
  Future<Either<Failure, ProviderPage>> searchProviders({
    required String keyword,
    int page = 1,
    int limit = 20,
  }) async {
    await gates[keyword]?.future;
    return pages[keyword]?[page] ??
        const Right(ProviderPage(items: [], total: 0, totalPage: 1));
  }

  @override
  Future<Either<Failure, ProviderExtras>> getProviderExtras(
    ProviderEntity provider,
  ) async => Left(ServerFailure('no extras'));

  @override
  Future<Either<Failure, MyRequestPage>> getMyRequests({
    required int userId,
    int page = 1,
    int limit = 20,
  }) async {
    await myGates[page]?.future;
    return myPages[page - 1];
  }

  @override
  Future<Either<Failure, List<RequestOfferEntity>>> getRequestOffers(
    int requestId,
  ) async {
    offersCalls.add(requestId);
    return const Right([
      RequestOfferEntity(id: 1, status: 'pending', sellerName: 'A', price: 50),
    ]);
  }
}

PostRequestFlowBloc _flow(_Repo repo, _Storage storage) => PostRequestFlowBloc(
  transcribeAudio: TranscribeAudioUseCase(repo),
  draftRequest: DraftRequestUseCase(repo),
  searchProviders: SearchProvidersUseCase(repo),
  createBuyerRequest: CreateBuyerRequestUseCase(repo),
  storage: storage,
);

Future<S> _until<S>(Stream<S> stream, S current, bool Function(S) test) =>
    test(current) ? Future.value(current) : stream.firstWhere(test);

Future<PostRequestFlowState> _ready(PostRequestFlowBloc bloc) => _until(
  bloc.stream,
  bloc.state,
  (s) => s.analysisStatus == PostRequestAnalysisStatus.ready,
);

void main() {
  group('PostRequestFlowBloc edge cases', () {
    test('AI draft fails → outcome failed + notice, transcript kept', () async {
      final repo = _Repo()..draft = Left(ServerFailure('boom'));
      final bloc = _flow(repo, _Storage())
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: 'knee pain'),
            locale: 'en',
          ),
        );
      final s = await _ready(bloc);
      expect(s.outcome, PostRequestDraftOutcome.failed);
      expect(s.notice, PostRequestNotice.draftFailed);
      expect(s.values.description, 'knee pain');
      await bloc.close();
    });

    test('voice only: rate limited / empty transcription → notice', () async {
      final limited = _Repo()
        ..transcribe = Left(SpeechRateLimitFailure('too many'));
      final a = _flow(limited, _Storage())
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: '', voicePath: '/tmp/a.wav'),
            locale: 'en',
          ),
        );
      expect((await _ready(a)).notice, PostRequestNotice.rateLimited);
      await a.close();

      final empty = _Repo()..transcribe = const Right('   ');
      final b = _flow(empty, _Storage())
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: '', voicePath: '/tmp/a.wav'),
            locale: 'en',
          ),
        );
      final s = await _ready(b);
      expect(s.notice, PostRequestNotice.emptyVoice);
      expect(s.outcome, PostRequestDraftOutcome.failed);
      await b.close();
    });

    test('submit validation: empty description, no providers chosen', () async {
      final repo = _Repo();
      final bloc = _flow(repo, _Storage())
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: 'yoga'),
            locale: 'en',
          ),
        );
      await _ready(bloc);

      bloc.add(
        const PostRequestFlowValuesChanged(
          RequestFormValues(
            description: '   ',
            deliveryTypes: [RequestDeliveryType.atHome],
          ),
        ),
      );
      bloc.add(const PostRequestFlowSubmitted());
      expect(
        (await bloc.stream.firstWhere((s) => s.notice != null)).notice,
        PostRequestNotice.descriptionRequired,
      );
      bloc
        ..add(const PostRequestFlowNoticeConsumed())
        ..add(
          const PostRequestFlowValuesChanged(
            RequestFormValues(
              description: 'Yoga at home',
              deliveryTypes: [RequestDeliveryType.atHome],
            ),
          ),
        )
        ..add(
          const PostRequestFlowVisibilityChanged(
            RequestVisibility.chosenProviders,
          ),
        )
        ..add(const PostRequestFlowSubmitted());
      expect(
        (await bloc.stream.firstWhere((s) => s.notice != null)).notice,
        PostRequestNotice.chooseProviders,
      );
      expect(repo.createCalls, 0);
      await bloc.close();
    });

    test('submit failure keeps pending draft; double tap posts once', () async {
      final repo = _Repo()
        ..create = Left(ServerFailure('Server error'))
        ..createGate = Completer<void>();
      final storage = _Storage()..pending = {'description': 'old'};
      final bloc = _flow(repo, storage)
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: 'massage'),
            locale: 'en',
          ),
        );
      await _ready(bloc);
      bloc
        ..add(const PostRequestFlowSubmitted())
        ..add(const PostRequestFlowSubmitted());
      await bloc.stream.firstWhere(
        (s) => s.submitStatus == PostRequestSubmitStatus.submitting,
      );
      await Future<void>.delayed(Duration.zero);
      repo.createGate!.complete();
      final s = await bloc.stream.firstWhere(
        (s) => s.submitStatus == PostRequestSubmitStatus.failure,
      );
      expect(repo.createCalls, 1);
      expect(s.notice, PostRequestNotice.requestFailed);
      expect(s.noticeMessage, 'Server error');
      expect(storage.pending, isNotNull);
      await bloc.close();
    });
  });

  group('PostRequestFlowBloc retry / auth / AI merge', () {
    test(
      'guest closes sign-up sheet, taps Post again → sheet reopens',
      () async {
        final bloc = _flow(_Repo(), _Storage(loggedIn: false))
          ..add(
            const PostRequestFlowStarted(
              args: PostRequestFlowArgs(text: 'physio'),
              locale: 'en',
            ),
          );
        await _ready(bloc);
        final statuses = <PostRequestSubmitStatus>[];
        final sub = bloc.stream.listen((s) => statuses.add(s.submitStatus));
        bloc.add(const PostRequestFlowSubmitted());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const PostRequestFlowSubmitted());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sub.cancel();
        // idle → pendingAuth lần 2 để listener của Review mở lại popup.
        expect(
          statuses.where((s) => s == PostRequestSubmitStatus.pendingAuth),
          hasLength(2),
        );
        await bloc.close();
      },
    );

    test(
      'chosen providers: retry after partial failure skips sent ones',
      () async {
        final repo = _Repo()..failSellers.add(502);
        final bloc = _flow(repo, _Storage())
          ..add(
            const PostRequestFlowStarted(
              args: PostRequestFlowArgs(text: 'physio'),
              locale: 'en',
            ),
          );
        await _ready(bloc);
        bloc
          ..add(PostRequestFlowProvidersSelected([_p(1), _p(2), _p(3)]))
          ..add(const PostRequestFlowSubmitted());
        await bloc.stream.firstWhere(
          (s) => s.submitStatus == PostRequestSubmitStatus.failure,
        );
        expect(repo.postedSellers, [501]);

        repo.failSellers.clear();
        bloc
          ..add(const PostRequestFlowNoticeConsumed())
          ..add(const PostRequestFlowSubmitted());
        await bloc.stream.firstWhere(
          (s) => s.submitStatus == PostRequestSubmitStatus.success,
        );
        expect(repo.postedSellers, [501, 502, 503]);
        await bloc.close();
      },
    );

    test('deselecting the failed provider never posts publicly', () async {
      final repo = _Repo()..failSellers.add(502);
      final bloc = _flow(repo, _Storage())
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: 'physio'),
            locale: 'en',
          ),
        );
      await _ready(bloc);
      bloc
        ..add(PostRequestFlowProvidersSelected([_p(1), _p(2)]))
        ..add(const PostRequestFlowSubmitted());
      await bloc.stream.firstWhere(
        (s) => s.submitStatus == PostRequestSubmitStatus.failure,
      );
      final callsBefore = repo.createCalls;
      bloc
        ..add(const PostRequestFlowNoticeConsumed())
        ..add(PostRequestFlowProvidersSelected([_p(1)]))
        ..add(const PostRequestFlowSubmitted());
      await bloc.stream.firstWhere(
        (s) => s.submitStatus == PostRequestSubmitStatus.success,
      );
      expect(repo.createCalls, callsBefore);
      await bloc.close();
    });

    test('edits made while AI is analysing are not overwritten', () async {
      final repo = _Repo()..draftGate = Completer<void>();
      final bloc = _flow(repo, _Storage())
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: 'yoga'),
            locale: 'en',
          ),
        );
      await bloc.stream.firstWhere((s) => s.isAnalyzing);
      bloc.add(
        const PostRequestFlowValuesChanged(
          RequestFormValues(
            description: 'Yoga for my back, mornings',
            budget: '50',
            deliveryTypes: [RequestDeliveryType.remote],
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      repo.draftGate!.complete();
      final s = await _ready(bloc);
      expect(s.values.description, 'Yoga for my back, mornings');
      expect(s.values.budget, '50');
      expect(s.values.deliveryTypes, [RequestDeliveryType.remote]);
      await bloc.close();
    });
  });

  group('MatchingProvidersBloc edge cases', () {
    MatchingProvidersBloc bloc0(_Repo repo) => MatchingProvidersBloc(
      searchProviders: SearchProvidersUseCase(repo),
      getProviderExtras: GetProviderExtrasUseCase(repo),
    );

    test('load more appends next page, stops at last page', () async {
      final repo = _Repo()
        ..pages['physio'] = {
          1: Right(ProviderPage(items: [_p(1), _p(2)], total: 3, totalPage: 2)),
          2: Right(ProviderPage(items: [_p(3)], total: 3, totalPage: 2)),
        };
      final bloc = bloc0(repo)
        ..add(const MatchingProvidersStarted(keyword: 'physio'));
      await bloc.stream.firstWhere(
        (s) => s.status == MatchingProvidersStatus.success,
      );
      expect(bloc.state.hasMore, isTrue);
      bloc.add(const MatchingProvidersLoadMore());
      final s = await bloc.stream.firstWhere((s) => s.items.length == 3);
      expect(s.hasMore, isFalse);
      expect(s.page, 2);
      await bloc.close();
    });

    test(
      'first page error → failure; slow old keyword result dropped',
      () async {
        final repo = _Repo()
          ..pages['bad'] = {1: Left(ServerFailure('down'))}
          ..pages['old'] = {
            1: Right(ProviderPage(items: [_p(1)], total: 1, totalPage: 1)),
          }
          ..pages['new'] = {
            1: Right(ProviderPage(items: [_p(9)], total: 1, totalPage: 1)),
          };
        final failing = bloc0(repo)
          ..add(const MatchingProvidersStarted(keyword: 'bad'));
        expect(
          (await failing.stream.firstWhere(
            (s) => s.status == MatchingProvidersStatus.failure,
          )).errorMessage,
          'down',
        );
        await failing.close();

        repo.gates['old'] = Completer<void>();
        final bloc = bloc0(repo)
          ..add(const MatchingProvidersStarted(keyword: 'old'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const MatchingProvidersKeywordSubmitted('new'));
        await bloc.stream.firstWhere(
          (s) => s.status == MatchingProvidersStatus.success,
        );
        repo.gates['old']!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(bloc.state.keyword, 'new');
        expect(bloc.state.items.map((p) => p.id), [9]);
        await bloc.close();
      },
    );

    test('filter chip toggles on and off; clear removes all', () async {
      final bloc = bloc0(_Repo())
        ..add(const MatchingProvidersFilterToggled(ProviderFilter.topRated));
      expect(
        (await bloc.stream.first).activeFilters,
        contains(ProviderFilter.topRated),
      );
      bloc.add(const MatchingProvidersFilterToggled(ProviderFilter.topRated));
      expect((await bloc.stream.first).activeFilters, isEmpty);
      bloc
        ..add(const MatchingProvidersFilterToggled(ProviderFilter.budget))
        ..add(const MatchingProvidersFiltersCleared());
      expect(
        (await bloc.stream.firstWhere(
          (s) => s.activeFilters.isEmpty,
        )).activeFilters,
        isEmpty,
      );
      await bloc.close();
    });
  });

  group('MyRequestsBloc', () {
    MyRequestsBloc bloc0(_Repo repo, _Storage storage) => MyRequestsBloc(
      getMyRequests: GetMyRequestsUseCase(repo),
      getRequestOffers: GetRequestOffersUseCase(repo),
      storage: storage,
    );

    test('guest → signedOut, no API call', () async {
      final bloc = bloc0(_Repo(), _Storage(loggedIn: false))
        ..add(const MyRequestsStarted());
      expect((await bloc.stream.first).status, MyRequestsStatus.signedOut);
      await bloc.close();
    });

    test(
      'active/closed split; offers loaded only when offers_count > 0',
      () async {
        final repo = _Repo()
          ..myPages = [
            Right(
              MyRequestPage(
                items: [
                  _r(1, offers: 2),
                  _r(2),
                  _r(3, status: 'closed'),
                ],
                totalPage: 1,
              ),
            ),
          ];
        final bloc = bloc0(repo, _Storage())..add(const MyRequestsStarted());
        final s = await bloc.stream.firstWhere((s) => s.offers.containsKey(1));
        expect(s.visibleItems.map((r) => r.id), [1, 2]);
        expect(repo.offersCalls, [1]);
        bloc.add(const MyRequestsTabChanged(MyRequestsTab.closed));
        expect((await bloc.stream.first).visibleItems.map((r) => r.id), [3]);
        await bloc.close();
      },
    );

    test('logout elsewhere wipes the kept-alive list', () async {
      final repo = _Repo()
        ..myPages = [
          Right(MyRequestPage(items: [_r(1)], totalPage: 1)),
        ];
      final storage = _Storage();
      final bloc = bloc0(repo, storage)..add(const MyRequestsStarted());
      await bloc.stream.firstWhere((s) => s.items.isNotEmpty);
      storage.loggedIn = false;
      AuthEventBus.emit(const UserLoggedOut());
      final s = await bloc.stream.firstWhere(
        (s) => s.status == MyRequestsStatus.signedOut,
      );
      expect(s.items, isEmpty);
      expect(s.offers, isEmpty);
      await bloc.close();
    });

    test('refresh during load-more: stale page is dropped', () async {
      final repo = _Repo()
        ..myPages = [
          Right(MyRequestPage(items: [_r(1), _r(2)], totalPage: 2)),
          Right(MyRequestPage(items: [_r(3)], totalPage: 2)),
        ];
      final bloc = bloc0(repo, _Storage())..add(const MyRequestsStarted());
      await bloc.stream.firstWhere((s) => s.items.length == 2);
      repo.myGates[2] = Completer<void>();
      bloc.add(const MyRequestsLoadMore());
      await bloc.stream.firstWhere((s) => s.isLoadingMore);
      bloc.add(const MyRequestsStarted());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      repo.myGates[2]!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.page, 1);
      expect(bloc.state.items.map((r) => r.id), [1, 2]);
      await bloc.close();
    });

    test('refresh (tab re-opened) keeps cards, no loading flash', () async {
      final repo = _Repo()
        ..myPages = [
          Right(MyRequestPage(items: [_r(1, offers: 1)], totalPage: 1)),
        ];
      final bloc = bloc0(repo, _Storage())..add(const MyRequestsStarted());
      await bloc.stream.firstWhere((s) => s.offers.containsKey(1));
      final seen = <MyRequestsState>[];
      final sub = bloc.stream.listen(seen.add);
      bloc.add(const MyRequestsStarted());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(seen.any((s) => s.status == MyRequestsStatus.loading), isFalse);
      expect(seen.any((s) => s.items.isEmpty), isFalse);
      // Offer của thẻ không bị xoá trong lúc tải lại (không nháy mất dải avatar).
      expect(seen.every((s) => s.offers.containsKey(1)), isTrue);
      await bloc.close();
    });
  });
}
