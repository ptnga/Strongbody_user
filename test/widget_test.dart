import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/modules/home/domain/repositories/home_repository.dart';
import 'package:strongbody_buyer/modules/home/domain/usecases/get_new_offers_count_use_case.dart';
import 'package:strongbody_buyer/modules/home/presentation/bloc/home/home_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/data/mappers/post_request_mapper.dart';
import 'package:strongbody_buyer/modules/post_request/data/models/response/request_draft_response_dto.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/my_request_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/provider_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/provider_keyword.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/provider_refine_query.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_draft_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/request_form_values.dart';
import 'package:strongbody_buyer/modules/post_request/domain/repositories/post_request_repository.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/create_buyer_request_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/draft_request_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/get_provider_extras_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/search_providers_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/transcribe_audio_use_case.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/matching_providers/matching_providers_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/bloc/post_request_flow/post_request_flow_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/post_request_flow_args.dart';
import 'package:strongbody_buyer/modules/post_request/presentation/request_formatters.dart';

class _FakeStorage implements GlobalStorage {
  _FakeStorage({this.loggedIn = false, this.name});

  final bool loggedIn;
  final String? name;
  Map<String, dynamic>? pending;

  @override
  Future<void> init() async {}
  @override
  String? get accessToken => loggedIn ? 'token' : null;
  @override
  String? get refreshToken => null;
  @override
  bool get isLoggedIn => loggedIn;
  @override
  int? get userId => loggedIn ? 7 : null;
  @override
  String? get userName => name;
  @override
  String get locale => 'en';
  @override
  Map<String, dynamic>? get pendingRequest => pending;
  @override
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {}
  @override
  String? get userEmail => null;
  @override
  String? get referralCode => null;
  @override
  Future<void> saveUser({required int id, String? name, String? email}) async {}
  @override
  Future<void> saveAccessToken(
    String accessToken, {
    String? refreshToken,
  }) async {}
  @override
  Future<void> saveLocale(String locale) async {}
  @override
  Future<void> savePendingRequest(Map<String, dynamic> json) async =>
      pending = json;
  @override
  Future<void> clearPendingRequest() async => pending = null;
  @override
  Future<void> clearUser() async {}
}

class _FakeHomeRepository implements HomeRepository {
  @override
  Future<Either<Failure, int>> getNewOffersCount() async => const Right(3);
}

class _FakePostRequestRepository implements PostRequestRepository {
  String? transcribedPath;
  String? draftedText;
  String? searchedKeyword;
  String? createdDescription;
  List<int>? createdSellerIds;
  String? createdVoice;

  @override
  Future<Either<Failure, String>> transcribeAudio(String audioPath) async {
    transcribedPath = audioPath;
    return const Right('I need a physiotherapist at home');
  }

  @override
  Future<Either<Failure, RequestDraftEntity>> draftRequest({
    required String text,
    required String locale,
  }) async {
    draftedText = text;
    return Right(
      RequestDraftEntity(
        isEmpty: false,
        values: RequestFormValues(
          description: 'Drafted: $text',
          budget: '60-80',
          deliveryTypes: const [RequestDeliveryType.atHome],
        ),
        assistant: const RequestAssistantMeta(
          categoryIds: [96654],
          suggestion: 'Say how long it hurts.',
        ),
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
    createdDescription = values.description;
    createdSellerIds = sellerUserIds;
    createdVoice = values.voicePath;
    return const Right('active');
  }

  @override
  Future<Either<Failure, ProviderPage>> searchProviders({
    required String keyword,
    int page = 1,
    int limit = 20,
  }) async {
    searchedKeyword = keyword;
    return Right(
      ProviderPage(
        items: [
          _provider,
          const ProviderEntity(
            id: 2,
            userId: 502,
            name: 'Grace Wong',
            rating: 4.8,
            reviewCount: 203,
            languages: ['en', 'zh-CN'],
          ),
          const ProviderEntity(id: 3, userId: 503, name: 'Thao Nguyen'),
        ],
        total: 12,
        totalPage: 1,
      ),
    );
  }

  @override
  Future<Either<Failure, ProviderExtras>> getProviderExtras(
    ProviderEntity provider,
  ) async => Right(
    provider.userId == 501
        ? ProviderExtras(
            minPrice: 65,
            deliveryTypes: {RequestDeliveryType.atHome},
            slots: const [
              WeeklySlot(
                weekday: DateTime.saturday,
                startTime: '09:00',
                endTime: '12:00',
              ),
            ],
          )
        : ProviderExtras(
            minPrice: 120,
            deliveryTypes: {RequestDeliveryType.remote},
            slots: const [
              WeeklySlot(
                weekday: DateTime.monday,
                startTime: '09:00',
                endTime: '12:00',
              ),
            ],
          ),
  );

  @override
  Future<Either<Failure, MyRequestPage>> getMyRequests({
    required int userId,
    int page = 1,
    int limit = 20,
  }) async => const Right(MyRequestPage(items: [], totalPage: 1));

  @override
  Future<Either<Failure, List<RequestOfferEntity>>> getRequestOffers(
    int requestId,
  ) async => const Right([]);
}

PostRequestFlowBloc _flowBloc(
  _FakeStorage storage,
  PostRequestRepository repo,
) => PostRequestFlowBloc(
  transcribeAudio: TranscribeAudioUseCase(repo),
  draftRequest: DraftRequestUseCase(repo),
  searchProviders: SearchProvidersUseCase(repo),
  createBuyerRequest: CreateBuyerRequestUseCase(repo),
  storage: storage,
);

Future<PostRequestFlowState> _until(
  PostRequestFlowBloc bloc,
  bool Function(PostRequestFlowState) test,
) => test(bloc.state) ? Future.value(bloc.state) : bloc.stream.firstWhere(test);

const _provider = ProviderEntity(
  id: 1,
  userId: 501,
  slug: 'minh',
  name: 'Minh Pham',
  rating: 4.9,
  reviewCount: 128,
  languages: ['vi', 'en'],
);

class _Prefs implements UserPreferences {
  final recent = <String>[];

  @override
  List<String> get recentSearches => List.unmodifiable(recent);
  @override
  Future<void> addRecentSearch(String text) async => recent.insert(0, text);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => initializeDateFormatting());

  group('HomeBloc', () {
    test('guest: no greeting name, no offers call', () async {
      final bloc = HomeBloc(
        getNewOffersCount: GetNewOffersCountUseCase(_FakeHomeRepository()),
        searchProviders: SearchProvidersUseCase(_FakePostRequestRepository()),
        storage: _FakeStorage(),
        preferences: _Prefs(),
      );
      bloc.add(const HomeStarted());
      await expectLater(
        bloc.stream,
        emits(const HomeState(status: HomeStatus.success)),
      );
      await bloc.close();
    });

    test('logged in: initials + new offers count', () async {
      final bloc = HomeBloc(
        getNewOffersCount: GetNewOffersCountUseCase(_FakeHomeRepository()),
        searchProviders: SearchProvidersUseCase(_FakePostRequestRepository()),
        storage: _FakeStorage(loggedIn: true, name: 'Sarah Nguyen'),
        preferences: _Prefs(),
      );
      bloc.add(const HomeStarted());
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<HomeState>((s) => s.newOffersCount == 3)),
      );
      expect(bloc.state.initials, 'SN');
      expect(bloc.state.firstName, 'Sarah');
      await bloc.close();
    });
  });

  group('RequestFormValues', () {
    test('parsedBudget handles amount and ranges', () {
      expect(const RequestFormValues(budget: '80').parsedBudget, (
        min: 80.0,
        max: 80.0,
      ));
      expect(const RequestFormValues(budget: '150–120').parsedBudget, (
        min: 120.0,
        max: 150.0,
      ));
      expect(const RequestFormValues().parsedBudget, (min: null, max: null));
    });

    test('date range sets deadline, end date and schedule days', () {
      final values = const RequestFormValues().withDateRange(
        DateTime(2026, 10, 24), // Sat
        DateTime(2026, 10, 25), // Sun
      );
      expect(values.deadline, DateTime(2026, 10, 24, 9));
      expect(values.endDate, DateTime(2026, 10, 25));
      expect(values.schedule.keys.toSet(), {WeekDay.sat, WeekDay.sun});
    });

    test(
      'AI "this weekend" (Sat deadline + sat/sun schedule) → Sat–Sun range',
      () {
        final values = RequestFormValues(
          deadline: DateTime(2026, 10, 31, 9),
          schedule: const {
            WeekDay.sat: [TimeRange(from: '09:00', to: '17:00')],
            WeekDay.sun: [TimeRange(from: '09:00', to: '17:00')],
          },
        ).withRangeFromSchedule();
        expect(values.endDate, DateTime(2026, 11, 1, 9));
      },
    );
  });

  group('RequestFormatters', () {
    test('when + budget', () {
      final values = const RequestFormValues(
        budget: '60-80',
      ).withDateRange(DateTime(2026, 10, 24), DateTime(2026, 10, 25));
      expect(RequestFormatters.when(values, 'en'), 'Sat 24 – Sun 25 Oct');
      expect(RequestFormatters.budget(values), r'$60–80');
      expect(
        RequestFormatters.budget(
          const RequestFormValues(budget: '500000', currency: 'VND'),
        ),
        '500000 VND',
      );
      expect(
        RequestFormatters.headline('I need a physio. At home this weekend.'),
        'I need a physio',
      );
    });
  });

  group('PostRequestMapper', () {
    test('maps AI draft and drops unknown values', () {
      final dto = RequestDraftResponseDto.fromJson(
        jsonDecode('''{
          "draft": {
            "description": "Physio at home",
            "budget": "50-80",
            "currency": "eur",
            "deliveryTypes": ["at_home", "spaceship"],
            "deadline": "2030-05-04T09:00",
            "schedule": {"sat": [{"from": "09:00", "to": "12:00"}], "sun": [{"from": "12:00", "to": "09:00"}]},
            "sellerLanguages": ["vi", "xx"],
            "categoryIds": [96652]
          },
          "empty": false, "suggestion": "Add your area", "rank": 7
        }''')
            as Map<String, dynamic>,
      );
      final draft = PostRequestMapper.draft(dto, fallbackText: 'raw');
      expect(draft.values.description, 'Physio at home');
      expect(draft.values.currency, 'EUR');
      expect(draft.values.deliveryTypes, [RequestDeliveryType.atHome]);
      expect(draft.values.deadline, DateTime(2030, 5, 4, 9));
      expect(draft.values.schedule.keys, [WeekDay.sat]);
      expect(draft.values.sellerLanguages, ['vi']);
      expect(draft.assistant.qualityScore, 7);
    });

    test(
      'public request multipart like web + voice file like Multime',
      () async {
        final dir = await Directory.systemTemp.createTemp('sb_test');
        final voice = File('${dir.path}/voice_1.m4a')
          ..writeAsBytesSync(List.filled(200, 1));
        final formData = await PostRequestMapper.createRequestFormData(
          userId: 7,
          values: RequestFormValues(
            description: ' Need help ',
            budget: '120-150',
            deliveryTypes: const [
              RequestDeliveryType.remote,
              RequestDeliveryType.atHome,
            ],
            sellerLanguages: const ['en'],
            voicePath: voice.path,
          ),
          assistant: const RequestAssistantMeta(
            categoryIds: [96652, 96657],
            qualityScore: 6,
          ),
        );
        final fields = Map.fromEntries(formData.fields);
        expect(fields['description'], 'Need help');
        expect(fields['type'], 'ldp');
        expect(fields['min_budget'], '120');
        expect(fields['max_budget'], '150');
        expect(fields['delivery_type'], 'all');
        expect(fields['category_id'], '96652');
        expect(fields.containsKey('seller_id'), isFalse);
        final voicePart = formData.files.singleWhere((f) => f.key == 'voice');
        expect(voicePart.value.contentType.toString(), 'audio/m4a');
        await dir.delete(recursive: true);
      },
    );

    test('to-seller variant adds seller_id + is_privated', () async {
      final formData = await PostRequestMapper.createRequestFormData(
        userId: 7,
        values: const RequestFormValues(description: 'Yoga'),
        sellerUserId: 501,
      );
      final fields = Map.fromEntries(formData.fields);
      expect(fields['seller_id'], '501');
      expect(fields['is_privated'], 'true');
    });

    test('provider keyword from profession words, else category', () {
      expect(
        ProviderKeyword.fromText('I need a physiotherapist for back pain', []),
        'physiotherapist',
      );
      expect(ProviderKeyword.fromText('Tôi cần người dạy yoga', []), 'yoga');
      expect(ProviderKeyword.fromText('help me relax', [96654]), 'massage');
      expect(ProviderKeyword.fromText('hello', []), isNull);
    });

    test('maps expert/balanced items', () {
      final page = PostRequestMapper.providers({
        'total': 26,
        'total_page': 2,
        'list': [
          {
            'id': 5230,
            'user_id': 5284,
            'slug': 'revival',
            'shop_name': 'Revival Physio',
            'seller_verified': true,
            'years_of_experience': 8,
            'review_summary': {'rating': 4.9, 'review_count': 128},
            'skills': ['Back & spine ', ''],
            'supported_languages': ['vi', 'en'],
            'user': {
              'first_name': 'rev',
              'profile_picture': '',
              'country': {'title': 'Vietnam'},
            },
            'professions': [
              {'name': 'Physiotherapist'},
            ],
          },
        ],
      });
      expect(page.total, 26);
      expect(page.items.single.userId, 5284);
      expect(page.items.single.name, 'Revival Physio');
      expect(page.items.single.profession, 'Physiotherapist');
      expect(page.items.single.avatarUrl, isNull);
      expect(page.items.single.yearsOfExperience, 8);
      expect(page.items.single.reviewCount, 128);
      expect(page.items.single.skills, ['Back & spine']);
      expect(page.items.single.slug, 'revival');
    });

    test(
      'provider extras: min price over delivery options, slots from profile',
      () {
        final extras = PostRequestMapper.providerExtras(
          services: [
            {
              'price': 149,
              'session_mode': 'single',
              'delivery_options': [
                {'delivery_type': 'remote', 'price': 149, 'is_active': true},
                {'delivery_type': 'at_home', 'price': 65, 'is_active': true},
                {'delivery_type': 'at_office', 'price': 40, 'is_active': false},
              ],
            },
          ],
          profile: {
            'availabilities': [
              {
                'weekday': 6,
                'start_time': '09:00',
                'end_time': '12:00',
                'is_active': true,
              },
              {
                'weekday': 0,
                'start_time': '14:00',
                'end_time': '16:00',
                'is_active': true,
              },
            ],
          },
        );
        expect(extras.minPrice, 65);
        expect(extras.perSession, isTrue);
        expect(extras.deliveryTypes, {
          RequestDeliveryType.remote,
          RequestDeliveryType.atHome,
        });
        expect(extras.slots.map((s) => s.weekday), [
          DateTime.saturday,
          DateTime.sunday,
        ]);
        // Thứ 5 22/10/2026 10:00 → lần rảnh gần nhất: thứ 7 24/10 09:00.
        expect(
          extras.nextAvailable(DateTime(2026, 10, 22, 10)),
          DateTime(2026, 10, 24, 9),
        );
        expect(
          extras.availableBetween(
            DateTime(2026, 10, 26),
            DateTime(2026, 10, 30),
          ),
          isFalse,
        );
      },
    );

    test('refine by voice → filters', () {
      final q = ProviderRefineQuery.parse(
        'Only women who speak Vietnamese, under \$70, top rated',
      );
      expect(q.languageCode, 'vi');
      expect(q.maxBudget, 70);
      expect(q.topRated, isTrue);
      expect(ProviderRefineQuery.parse('yoga teacher').keyword, 'yoga');
      expect(ProviderRefineQuery.parse('hello there').isEmpty, isTrue);
    });
  });

  group('PostRequestFlowBloc', () {
    test('typed text → AI draft → matching providers count', () async {
      final repo = _FakePostRequestRepository();
      final bloc = _flowBloc(_FakeStorage(), repo)
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: 'I need a physiotherapist'),
            locale: 'en',
          ),
        );
      final ready = await _until(
        bloc,
        (s) => !s.isAnalyzing && s.matchCount != null,
      );
      expect(ready.outcome, PostRequestDraftOutcome.filled);
      expect(ready.values.description, 'Drafted: I need a physiotherapist');
      expect(ready.assistant?.categoryIds, [96654]);
      expect(repo.searchedKeyword, 'physiotherapist');
      expect(ready.matchCount, 12);
      await bloc.close();
    });

    test('voice only (no on-device text) → BE transcription first', () async {
      final repo = _FakePostRequestRepository();
      final bloc = _flowBloc(_FakeStorage(), repo)
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(
              voicePath: '/tmp/voice.m4a',
              voiceDuration: Duration(seconds: 9),
            ),
            locale: 'en',
          ),
        );
      final ready = await _until(bloc, (s) => !s.isAnalyzing);
      expect(repo.transcribedPath, '/tmp/voice.m4a');
      expect(ready.transcript, 'I need a physiotherapist at home');
      expect(ready.values.voicePath, '/tmp/voice.m4a');
      expect(ready.values.voiceDuration, const Duration(seconds: 9));
      await bloc.close();
    });

    test('guest submit keeps request pending', () async {
      final storage = _FakeStorage();
      final bloc = _flowBloc(storage, _FakePostRequestRepository())
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: 'Yoga'),
            locale: 'en',
          ),
        );
      await _until(bloc, (s) => !s.isAnalyzing);
      bloc.add(const PostRequestFlowSubmitted());
      await _until(
        bloc,
        (s) => s.submitStatus == PostRequestSubmitStatus.pendingAuth,
      );
      expect(storage.pending?['description'], 'Drafted: Yoga');
      await bloc.close();
    });

    test('chosen providers → posted to each seller, voice kept', () async {
      final repo = _FakePostRequestRepository();
      final bloc = _flowBloc(_FakeStorage(loggedIn: true), repo)
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: 'Yoga', voicePath: '/tmp/v.m4a'),
            locale: 'en',
          ),
        );
      await _until(bloc, (s) => !s.isAnalyzing);
      bloc
        ..add(
          const PostRequestFlowVisibilityChanged(
            RequestVisibility.chosenProviders,
          ),
        )
        ..add(const PostRequestFlowSubmitted());
      await _until(bloc, (s) => s.notice == PostRequestNotice.chooseProviders);

      bloc
        ..add(const PostRequestFlowNoticeConsumed())
        ..add(const PostRequestFlowProvidersSelected([_provider]))
        ..add(const PostRequestFlowSubmitted());
      await _until(
        bloc,
        (s) => s.submitStatus == PostRequestSubmitStatus.success,
      );
      expect(repo.createdSellerIds, [501]);
      expect(repo.createdVoice, '/tmp/v.m4a');
      await bloc.close();
    });

    test(
      'providers "Post request" after "Request offer" posts to all',
      () async {
        final repo = _FakePostRequestRepository();
        final bloc = _flowBloc(_FakeStorage(loggedIn: true), repo)
          ..add(
            const PostRequestFlowStarted(
              args: PostRequestFlowArgs(text: 'Yoga', voicePath: '/tmp/v.m4a'),
              locale: 'en',
            ),
          );
        await _until(bloc, (s) => !s.isAnalyzing);
        // "Request offer" trên một provider rồi quay lại, bấm "Post request".
        bloc.add(const PostRequestFlowProvidersSelected([_provider]));
        await _until(
          bloc,
          (s) => s.visibility == RequestVisibility.chosenProviders,
        );
        bloc
          ..add(const PostRequestFlowProvidersSelected([]))
          ..add(
            const PostRequestFlowVisibilityChanged(
              RequestVisibility.allMatching,
            ),
          );
        final review = await _until(
          bloc,
          (s) =>
              s.visibility == RequestVisibility.allMatching &&
              s.selectedProviders.isEmpty,
        );
        expect(review.values.description, isNotEmpty);

        bloc.add(const PostRequestFlowSubmitted());
        await _until(
          bloc,
          (s) => s.submitStatus == PostRequestSubmitStatus.success,
        );
        expect(repo.createdSellerIds, isEmpty);
        expect(repo.createdDescription, review.values.description);
        expect(repo.createdVoice, '/tmp/v.m4a');
        await bloc.close();
      },
    );

    test('delivery is required; removing voice drops the file', () async {
      final repo = _FakePostRequestRepository();
      final bloc = _flowBloc(_FakeStorage(loggedIn: true), repo)
        ..add(
          const PostRequestFlowStarted(
            args: PostRequestFlowArgs(text: 'Yoga', voicePath: '/tmp/v.m4a'),
            locale: 'en',
          ),
        );
      final ready = await _until(bloc, (s) => !s.isAnalyzing);
      bloc
        ..add(
          PostRequestFlowValuesChanged(
            ready.values.copyWith(deliveryTypes: const []),
          ),
        )
        ..add(const PostRequestFlowSubmitted());
      await _until(bloc, (s) => s.notice == PostRequestNotice.deliveryRequired);

      bloc
        ..add(const PostRequestFlowNoticeConsumed())
        ..add(
          PostRequestFlowValuesChanged(
            ready.values.copyWith(
              deliveryTypes: const [RequestDeliveryType.remote],
            ),
          ),
        )
        ..add(const PostRequestFlowVoiceRemoved())
        ..add(const PostRequestFlowSubmitted());
      await _until(
        bloc,
        (s) => s.submitStatus == PostRequestSubmitStatus.success,
      );
      expect(repo.createdSellerIds, isEmpty);
      expect(repo.createdVoice, isNull);
      await bloc.close();
    });
  });

  test('browse only (menu / Saved providers) skips AI analysis', () async {
    final repo = _FakePostRequestRepository();
    final bloc = _flowBloc(_FakeStorage(loggedIn: true), repo)
      ..add(
        const PostRequestFlowStarted(
          args: PostRequestFlowArgs(browseOnly: true),
          locale: 'en',
        ),
      );
    final ready = await _until(bloc, (s) => !s.isAnalyzing);
    expect(ready.outcome, PostRequestDraftOutcome.empty);
    expect(ready.notice, isNull);
    expect(repo.searchedKeyword, isNull);
    await bloc.close();
  });

  test('voice note: remove → Undo remove keeps it on the request', () async {
    final repo = _FakePostRequestRepository();
    final bloc = _flowBloc(_FakeStorage(loggedIn: true), repo)
      ..add(
        const PostRequestFlowStarted(
          args: PostRequestFlowArgs(
            text: 'Yoga',
            voicePath: '/tmp/v.m4a',
            voiceDuration: Duration(seconds: 9),
          ),
          locale: 'en',
        ),
      );
    await _until(bloc, (s) => !s.isAnalyzing);

    bloc.add(const PostRequestFlowVoiceRemoved());
    final removed = await _until(bloc, (s) => s.hasRemovedVoice);
    expect(removed.values.hasVoice, isFalse);
    expect(removed.removedVoiceDuration, const Duration(seconds: 9));

    bloc.add(const PostRequestFlowVoiceRestored());
    final restored = await _until(bloc, (s) => !s.hasRemovedVoice);
    expect(restored.values.voicePath, '/tmp/v.m4a');
    expect(restored.values.voiceDuration, const Duration(seconds: 9));

    bloc
      ..add(
        PostRequestFlowValuesChanged(
          restored.values.copyWith(
            deliveryTypes: const [RequestDeliveryType.remote],
          ),
        ),
      )
      ..add(const PostRequestFlowSubmitted());
    await _until(
      bloc,
      (s) => s.submitStatus == PostRequestSubmitStatus.success,
    );
    expect(repo.createdVoice, '/tmp/v.m4a');
    await bloc.close();
  });

  group('MatchingProvidersBloc', () {
    MatchingProvidersBloc bloc0(PostRequestRepository repo) =>
        MatchingProvidersBloc(
          searchProviders: SearchProvidersUseCase(repo),
          getProviderExtras: GetProviderExtrasUseCase(repo),
        );

    Future<MatchingProvidersState> until(
      MatchingProvidersBloc bloc,
      bool Function(MatchingProvidersState) test,
    ) => test(bloc.state)
        ? Future.value(bloc.state)
        : bloc.stream.firstWhere(test);

    test(
      'request chips on by default, extras filter at-home + weekend',
      () async {
        final bloc = bloc0(_FakePostRequestRepository())
          ..add(
            MatchingProvidersStarted(
              keyword: 'physiotherapist',
              context: ProviderRequestContext(
                deliveryTypes: const [RequestDeliveryType.atHome],
                startDate: DateTime(2026, 10, 31), // thứ 7
                endDate: DateTime(2026, 11, 1),
                maxBudget: 70,
              ),
            ),
          );
        final loaded = await until(bloc, (s) => s.extras.length == 3);
        expect(loaded.activeFilters, {
          ProviderFilter.delivery,
          ProviderFilter.dates,
        });
        // Grace: online + thứ 2 → ẩn; Thao: chưa có dữ liệu khớp nào cũng online thứ 2 → ẩn.
        expect(loaded.visibleItems.map((p) => p.name), ['Minh Pham']);
        expect(loaded.matchCount, 1);

        bloc
          ..add(const MatchingProvidersFilterToggled(ProviderFilter.delivery))
          ..add(const MatchingProvidersFilterToggled(ProviderFilter.dates));
        final all = await until(bloc, (s) => s.activeFilters.isEmpty);
        expect(all.visibleItems.length, 3);
        expect(all.matchCount, 12); // không lọc → tổng của API
        await bloc.close();
      },
    );

    test(
      'refine "speaks Vietnamese, top rated" turns on language + sort',
      () async {
        final bloc = bloc0(_FakePostRequestRepository())
          ..add(const MatchingProvidersStarted(keyword: 'physiotherapist'));
        await until(bloc, (s) => s.extras.length == 3);
        bloc.add(
          const MatchingProvidersRefined(
            'someone who speaks Vietnamese, top rated',
          ),
        );
        final refined = await until(
          bloc,
          (s) => s.activeFilters.contains(ProviderFilter.language),
        );
        expect(refined.context.languageCode, 'vi');
        // Grace khai báo en/zh → ẩn; Thao chưa khai báo ngôn ngữ → vẫn hiện.
        expect(refined.visibleItems.map((p) => p.name), [
          'Minh Pham',
          'Thao Nguyen',
        ]);
        await bloc.close();
      },
    );
  });
}
