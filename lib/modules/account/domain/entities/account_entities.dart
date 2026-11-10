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

  /// Hạn của [expiringPoints] (`expiresAt`) — null thì không hiện dòng hết hạn (web
  /// `PointCard` không tự bịa ngày).
  final DateTime? expiresAt;

  const LionWallet({
    required this.id,
    required this.points,
    this.expiringPoints = 0,
    this.expiresAt,
  });

  /// Point service trả 404 "Customer not found" = user chưa có ví (web `EMPTY_WALLET`).
  static const empty = LionWallet(id: 0, points: 0);

  /// Chưa có ví thật → không có lịch sử để tải.
  bool get exists => id > 0;

  /// Web `PointCard`: chỉ hiện "N points will expire on …" khi có ngày thật và N > 0.
  bool get showsExpiry => expiresAt != null && expiringPoints > 0;

  @override
  List<Object?> get props => [id, points, expiringPoints, expiresAt];
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

/// referral / purchase / redemption có tiêu đề + mô tả riêng; other = `idempotencyKey` + `reason`.
enum LionLedgerKind { referral, purchase, redemption, other }

/// Một dòng lịch sử điểm (`/v1/transactions/wallets/{walletId}/ledger`).
class LionLedgerItem extends Equatable {
  final int id;
  final LionLedgerType type;

  /// Dương = cộng, âm = trừ (`amountCents`).
  final int amount;

  /// invite | purchase | …
  final String source;
  final String reason;

  /// Web dùng làm tiêu đề dự phòng khi không khớp loại/nguồn nào.
  final String idempotencyKey;
  final DateTime? at;

  const LionLedgerItem({
    required this.id,
    required this.type,
    required this.amount,
    this.source = '',
    this.reason = '',
    this.idempotencyKey = '',
    this.at,
  });

  /// Loại hiển thị theo web `HistoryItemList.getHistoryItemDisplay`.
  LionLedgerKind get kind => switch (type) {
    LionLedgerType.earn when source == 'invite' => LionLedgerKind.referral,
    LionLedgerType.earn when source == 'purchase' => LionLedgerKind.purchase,
    LionLedgerType.spend => LionLedgerKind.redemption,
    _ => LionLedgerKind.other,
  };

  @override
  List<Object?> get props => [
    id,
    type,
    amount,
    source,
    reason,
    idempotencyKey,
    at,
  ];
}
