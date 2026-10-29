import 'package:equatable/equatable.dart';

/// Cách nhận hỗ trợ (multi-select). Nhiều loại → BE nhận 1 giá trị `all`.
enum RequestDeliveryType {
  remote('remote'),
  atHome('at_home'),
  atClinic('at_clinic');

  const RequestDeliveryType(this.apiValue);
  final String apiValue;

  static RequestDeliveryType? fromApi(String value) {
    for (final type in values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }
}

/// Ngày trong tuần — `key` khớp JSON schedule gửi lên BE.
enum WeekDay {
  mon,
  tue,
  wed,
  thu,
  fri,
  sat,
  sun;

  String get key => name;

  /// `DateTime.weekday` (1 = thứ 2) → [WeekDay].
  static WeekDay fromDate(DateTime date) => values[date.weekday - 1];
}

/// Khoảng giờ "HH:mm" – "HH:mm".
class TimeRange extends Equatable {
  final String from;
  final String to;

  const TimeRange({required this.from, required this.to});

  bool get isValid =>
      from.isNotEmpty && to.isNotEmpty && from.compareTo(to) < 0;

  Map<String, String> toJson() => {'from': from, 'to': to};

  @override
  List<Object?> get props => [from, to];
}

/// Giá trị request (mirror `RequestFormValues` của web `(home-marketplace)/_lib/forms.ts`
/// + voice note như Multime). Chỉ `description` + cách nhận là bắt buộc trên UI.
class RequestFormValues extends Equatable {
  /// Giới hạn mô tả theo thiết kế màn Review.
  static const maxDescription = 1000;

  final String description;

  /// Ô text tự do "amount or range" (vd `80` hoặc `60-80`).
  final String budget;
  final String currency;
  final List<RequestDeliveryType> deliveryTypes;

  /// Ngày bắt đầu cần (gửi BE ở field `deadline`, giống web).
  final DateTime? deadline;

  /// Ngày kết thúc của khoảng "When" (vd Sat 24 – Sun 25). null = một ngày.
  final DateTime? endDate;
  final Map<WeekDay, List<TimeRange>> schedule;
  final List<String> sellerLanguages;

  /// Đường dẫn file trên máy — không lưu được khi giữ request chờ đăng nhập.
  final List<String> attachmentPaths;

  /// Voice note (m4a) gửi kèm ở field `voice`.
  final String? voicePath;
  final Duration? voiceDuration;

  const RequestFormValues({
    this.description = '',
    this.budget = '',
    this.currency = 'USD',
    this.deliveryTypes = const [],
    this.deadline,
    this.endDate,
    this.schedule = const {},
    this.sellerLanguages = const [],
    this.attachmentPaths = const [],
    this.voicePath,
    this.voiceDuration,
  });

  bool get isScheduleEmpty =>
      !schedule.values.any((ranges) => ranges.any((r) => r.isValid));

  bool get hasVoice => voicePath != null;

  /// "80" → (80, 80); "60-80" → (60, 80); rỗng/không hợp lệ → (null, null).
  static final _budgetPattern = RegExp(
    r'^\s*[$€£]?\s*\d+([.,]\d+)?(\s*[–—-]\s*[$€£]?\s*\d+([.,]\d+)?)?\s*$',
  );

  /// Ô ngân sách hợp lệ: trống, một số, hoặc khoảng ("60–80", "$60-$80").
  static bool isValidBudgetText(String text) =>
      text.trim().isEmpty || _budgetPattern.hasMatch(text);

  ({double? min, double? max}) get parsedBudget {
    final text = budget.trim().replaceAll(RegExp('[–—]'), '-');
    if (text.isEmpty) return (min: null, max: null);
    final nums = text
        .split('-')
        .map((s) => double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), '')))
        .whereType<double>()
        .where((n) => n >= 0)
        .toList();
    if (nums.isEmpty) return (min: null, max: null);
    if (nums.length == 1) return (min: nums.first, max: nums.first);
    final a = nums[0];
    final b = nums[1];
    return (min: a < b ? a : b, max: a < b ? b : a);
  }

  RequestFormValues copyWith({
    String? description,
    String? budget,
    String? currency,
    List<RequestDeliveryType>? deliveryTypes,
    DateTime? deadline,
    DateTime? endDate,
    bool clearDates = false,
    Map<WeekDay, List<TimeRange>>? schedule,
    List<String>? sellerLanguages,
    List<String>? attachmentPaths,
    String? voicePath,
    Duration? voiceDuration,
    bool clearVoice = false,
  }) {
    return RequestFormValues(
      description: description ?? this.description,
      budget: budget ?? this.budget,
      currency: currency ?? this.currency,
      deliveryTypes: deliveryTypes ?? this.deliveryTypes,
      deadline: clearDates ? null : (deadline ?? this.deadline),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      schedule: schedule ?? this.schedule,
      sellerLanguages: sellerLanguages ?? this.sellerLanguages,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      voicePath: clearVoice ? null : (voicePath ?? this.voicePath),
      voiceDuration: clearVoice ? null : (voiceDuration ?? this.voiceDuration),
    );
  }

  /// Đổi khoảng ngày "When": lịch tuần lấy theo các ngày trong khoảng (09:00–17:00,
  /// cùng quy ước với AI của web khi ngày không kèm giờ).
  RequestFormValues withDateRange(DateTime start, DateTime? end) {
    final last = end ?? start;
    final days = <WeekDay>{};
    for (
      var d = DateTime(start.year, start.month, start.day);
      !d.isAfter(last) && days.length < 7;
      d = d.add(const Duration(days: 1))
    ) {
      days.add(WeekDay.fromDate(d));
    }
    return copyWith(
      deadline: DateTime(start.year, start.month, start.day, 9),
      endDate: end == null || _sameDay(start, end) ? null : end,
      schedule: {
        for (final day in days)
          day: const [TimeRange(from: '09:00', to: '17:00')],
      },
    );
  }

  /// Khoảng ngày suy ra từ AI: bắt đầu ở `deadline`, kéo dài qua các ngày liên tiếp
  /// có trong `schedule` (vd "this weekend" → Sat–Sun).
  RequestFormValues withRangeFromSchedule() {
    final start = deadline;
    if (start == null || schedule.isEmpty || endDate != null) return this;
    var end = start;
    for (var i = 1; i < 7; i++) {
      final next = start.add(Duration(days: i));
      if (!schedule.containsKey(WeekDay.fromDate(next))) break;
      end = next;
    }
    return _sameDay(start, end) ? this : copyWith(endDate: end);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Phần text/cấu trúc (bỏ file) — để lưu request chờ đăng nhập.
  Map<String, dynamic> toStorageJson() => {
    'description': description,
    'budget': budget,
    'currency': currency,
    'deliveryTypes': deliveryTypes.map((d) => d.apiValue).toList(),
    'deadline': deadline?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'schedule': {
      for (final entry in schedule.entries)
        entry.key.key: entry.value.map((r) => r.toJson()).toList(),
    },
    'sellerLanguages': sellerLanguages,
  };

  @override
  List<Object?> get props => [
    description,
    budget,
    currency,
    deliveryTypes,
    deadline,
    endDate,
    schedule,
    sellerLanguages,
    attachmentPaths,
    voicePath,
    voiceDuration,
  ];
}
