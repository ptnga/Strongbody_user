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

/// Bước 1: xác minh mật khẩu → BE gửi mã OTP tới email.
final class AccountDeletionRequested extends AccountEvent {
  final String password;

  const AccountDeletionRequested(this.password);

  @override
  List<Object?> get props => [password];
}

/// Bước 2: gửi mã OTP để xác nhận và xoá tài khoản.
final class AccountDeletionVerified extends AccountEvent {
  final String otp;

  const AccountDeletionVerified(this.otp);

  @override
  List<Object?> get props => [otp];
}

/// Gửi lại mã OTP (dùng lại mật khẩu đã nhập ở bước 1).
final class AccountDeletionCodeResent extends AccountEvent {
  const AccountDeletionCodeResent();
}
