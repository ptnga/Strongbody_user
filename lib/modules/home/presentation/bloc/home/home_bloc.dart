import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/core/streams/auth_event_bus.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import 'package:strongbody_buyer/modules/post_request/domain/usecases/search_providers_use_case.dart';

import '../../../domain/entities/typing_suggestion.dart';
import '../../../domain/usecases/get_new_offers_count_use_case.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends BlocWithApi<HomeEvent, HomeState> {
  final GetNewOffersCountUseCase _getNewOffersCount;
  final SearchProvidersUseCase _searchProviders;
  final GlobalStorage _storage;
  final UserPreferences _preferences;
  late final StreamSubscription<AuthEvent> _authSubscription;
  Timer? _suggestDebounce;

  HomeBloc({
    required GetNewOffersCountUseCase getNewOffersCount,
    required SearchProvidersUseCase searchProviders,
    required GlobalStorage storage,
    required UserPreferences preferences,
  }) : _getNewOffersCount = getNewOffersCount,
       _searchProviders = searchProviders,
       _storage = storage,
       _preferences = preferences,
       super(HomeState(recentSearches: preferences.recentSearches)) {
    on<HomeStarted>(_onStarted);
    on<HomeQueryChanged>(_onQueryChanged);
    on<HomeComposerFocusChanged>(
      (event, emit) => emit(state.copyWith(composerFocused: event.focused)),
    );
    on<HomeSearchRecorded>((event, emit) async {
      await _preferences.addRecentSearch(event.text);
      emit(state.copyWith(recentSearches: _preferences.recentSearches));
    });
    on<_HomeSuggestionsRequested>(_onSuggestionsRequested);
    // Đăng nhập / đăng xuất ở bất kỳ đâu → làm mới lời chào, avatar, pill offer.
    _authSubscription = AuthEventBus.stream.listen((_) {
      if (!isClosed) add(const HomeStarted());
    });
  }

  void _onQueryChanged(HomeQueryChanged event, Emitter<HomeState> emit) {
    _suggestDebounce?.cancel();
    if (!TypingSuggestionSeed.accepts(event.text)) {
      emit(state.copyWith(clearTyping: true));
      return;
    }
    // Gợi ý ngay từ bộ từ sẵn có, rồi bổ sung nghề / kỹ năng provider thật.
    emit(state.copyWith(typing: TypingSuggestionSeed.build(event.text)));
    final query = event.text.trim();
    _suggestDebounce = Timer(
      const Duration(milliseconds: 300),
      () => add(_HomeSuggestionsRequested(query)),
    );
  }

  Future<void> _onSuggestionsRequested(
    _HomeSuggestionsRequested event,
    Emitter<HomeState> emit,
  ) => callApi(
    useCase: _searchProviders,
    param: SearchProvidersParams(keyword: event.query, limit: 10),
    onSuccess: (page) async {
      // Người dùng đã gõ tiếp / xoá → bỏ kết quả cũ.
      if (state.typing?.query != event.query) return;
      final skillCounts = <String, int>{};
      for (final p in page.items) {
        for (final skill in p.skills) {
          skillCounts.update(skill, (n) => n + 1, ifAbsent: () => 1);
        }
      }
      final concerns = skillCounts.keys.toList()
        ..sort((a, b) => skillCounts[b]!.compareTo(skillCounts[a]!));
      emit(
        state.copyWith(
          typing: TypingSuggestionSeed.build(
            event.query,
            remoteTerms: [
              for (final p in page.items) ?p.profession,
              ...skillCounts.keys,
            ],
            remoteConcerns: concerns,
          ),
        ),
      );
    },
    onFailure: (_) {},
  );

  @override
  Future<void> close() async {
    _suggestDebounce?.cancel();
    await _authSubscription.cancel();
    return super.close();
  }

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    final isLoggedIn = _storage.isLoggedIn;
    emit(
      state.copyWith(
        status: HomeStatus.success,
        isLoggedIn: isLoggedIn,
        userName: _storage.userName,
        clearUserName: !isLoggedIn,
        newOffersCount: isLoggedIn ? null : 0,
      ),
    );
    if (!isLoggedIn) return;

    // Pill "N new offers" — lỗi thì ẩn, không chặn trang chủ.
    await callApi(
      useCase: _getNewOffersCount,
      param: const NoParams(),
      onSuccess: (count) async => emit(state.copyWith(newOffersCount: count)),
      onFailure: (_) {},
    );
  }
}
