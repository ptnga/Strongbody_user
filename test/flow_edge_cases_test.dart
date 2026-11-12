import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/streams/auth_event_bus.dart';
import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/my_request_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/post_request_failure.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/posted_request_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/provider_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_draft_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_form_values.dart';
import 'package:strongbody_buyer/modules/post_request/domain/repositories/post_request_repository.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/create_buyer_request_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/draft_request_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/get_currencies_use_case.dart';
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
  Either<Failure, CreatedRequest> create = const Right(
    CreatedRequest(id: 42, status: 'active'),
  );
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
  Future<Either<Failure, CreatedRequest>> createBuyerRequest({
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

  /// `isPrivate` của từng lần gọi `getMyRequests` (tab Public / Private).
  final myScopes = <bool?>[];

  @override
  Future<Either<Failure, MyRequestPage>> getMyRequests({
    required int userId,
    int page = 1,
    int limit = 20,
    bool? isPrivate,
  }) async {
    myScopes.add(isPrivate);
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

  @override
  Future<Either<Failure, SentRequest>> getSentRequest(int id) async =>
      Left(NotFoundFailure('none'));

  @override
  Future<Either<Failure, List<CurrencyOption>>> getCurrencies() async =>
      const Right([
        CurrencyOption(id: 1, code: 'USD'),
        CurrencyOption(id: 2, code: 'VND'),
      ]);
}

PostRequestFlowBloc _flow(_Repo repo, _Storage storage) => PostRequestFlowBloc(
  transcribeAudio: TranscribeAudioUseCase(repo),
  draftRequest: DraftRequestUseCase(repo),
  createBuyerRequest: CreateBuyerRequestUseCase(repo),
  getCurrencies: GetCurrenciesUseCase(repo),
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
  group('PostRequestFlowBloc (web /request-assistant)', () {
    const long =
        'I need a physiotherapist at home for my lower back pain this weekend.';

    test('typed text → form locked while drafting → filled form', () async {
      final repo = _Repo();
      final bloc = _flow(repo, _Storage())
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: long),
            locale: 'en',
          ),
        );
      final working = await _until(
        bloc.stream,
        bloc.state,
        (s) => s.step == PostRequestDraftStep.drafting,
      );
      expect(working.isWorking, isTrue);
      expect(working.values.description, long);
      final s = await _ready(bloc);
      expect(s.progress, 100);
      expect(s.outcome, PostRequestDraftOutcome.filled);
      expect(s.values.deliveryTypes, [RequestDeliveryType.atHome]);
      await bloc.close();
    });

    test(
      'voice → BE transcription → AI; recording not kept unless attached',
      () async {
        final repo = _Repo();
        final bloc = _flow(repo, _Storage())
          ..add(
            const PostRequestFlowStarted(
              args: PostRequestFlowArgs(audioPath: '/tmp/a.m4a'),
              locale: 'en',
            ),
          );
        final step = await _until(
          bloc.stream,
          bloc.state,
          (s) => s.step == PostRequestDraftStep.transcribing,
        );
        expect(step.isWorking, isTrue);
        final s = await _ready(bloc);
        expect(s.values.description, 'back pain at home');
        expect(s.values.voicePath, isNull);
        await bloc.close();

        final attached = _flow(repo, _Storage())
          ..add(
            const PostRequestFlowStarted(
              args: PostRequestFlowArgs(
                audioPath: '/tmp/b.m4a',
                attachVoice: true,
                voiceDuration: Duration(seconds: 9),
              ),
              locale: 'en',
            ),
          );
        final kept = await _ready(attached);
        expect(kept.values.voicePath, '/tmp/b.m4a');
        await attached.close();
      },
    );

    test(
      'voice: rate limited / empty transcription → failed + notice',
      () async {
        final repo = _Repo()..transcribe = Left(SpeechRateLimitFailure('slow'));
        var bloc = _flow(repo, _Storage())
          ..add(
            const PostRequestFlowStarted(
              args: PostRequestFlowArgs(audioPath: '/tmp/a.m4a'),
              locale: 'en',
            ),
          );
        var s = await _ready(bloc);
        expect(s.outcome, PostRequestDraftOutcome.failed);
        expect(s.notice, PostRequestNotice.rateLimited);
        await bloc.close();

        repo.transcribe = const Right('  ');
        bloc = _flow(repo, _Storage())
          ..add(
            const PostRequestFlowStarted(
              args: PostRequestFlowArgs(audioPath: '/tmp/a.m4a'),
              locale: 'en',
            ),
          );
        s = await _ready(bloc);
        expect(s.notice, PostRequestNotice.emptyVoice);
        await bloc.close();
      },
    );

    test('AI draft fails → failed + notice, typed text kept', () async {
      final repo = _Repo()..draft = Left(ServerFailure('boom'));
      final bloc = _flow(repo, _Storage())
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: long),
            locale: 'vi',
          ),
        );
      final s = await _ready(bloc);
      expect(s.outcome, PostRequestDraftOutcome.failed);
      expect(s.notice, PostRequestNotice.draftFailed);
      expect(s.values.description, long);
      expect(s.values.sellerLanguages, ['vi']);
      await bloc.close();
    });

    test('Me too prefill opens the form without AI', () async {
      final repo = _Repo()..draft = Left(ServerFailure('should not call'));
      final bloc = _flow(repo, _Storage())
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(
              prefill: RequestFormValues(
                description: long,
                deliveryTypes: [RequestDeliveryType.remote],
                similarToRequestId: 99,
              ),
            ),
            locale: 'en',
          ),
        );
      final s = await _ready(bloc);
      expect(s.notice, isNull);
      expect(s.values.similarToRequestId, 99);
      expect(s.values.sellerLanguages, ['en']);
      await bloc.close();
    });

    test('currency id is filled when the list loads', () async {
      final repo = _Repo();
      final bloc = _flow(repo, _Storage())
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(),
            locale: 'en',
          ),
        );
      final s = await _until(
        bloc.stream,
        bloc.state,
        (s) => s.currencies.isNotEmpty,
      );
      expect(s.values.currencyId, 1);
      await bloc.close();
    });

    test(
      'submit: description under 50 chars or bad budget → no post',
      () async {
        final repo = _Repo();
        final bloc = _flow(repo, _Storage())
          ..add(
            const PostRequestFlowStarted(
              args: PostRequestFlowArgs(text: 'back pain'),
              locale: 'en',
            ),
          );
        final ready = await _ready(bloc);
        bloc.add(const PostRequestFlowSubmitted());
        final s = await _until(
          bloc.stream,
          bloc.state,
          (s) => s.notice != null,
        );
        expect(s.notice, PostRequestNotice.descriptionTooShort);

        bloc
          ..add(const PostRequestFlowNoticeConsumed())
          ..add(
            PostRequestFlowValuesChanged(
              ready.values.copyWith(description: long, budget: 'abc'),
            ),
          )
          ..add(const PostRequestFlowSubmitted());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(repo.createCalls, 0);
        await bloc.close();
      },
    );

    test('guest submit keeps the request pending for after sign up', () async {
      final storage = _Storage(loggedIn: false);
      final bloc = _flow(_Repo(), storage)
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: long),
            locale: 'en',
          ),
        );
      await _ready(bloc);
      bloc.add(const PostRequestFlowSubmitted());
      final s = await _until(
        bloc.stream,
        bloc.state,
        (s) => s.submitStatus == PostRequestSubmitStatus.pendingAuth,
      );
      expect(s.values.description, long);
      expect(storage.pending?['description'], long);
      expect(storage.pending?['anonymous'], false);
      await bloc.close();
    });

    test('success → created request id; double tap posts once', () async {
      final repo = _Repo()..createGate = Completer<void>();
      final bloc = _flow(repo, _Storage())
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: long),
            locale: 'en',
          ),
        );
      await _ready(bloc);
      bloc
        ..add(const PostRequestFlowSubmitted())
        ..add(const PostRequestFlowSubmitted());
      await Future<void>.delayed(Duration.zero);
      repo.createGate!.complete();
      final s = await _until(
        bloc.stream,
        bloc.state,
        (s) => s.submitStatus == PostRequestSubmitStatus.success,
      );
      expect(s.created?.id, 42);
      expect(repo.createCalls, 1);
      await bloc.close();
    });

    test(
      'send to providers: a failed seller is retried, others not resent',
      () async {
        final repo = _Repo()..failSellers.add(502);
        final bloc = _flow(repo, _Storage())
          ..add(
            const PostRequestFlowStarted(
              args: PostRequestFlowArgs(
                prefill: RequestFormValues(description: long),
                sellerUserIds: [501, 502],
              ),
              locale: 'en',
            ),
          );
        final ready = await _ready(bloc);
        expect(ready.values.sellerLanguages, isEmpty);
        bloc.add(const PostRequestFlowSubmitted());
        await _until(
          bloc.stream,
          bloc.state,
          (s) => s.submitStatus == PostRequestSubmitStatus.failure,
        );
        repo.failSellers.clear();
        bloc.add(const PostRequestFlowSubmitted());
        await _until(
          bloc.stream,
          bloc.state,
          (s) => s.submitStatus == PostRequestSubmitStatus.success,
        );
        expect(repo.postedSellers, [501, 502]);
        await bloc.close();
      },
    );
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
      'public/private tabs filter on the server; offers only when offers_count > 0',
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
        // Web: request đã đóng vẫn ở cùng danh sách (badge "Closed").
        expect(s.visibleItems.map((r) => r.id), [1, 2, 3]);
        expect(repo.offersCalls, [1]);
        expect(repo.myScopes, [false]);
        bloc.add(const MyRequestsTabChanged(MyRequestsTab.private));
        await bloc.stream.firstWhere(
          (s) =>
              s.tab == MyRequestsTab.private &&
              s.status == MyRequestsStatus.success,
        );
        expect(repo.myScopes, [false, true]);
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
