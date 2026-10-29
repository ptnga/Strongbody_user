import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/modules/account/data/mappers/account_mapper.dart';
import 'package:strongbody_buyer/modules/account/domain/entities/account_entities.dart';
import 'package:strongbody_buyer/modules/account/domain/repositories/account_repository.dart';
import 'package:strongbody_buyer/modules/account/domain/usecases/account_use_cases.dart';
import 'package:strongbody_buyer/modules/account/presentation/bloc/account/account_bloc.dart';

class _Storage implements GlobalStorage {
  _Storage(this.loggedIn);

  bool loggedIn;

  @override
  bool get isLoggedIn => loggedIn;
  @override
  int? get userId => loggedIn ? 7 : null;
  @override
  String? get userName => loggedIn ? 'Sarah' : null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Prefs implements UserPreferences {
  String? language;
  bool translate = false;
  bool aloud = false;
  bool attach = true;

  @override
  String? get speakingLanguage => language;
  @override
  bool get autoTranslateChats => translate;
  @override
  bool get readRepliesAloud => aloud;
  @override
  bool get attachVoiceToRequests => attach;
  @override
  Future<void> setSpeakingLanguage(String? code) async => language = code;
  @override
  Future<void> setAutoTranslateChats(bool value) async => translate = value;
  @override
  Future<void> setReadRepliesAloud(bool value) async => aloud = value;
  @override
  Future<void> setAttachVoiceToRequests(bool value) async => attach = value;
  @override
  Future<void> init() async {}
  @override
  List<String> get recentSearches => const [];
  @override
  Future<void> addRecentSearch(String text) async {}
  @override
  Future<void> clearRecentSearches() async {}
}

class _Repo implements AccountRepository {
  _Repo(this.storage);

  final _Storage storage;
  bool loggedOut = false;

  @override
  Future<Either<Failure, AccountProfile>> getProfile() async => const Right(
    AccountProfile(
      id: 7,
      firstName: 'Sarah',
      lastName: 'Nguyen',
      city: 'Ho Chi Minh City',
      languages: ['en', 'vi'],
    ),
  );

  @override
  Future<Either<Failure, AccountProfile>> updateProfile({
    required String firstName,
    required String lastName,
    required String city,
  }) async => Right(
    AccountProfile(id: 7, firstName: firstName, lastName: lastName, city: city),
  );

  @override
  Future<Either<Failure, LionWallet>> getWallet() async =>
      const Right(LionWallet(id: 3, points: 1250));

  @override
  Future<Either<Failure, double?>> getPointValue() async => const Right(0.01);

  @override
  Future<Either<Failure, ({List<LionLedgerItem> items, bool hasMore})>>
  getLedger({required int walletId, required int page, int limit = 20}) async =>
      const Right((items: [], hasMore: false));

  @override
  Future<Either<Failure, Unit>> logout() async {
    loggedOut = true;
    storage.loggedIn = false;
    return const Right(unit);
  }
}

AccountBloc _bloc(_Repo repo, _Storage storage, _Prefs prefs) => AccountBloc(
  getProfile: GetAccountProfileUseCase(repo),
  updateProfile: UpdateAccountProfileUseCase(repo),
  getLionPoints: GetLionPointsUseCase(repo),
  logout: LogoutUseCase(repo),
  storage: storage,
  preferences: prefs,
);

void main() {
  group('AccountMapper', () {
    test('profile from /buyer/auth/me user', () {
      final p = AccountMapper.profile({
        'id': 7,
        'first_name': 'Sarah',
        'last_name': 'Nguyen',
        'email': 'sarah@example.com',
        'profile_picture': '',
        'city': '',
        'state': 'Ho Chi Minh City',
        'country': {'title': 'Vietnam'},
        'language': 'en, vi',
        'languages': [
          {'code': 'vi'},
          'fr',
        ],
      })!;
      expect(p.fullName, 'Sarah Nguyen');
      expect(p.avatarUrl, isNull);
      expect(p.place, 'Ho Chi Minh City');
      expect(p.country, 'Vietnam');
      expect(p.languages, ['en', 'vi', 'fr']);
      expect(AccountMapper.profile({'first_name': 'x'}), isNull);
    });

    test('wallet, point value, ledger', () {
      expect(
        AccountMapper.wallet({'id': 3, 'balanceCents': 1250})!.points,
        1250,
      );
      expect(
        AccountMapper.pointValue({
          'list': [
            {
              'value_json': {'value_of_1_point': 0.01},
            },
          ],
        }),
        0.01,
      );
      expect(AccountMapper.pointValue({'list': []}), isNull);
      final item = AccountMapper.ledgerItem({
        'id': 1,
        'type': 'spend',
        'amountCents': -200,
        'source': 'checkout',
        'eventAt': '2026-10-12T08:00:00Z',
      })!;
      expect(item.type, LionLedgerType.spend);
      expect(item.amount, -200);
      expect(item.at!.day, 12);
    });
  });

  group('AccountBloc', () {
    test('signed in: profile + points worth; prefs persist', () async {
      final storage = _Storage(true);
      final prefs = _Prefs();
      final bloc = _bloc(_Repo(storage), storage, prefs)
        ..add(const AccountStarted());
      final ready = await bloc.stream.firstWhere(
        (s) => s.profile != null && s.wallet != null,
      );
      expect(ready.displayName, 'Sarah Nguyen');
      expect(ready.pointsWorth, closeTo(12.5, 0.001));

      bloc
        ..add(const AccountSpeakingLanguageChanged('vi'))
        ..add(const AccountToggleChanged(AccountToggle.attachVoice, false));
      await bloc.stream.firstWhere((s) => !s.attachVoice);
      expect(prefs.language, 'vi');
      expect(prefs.attach, isFalse);
      await bloc.close();
    });

    test('guest → signedOut; logout clears session', () async {
      final guest = _Storage(false);
      final guestBloc = _bloc(_Repo(guest), guest, _Prefs())
        ..add(const AccountStarted());
      expect((await guestBloc.stream.first).status, AccountStatus.signedOut);
      await guestBloc.close();

      final storage = _Storage(true);
      final repo = _Repo(storage);
      final bloc = _bloc(repo, storage, _Prefs())..add(const AccountStarted());
      await bloc.stream.firstWhere((s) => s.profile != null);
      bloc.add(const AccountLogoutRequested());
      final out = await bloc.stream.firstWhere(
        (s) => s.notice == AccountNotice.loggedOut,
      );
      expect(out.status, AccountStatus.signedOut);
      expect(out.profile, isNull);
      expect(repo.loggedOut, isTrue);
      await bloc.close();
    });
  });
}
