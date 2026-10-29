part of 'account_bloc.dart';

sealed class AccountEvent extends Equatable {
  const AccountEvent();

  @override
  List<Object?> get props => [];
}

/// Tải profile + Lion Points (cũng dùng cho kéo để làm mới).
final class AccountStarted extends AccountEvent {
  const AccountStarted();
}

final class AccountSpeakingLanguageChanged extends AccountEvent {
  /// null = Auto-detect.
  final String? code;

  const AccountSpeakingLanguageChanged(this.code);

  @override
  List<Object?> get props => [code];
}

enum AccountToggle { autoTranslate, readAloud, attachVoice }

final class AccountToggleChanged extends AccountEvent {
  final AccountToggle toggle;
  final bool value;

  const AccountToggleChanged(this.toggle, this.value);

  @override
  List<Object?> get props => [toggle, value];
}

final class AccountProfileSaved extends AccountEvent {
  final String firstName;
  final String lastName;
  final String city;

  const AccountProfileSaved({
    required this.firstName,
    required this.lastName,
    required this.city,
  });

  @override
  List<Object?> get props => [firstName, lastName, city];
}

final class AccountLogoutRequested extends AccountEvent {
  const AccountLogoutRequested();
}
