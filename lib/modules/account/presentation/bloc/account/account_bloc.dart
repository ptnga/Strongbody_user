import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:strongbody_buyer/core/analytics/analytics_events.dart';
import 'package:strongbody_buyer/core/analytics/app_analytics.dart';
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
  final RequestAccountDeletionUseCase _requestDeletion;
  final VerifyAccountDeletionUseCase _verifyDeletion;
  final GlobalStorage _storage;
  final UserPreferences _preferences;
  late final StreamSubscription<AuthEvent> _auth;

  /// Mật khẩu đã nhập ở bước 1, để gửi lại mã (resend) mà không hỏi lại.
  String? _deletePassword;

  AccountBloc({
    required GetAccountProfileUseCase getProfile,
    required UpdateAccountProfileUseCase updateProfile,
    required GetLionPointsUseCase getLionPoints,
    required LogoutUseCase logout,
    required RequestAccountDeletionUseCase requestAccountDeletion,
    required VerifyAccountDeletionUseCase verifyAccountDeletion,
    required GlobalStorage storage,
    required UserPreferences preferences,
  }) : _getProfile = getProfile,
       _updateProfile = updateProfile,
       _getLionPoints = getLionPoints,
       _logout = logout,
       _requestDeletion = requestAccountDeletion,
       _verifyDeletion = verifyAccountDeletion,
       _storage = storage,
       _preferences = preferences,
       super(const AccountState()) {
    on<AccountStarted>(_onStarted);
    on<AccountSpeakingLanguageChanged>(_onSpeakingLanguage);
    on<AccountToggleChanged>(_onToggle);
    on<AccountProfileSaved>(_onProfileSaved);
    on<AccountLogoutRequested>(_onLogout);
    on<AccountDeletionRequested>(_onDeletionRequested);
    on<AccountDeletionVerified>(_onDeletionVerified);
    on<AccountDeletionCodeResent>(_onDeletionCodeResent);
    // Đăng nhập / đăng xuất ở chỗ khác (tab được giữ sống) → tải lại / về khách.
    _auth = AuthEventBus.stream.listen((event) {
      if (event is! UserProfileUpdated && !isClosed) {
        add(const AccountStarted());
      }
    });
  }

  Future<void> _onStarted(
    AccountStarted event,
    Emitter<AccountState> emit,
  ) async {
    // Khách / đổi tài khoản → bỏ hồ sơ + ví của người trước.
    final sameUser =
        _storage.isLoggedIn && state.profile?.id == _storage.userId;
    final base = sameUser ? state : const AccountState();
    emit(
      base.copyWith(
        status: _storage.isLoggedIn
            ? (base.profile == null ? AccountStatus.loading : null)
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
    AppAnalytics.capture(AnalyticsEvents.accountSettingChanged, {
      'setting': 'speaking_language',
      'value': event.code ?? 'auto',
    });
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
    AppAnalytics.capture(AnalyticsEvents.accountSettingChanged, {
      'setting': switch (event.toggle) {
        AccountToggle.autoTranslate => 'auto_translate',
        AccountToggle.readAloud => 'read_aloud',
        AccountToggle.attachVoice => 'attach_voice',
      },
      'value': event.value,
    });
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
      onSuccess: (profile) async {
        AppAnalytics.capture(AnalyticsEvents.profileUpdated);
        emit(
          state.copyWith(
            profile: profile,
            sessionName: _storage.userName,
            savingProfile: false,
            notice: AccountNotice.profileSaved,
          ),
        );
      },
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

  /// Bước 1: xác minh mật khẩu → BE gửi mã OTP tới email.
  Future<void> _onDeletionRequested(
    AccountDeletionRequested event,
    Emitter<AccountState> emit,
  ) async {
    if (state.deleting) return;
    _deletePassword = event.password;
    emit(state.copyWith(deleting: true, clearDeletionError: true));
    await callApi(
      useCase: _requestDeletion,
      param: event.password,
      onSuccess: (_) async => emit(
        state.copyWith(deleting: false, notice: AccountNotice.deletionCodeSent),
      ),
      onFailure: (message) => emit(
        state.copyWith(
          deleting: false,
          deletionError: message,
          notice: AccountNotice.accountDeleteFailed,
        ),
      ),
    );
  }

  /// Bước 2: gửi mã OTP để xác nhận; thành công mới xoá phiên.
  Future<void> _onDeletionVerified(
    AccountDeletionVerified event,
    Emitter<AccountState> emit,
  ) async {
    if (state.verifyingDeletion) return;
    emit(state.copyWith(verifyingDeletion: true, clearDeletionError: true));
    await callApi(
      useCase: _verifyDeletion,
      param: event.otp,
      onSuccess: (_) async {
        _deletePassword = null;
        emit(
          AccountState(
            status: AccountStatus.signedOut,
            speakingLanguage: state.speakingLanguage,
            autoTranslate: state.autoTranslate,
            readAloud: state.readAloud,
            attachVoice: state.attachVoice,
            notice: AccountNotice.accountDeleted,
            noticeId: state.noticeId + 1,
          ),
        );
      },
      onFailure: (message) => emit(
        state.copyWith(
          verifyingDeletion: false,
          deletionError: message,
          notice: AccountNotice.accountDeleteFailed,
        ),
      ),
    );
  }

  /// Gửi lại mã OTP: gọi lại bước 1 với mật khẩu đã lưu.
  Future<void> _onDeletionCodeResent(
    AccountDeletionCodeResent event,
    Emitter<AccountState> emit,
  ) async {
    final password = _deletePassword;
    if (password == null || state.deleting) return;
    emit(state.copyWith(deleting: true, clearDeletionError: true));
    await callApi(
      useCase: _requestDeletion,
      param: password,
      onSuccess: (_) async => emit(
        state.copyWith(
          deleting: false,
          notice: AccountNotice.deletionCodeResent,
        ),
      ),
      onFailure: (message) => emit(
        state.copyWith(
          deleting: false,
          deletionError: message,
          notice: AccountNotice.accountDeleteFailed,
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _auth.cancel();
    return super.close();
  }
}
