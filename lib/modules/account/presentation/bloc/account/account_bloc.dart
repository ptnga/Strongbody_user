import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/bloc/abstract_bloc_with_api.dart';
import 'package:strongbody_buyer/core/domain/storages/global_storage.dart';
import 'package:strongbody_buyer/core/domain/storages/user_preferences.dart';
import 'package:strongbody_buyer/core/streams/auth_event_bus.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../../../domain/entities/account_entities.dart';
import '../../../domain/usecases/account_use_cases.dart';

part 'account_event.dart';
part 'account_state.dart';

/// Tab Account: profile (`/buyer/auth/me`), Lion Points (point service), tuỳ chọn giọng nói /
/// dịch (trên máy), sửa profile, đăng xuất.
class AccountBloc extends BlocWithApi<AccountEvent, AccountState> {
  final GetAccountProfileUseCase _getProfile;
  final UpdateAccountProfileUseCase _updateProfile;
  final GetLionPointsUseCase _getLionPoints;
  final LogoutUseCase _logout;
  final GlobalStorage _storage;
  final UserPreferences _preferences;
  late final StreamSubscription<AuthEvent> _auth;

  AccountBloc({
    required GetAccountProfileUseCase getProfile,
    required UpdateAccountProfileUseCase updateProfile,
    required GetLionPointsUseCase getLionPoints,
    required LogoutUseCase logout,
    required GlobalStorage storage,
    required UserPreferences preferences,
  }) : _getProfile = getProfile,
       _updateProfile = updateProfile,
       _getLionPoints = getLionPoints,
       _logout = logout,
       _storage = storage,
       _preferences = preferences,
       super(const AccountState()) {
    on<AccountStarted>(_onStarted);
    on<AccountSpeakingLanguageChanged>(_onSpeakingLanguage);
    on<AccountToggleChanged>(_onToggle);
    on<AccountProfileSaved>(_onProfileSaved);
    on<AccountLogoutRequested>(_onLogout);
    // Đăng nhập từ popup ở chỗ khác → tải lại.
    _auth = AuthEventBus.stream.listen((event) {
      if (event is UserLoggedIn && !isClosed) add(const AccountStarted());
    });
  }

  Future<void> _onStarted(
    AccountStarted event,
    Emitter<AccountState> emit,
  ) async {
    emit(
      state.copyWith(
        status: _storage.isLoggedIn
            ? (state.profile == null ? AccountStatus.loading : null)
            : AccountStatus.signedOut,
        sessionName: _storage.userName,
        speakingLanguage: _preferences.speakingLanguage,
        clearSpeakingLanguage: _preferences.speakingLanguage == null,
        autoTranslate: _preferences.autoTranslateChats,
        readAloud: _preferences.readRepliesAloud,
        attachVoice: _preferences.attachVoiceToRequests,
      ),
    );
    if (!_storage.isLoggedIn) return;
    await Future.wait([
      callApi(
        useCase: _getProfile,
        param: const NoParams(),
        onSuccess: (profile) async =>
            emit(state.copyWith(status: AccountStatus.ready, profile: profile)),
        // Lỗi vẫn hiện tên trong phiên.
        onFailure: (_) => emit(state.copyWith(status: AccountStatus.ready)),
      ),
      callApi(
        useCase: _getLionPoints,
        param: const NoParams(),
        onSuccess: (result) async => emit(
          state.copyWith(wallet: result.wallet, pointValue: result.pointValue),
        ),
        onFailure: (_) {},
      ),
    ]);
  }

  Future<void> _onSpeakingLanguage(
    AccountSpeakingLanguageChanged event,
    Emitter<AccountState> emit,
  ) async {
    await _preferences.setSpeakingLanguage(event.code);
    emit(
      state.copyWith(
        speakingLanguage: event.code,
        clearSpeakingLanguage: event.code == null,
      ),
    );
  }

  Future<void> _onToggle(
    AccountToggleChanged event,
    Emitter<AccountState> emit,
  ) async {
    switch (event.toggle) {
      case AccountToggle.autoTranslate:
        await _preferences.setAutoTranslateChats(event.value);
        emit(state.copyWith(autoTranslate: event.value));
      case AccountToggle.readAloud:
        await _preferences.setReadRepliesAloud(event.value);
        emit(state.copyWith(readAloud: event.value));
      case AccountToggle.attachVoice:
        await _preferences.setAttachVoiceToRequests(event.value);
        emit(state.copyWith(attachVoice: event.value));
    }
  }

  Future<void> _onProfileSaved(
    AccountProfileSaved event,
    Emitter<AccountState> emit,
  ) async {
    emit(state.copyWith(savingProfile: true));
    await callApi(
      useCase: _updateProfile,
      param: (
        firstName: event.firstName,
        lastName: event.lastName,
        city: event.city,
      ),
      onSuccess: (profile) async => emit(
        state.copyWith(
          profile: profile,
          sessionName: _storage.userName,
          savingProfile: false,
          notice: AccountNotice.profileSaved,
        ),
      ),
      onFailure: (_) => emit(
        state.copyWith(
          savingProfile: false,
          notice: AccountNotice.profileFailed,
        ),
      ),
    );
  }

  Future<void> _onLogout(
    AccountLogoutRequested event,
    Emitter<AccountState> emit,
  ) async {
    if (state.loggingOut) return;
    emit(state.copyWith(loggingOut: true));
    await callApi(
      useCase: _logout,
      param: const NoParams(),
      onSuccess: (_) async => emit(
        AccountState(
          status: AccountStatus.signedOut,
          speakingLanguage: state.speakingLanguage,
          autoTranslate: state.autoTranslate,
          readAloud: state.readAloud,
          attachVoice: state.attachVoice,
          notice: AccountNotice.loggedOut,
          noticeId: state.noticeId + 1,
        ),
      ),
      onFailure: (_) => emit(state.copyWith(loggingOut: false)),
    );
  }

  @override
  Future<void> close() async {
    await _auth.cancel();
    return super.close();
  }
}
