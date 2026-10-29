part of 'account_bloc.dart';

enum AccountStatus { loading, ready, signedOut }

enum AccountNotice { profileSaved, profileFailed, loggedOut }

class AccountState extends Equatable {
  final AccountStatus status;

  /// null khi chưa tải xong (UI dùng tên trong phiên tạm thời).
  final AccountProfile? profile;
  final String? sessionName;
  final LionWallet? wallet;

  /// USD / điểm; null = không quy đổi được.
  final double? pointValue;
  final String? speakingLanguage;
  final bool autoTranslate;
  final bool readAloud;
  final bool attachVoice;
  final bool savingProfile;
  final bool loggingOut;
  final AccountNotice? notice;
  final int noticeId;

  const AccountState({
    this.status = AccountStatus.loading,
    this.profile,
    this.sessionName,
    this.wallet,
    this.pointValue,
    this.speakingLanguage,
    this.autoTranslate = false,
    this.readAloud = false,
    this.attachVoice = true,
    this.savingProfile = false,
    this.loggingOut = false,
    this.notice,
    this.noticeId = 0,
  });

  String get displayName {
    final name = profile?.fullName ?? '';
    return name.isNotEmpty ? name : (sessionName ?? '');
  }

  /// Giá trị điểm ra USD; null nếu thiếu dữ liệu.
  double? get pointsWorth {
    final points = wallet?.points;
    final value = pointValue;
    return points == null || value == null ? null : points * value;
  }

  AccountState copyWith({
    AccountStatus? status,
    AccountProfile? profile,
    bool clearProfile = false,
    String? sessionName,
    LionWallet? wallet,
    bool clearWallet = false,
    double? pointValue,
    String? speakingLanguage,
    bool clearSpeakingLanguage = false,
    bool? autoTranslate,
    bool? readAloud,
    bool? attachVoice,
    bool? savingProfile,
    bool? loggingOut,
    AccountNotice? notice,
  }) {
    return AccountState(
      status: status ?? this.status,
      profile: clearProfile ? null : (profile ?? this.profile),
      sessionName: sessionName ?? this.sessionName,
      wallet: clearWallet ? null : (wallet ?? this.wallet),
      pointValue: pointValue ?? this.pointValue,
      speakingLanguage: clearSpeakingLanguage
          ? null
          : (speakingLanguage ?? this.speakingLanguage),
      autoTranslate: autoTranslate ?? this.autoTranslate,
      readAloud: readAloud ?? this.readAloud,
      attachVoice: attachVoice ?? this.attachVoice,
      savingProfile: savingProfile ?? this.savingProfile,
      loggingOut: loggingOut ?? this.loggingOut,
      notice: notice ?? this.notice,
      noticeId: notice != null ? noticeId + 1 : noticeId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    profile,
    sessionName,
    wallet,
    pointValue,
    speakingLanguage,
    autoTranslate,
    readAloud,
    attachVoice,
    savingProfile,
    loggingOut,
    notice,
    noticeId,
  ];
}
