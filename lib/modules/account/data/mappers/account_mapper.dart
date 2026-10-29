import '../../domain/entities/account_entities.dart';

class AccountMapper {
  const AccountMapper._();

  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty || s == 'null' ? null : s;
  }

  static int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');

  /// User của `/buyer/auth/me` (cùng shape `user` trong request feed / login).
  static AccountProfile? profile(Map<String, dynamic> json) {
    final id = _int(json['id'] ?? json['user_id']);
    if (id == null) return null;
    final country = json['country'] ?? json['Country'];
    final languages = <String>[];
    void addLanguage(Object? raw) {
      final value = raw is Map
          ? _str(raw['code'] ?? raw['language_code'] ?? raw['name'])
          : _str(raw);
      if (value == null) return;
      for (final part in value.split(',')) {
        final code = part.trim();
        if (code.isNotEmpty && !languages.contains(code)) languages.add(code);
      }
    }

    addLanguage(json['language']);
    final list = json['languages'] ?? json['spoken_languages'];
    if (list is List) list.forEach(addLanguage);

    return AccountProfile(
      id: id,
      firstName: _str(json['first_name']) ?? '',
      lastName: _str(json['last_name']) ?? '',
      email: _str(json['email']),
      avatarUrl: _str(json['profile_picture'] ?? json['avatar']),
      city: _str(json['city']) ?? _str(json['state']),
      country: country is Map ? _str(country['title']) : _str(country),
      languages: languages,
    );
  }

  static LionWallet? wallet(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id == null) return null;
    return LionWallet(
      id: id,
      points: _int(json['balanceCents'] ?? json['balance_cents']) ?? 0,
      expiringPoints: _int(json['expiredCents'] ?? json['expired_cents']) ?? 0,
    );
  }

  /// `data.list[0].value_json.value_of_1_point` của `/admin/app-settings`.
  static double? pointValue(Map<String, dynamic> data) {
    final list = data['list'];
    if (list is! List || list.isEmpty || list.first is! Map) return null;
    final valueJson = (list.first as Map)['value_json'];
    final value = valueJson is Map ? valueJson['value_of_1_point'] : null;
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return parsed == null || parsed <= 0 ? null : parsed;
  }

  static LionLedgerItem? ledgerItem(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id == null) return null;
    return LionLedgerItem(
      id: id,
      type: LionLedgerType.fromApi(_str(json['type'])),
      amount: _int(json['amountCents'] ?? json['amount_cents']) ?? 0,
      source: _str(json['source']) ?? '',
      reason: _str(json['reason']) ?? '',
      at: DateTime.tryParse(
        _str(json['eventAt'] ?? json['createdAt']) ?? '',
      )?.toLocal(),
    );
  }
}
