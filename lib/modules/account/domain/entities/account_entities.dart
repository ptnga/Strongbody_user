import 'package:equatable/equatable.dart';

/// Thông tin buyer (`GET /buyer/auth/me`).
class AccountProfile extends Equatable {
  final int id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? avatarUrl;
  final String? city;
  final String? country;

  /// Mã hoặc tên ngôn ngữ user khai báo (`language`, `languages`).
  final List<String> languages;

  const AccountProfile({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.email,
    this.avatarUrl,
    this.city,
    this.country,
    this.languages = const [],
  });

  String get fullName =>
      [firstName, lastName].where((s) => s.trim().isNotEmpty).join(' ');

  /// Thành phố, không có thì quốc gia.
  String? get place => city ?? country;

  @override
  List<Object?> get props => [
    id,
    firstName,
    lastName,
    email,
    avatarUrl,
    city,
    country,
    languages,
  ];
}

/// Ví Lion Points (point service `GET /v1/wallets/customer/{userId}`). Điểm = `balanceCents`.
class LionWallet extends Equatable {
  final int id;
  final int points;
  final int expiringPoints;

  const LionWallet({
    required this.id,
    required this.points,
    this.expiringPoints = 0,
  });

  @override
  List<Object?> get props => [id, points, expiringPoints];
}

enum LionLedgerType {
  earn,
  spend,
  expired;

  static LionLedgerType fromApi(String? value) => switch (value) {
    'spend' => spend,
    'expired' => expired,
    _ => earn,
  };
}

/// Một dòng lịch sử điểm (`/v1/transactions/wallets/{walletId}/ledger`).
class LionLedgerItem extends Equatable {
  final int id;
  final LionLedgerType type;

  /// Dương = cộng, âm = trừ (`amountCents`).
  final int amount;

  /// invite | purchase | …
  final String source;
  final String reason;
  final DateTime? at;

  const LionLedgerItem({
    required this.id,
    required this.type,
    required this.amount,
    this.source = '',
    this.reason = '',
    this.at,
  });

  @override
  List<Object?> get props => [id, type, amount, source, reason, at];
}
