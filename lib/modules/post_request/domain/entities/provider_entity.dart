import 'package:equatable/equatable.dart';

import 'request_form_values.dart';

/// Provider (seller profile) trong danh sách "matching providers"
/// (`/user/strongbodyai/expert/balanced` của web, cùng shape `/public/profiles` của Multime).
class ProviderEntity extends Equatable {
  /// Seller profile id.
  final int id;

  /// User id của seller — dùng cho `seller_id` khi gửi request riêng.
  final int userId;
  final String slug;
  final String name;
  final String? avatarUrl;
  final String? profession;
  final String? country;
  final bool verified;
  final int yearsOfExperience;
  final double rating;
  final int reviewCount;
  final List<String> skills;

  /// Mã ngôn ngữ (vd `en`, `vi`); rỗng = provider chưa khai báo.
  final List<String> languages;

  const ProviderEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.slug = '',
    this.avatarUrl,
    this.profession,
    this.country,
    this.verified = false,
    this.yearsOfExperience = 0,
    this.rating = 0,
    this.reviewCount = 0,
    this.skills = const [],
    this.languages = const [],
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    slug,
    name,
    avatarUrl,
    profession,
    country,
    verified,
    yearsOfExperience,
    rating,
    reviewCount,
    skills,
    languages,
  ];
}

/// Một trang kết quả tìm provider + tổng số khớp.
class ProviderPage extends Equatable {
  final List<ProviderEntity> items;
  final int total;
  final int totalPage;

  const ProviderPage({
    required this.items,
    required this.total,
    required this.totalPage,
  });

  @override
  List<Object?> get props => [items, total, totalPage];
}

/// Khung giờ rảnh lặp lại hằng tuần của seller (`availabilities` ở profile chi tiết).
class WeeklySlot extends Equatable {
  /// `DateTime.weekday`: 1 = thứ 2 … 7 = chủ nhật.
  final int weekday;

  /// "HH:mm"
  final String startTime;
  final String endTime;

  const WeeklySlot({
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  @override
  List<Object?> get props => [weekday, startTime, endTime];
}

/// Thông tin bổ sung cho thẻ provider — lấy riêng từng người vì danh sách expert không có:
/// giá "from" + cách cung cấp (từ service của seller), lịch rảnh (từ profile chi tiết).
class ProviderExtras extends Equatable {
  final double? minPrice;
  final String? currency;

  /// Service tính theo buổi → hiện "/ session".
  final bool perSession;
  final Set<RequestDeliveryType> deliveryTypes;
  final List<WeeklySlot> slots;

  const ProviderExtras({
    this.minPrice,
    this.currency,
    this.perSession = false,
    this.deliveryTypes = const {},
    this.slots = const [],
  });

  static const empty = ProviderExtras();

  /// Lần rảnh gần nhất sau [from] trong 14 ngày tới; null nếu không có lịch.
  DateTime? nextAvailable(DateTime from) {
    for (var offset = 0; offset < 14; offset++) {
      final day = DateTime(
        from.year,
        from.month,
        from.day,
      ).add(Duration(days: offset));
      final starts =
          slots
              .where((s) => s.weekday == day.weekday)
              .map((s) => _at(day, s.startTime))
              .whereType<DateTime>()
              .where((t) => t.isAfter(from))
              .toList()
            ..sort();
      if (starts.isNotEmpty) return starts.first;
    }
    return null;
  }

  /// Có khung rảnh nào rơi vào các ngày [start]…[end] không.
  bool availableBetween(DateTime start, DateTime end) {
    final last = DateTime(end.year, end.month, end.day);
    for (
      var day = DateTime(start.year, start.month, start.day);
      !day.isAfter(last);
      day = day.add(const Duration(days: 1))
    ) {
      if (slots.any((s) => s.weekday == day.weekday)) return true;
    }
    return false;
  }

  static DateTime? _at(DateTime day, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  @override
  List<Object?> get props => [
    minPrice,
    currency,
    perSession,
    deliveryTypes,
    slots,
  ];
}
