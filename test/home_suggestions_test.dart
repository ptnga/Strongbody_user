import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/modules/home/domain/entities/typing_suggestion.dart';
import 'package:strongbody_buyer/modules/home/domain/repositories/home_repository.dart';
import 'package:strongbody_buyer/modules/home/domain/usecases/get_new_offers_count_use_case.dart';
import 'package:strongbody_buyer/modules/home/presentation/bloc/home/home_bloc.dart';
import 'package:strongbody_buyer/modules/post_request/domain/entities/provider_entity.dart';
import 'package:strongbody_buyer/modules/post_request/domain/repositories/post_request_repository.dart';
import 'package:strongbody_buyer/modules/post_request/domain/usecases/search_providers_use_case.dart';

class _Storage implements GlobalStorage {
  @override
  bool get isLoggedIn => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HomeRepo implements HomeRepository {
  @override
  Future<Either<Failure, int>> getNewOffersCount() async => const Right(0);
}

class _Repo implements PostRequestRepository {
  final keywords = <String>[];

  @override
  Future<Either<Failure, ProviderPage>> searchProviders({
    required String keyword,
    int page = 1,
    int limit = 20,
  }) async {
    keywords.add(keyword);
    return const Right(
      ProviderPage(
        items: [
          ProviderEntity(
            id: 1,
            userId: 1,
            name: 'Minh',
            profession: 'Sports physiotherapist',
            skills: ['Neck pain', 'Posture'],
          ),
          ProviderEntity(
            id: 3,
            userId: 3,
            name: 'Noise',
            profession: 'konkrete fragen an physiotherapeut verantwortliche',
            skills: ['cosmetic & plastic surgery physiotherapy'],
          ),
          ProviderEntity(
            id: 2,
            userId: 2,
            name: 'Grace',
            profession: 'Physiotherapist',
            skills: ['Neck pain'],
          ),
        ],
        total: 2,
        totalPage: 1,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  group('TypingSuggestionSeed', () {
    test('only short keywords get suggestions', () {
      expect(TypingSuggestionSeed.accepts('p'), isFalse);
      expect(TypingSuggestionSeed.accepts('physio'), isTrue);
      expect(
        TypingSuggestionSeed.accepts('I need a physio at home this weekend'),
        isFalse,
      );
    });

    test('vocabulary: whole-prefix terms first, shortest first', () {
      final seed = TypingSuggestionSeed.build('physio');
      expect(seed.primary, 'physiotherapy');
      expect(seed.secondary, 'physiotherapist');
      expect(seed.concern, 'back pain');
      expect(
        TypingSuggestionSeed.matchTerms('train', ['Personal trainer', 'x']),
        ['personal trainer'],
      );
    });

    test('unknown word falls back to the query itself', () {
      final seed = TypingSuggestionSeed.build('zzq');
      expect(seed.primary, 'zzq');
      expect(seed.secondary, isNull);
      expect(seed.concern, isNull);
    });
  });

  test(
    'HomeBloc: instant seed, then provider professions + top skill',
    () async {
      final repo = _Repo();
      final bloc = HomeBloc(
        getNewOffersCount: GetNewOffersCountUseCase(_HomeRepo()),
        searchProviders: SearchProvidersUseCase(repo),
        storage: _Storage(),
        preferences: _Prefs(),
      );
      bloc.add(const HomeQueryChanged('physio'));
      final instant = await bloc.stream.firstWhere((s) => s.typing != null);
      expect(instant.typing!.concern, 'back pain');

      final remote = await bloc.stream.firstWhere(
        (s) => s.typing?.concern == 'neck pain',
      );
      expect(repo.keywords, ['physio']);
      expect(remote.typing!.primary, 'physiotherapist');

      bloc.add(const HomeQueryChanged('I need a physio at home this weekend'));
      await bloc.stream.firstWhere((s) => s.typing == null);
      await bloc.close();
    },
  );

  test('HomeBloc: focus with no text shows recent searches', () async {
    final prefs = _Prefs()..recent.add('yoga teacher');
    final bloc = HomeBloc(
      getNewOffersCount: GetNewOffersCountUseCase(_HomeRepo()),
      searchProviders: SearchProvidersUseCase(_Repo()),
      storage: _Storage(),
      preferences: prefs,
    );
    expect(bloc.state.showRecent, isFalse);
    bloc.add(const HomeComposerFocusChanged(true));
    await bloc.stream.firstWhere((s) => s.showRecent);

    bloc.add(const HomeSearchRecorded('physio'));
    final recorded = await bloc.stream.firstWhere(
      (s) => s.recentSearches.length == 2,
    );
    expect(recorded.recentSearches.first, 'physio');
    await bloc.close();
  });
}
