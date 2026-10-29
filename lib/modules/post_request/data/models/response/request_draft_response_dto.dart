/// Response `POST /api/ai/request-draft` (web):
/// `{ draft: { description, budget, currency, deliveryTypes, deadline, schedule,
/// sellerLanguages, categoryIds }, empty, suggestion, rank }`.
class RequestDraftResponseDto {
  final RequestDraftDto? draft;
  final bool? empty;
  final String? suggestion;
  final int? rank;

  const RequestDraftResponseDto({
    this.draft,
    this.empty,
    this.suggestion,
    this.rank,
  });

  factory RequestDraftResponseDto.fromJson(Map<String, dynamic> json) {
    final draft = json['draft'];
    return RequestDraftResponseDto(
      draft: draft is Map
          ? RequestDraftDto.fromJson(Map<String, dynamic>.from(draft))
          : null,
      empty: json['empty'] as bool?,
      suggestion: json['suggestion']?.toString(),
      rank: (json['rank'] as num?)?.toInt(),
    );
  }
}

class RequestDraftDto {
  final String? description;
  final String? budget;
  final String? currency;
  final List<String> deliveryTypes;

  /// "YYYY-MM-DDTHH:mm" (giờ địa phương) hoặc rỗng.
  final String? deadline;

  /// `{ mon: [{from: "09:00", to: "12:00"}], ... }`
  final Map<String, List<Map<String, String>>> schedule;
  final List<String> sellerLanguages;
  final List<int> categoryIds;

  const RequestDraftDto({
    this.description,
    this.budget,
    this.currency,
    this.deliveryTypes = const [],
    this.deadline,
    this.schedule = const {},
    this.sellerLanguages = const [],
    this.categoryIds = const [],
  });

  factory RequestDraftDto.fromJson(Map<String, dynamic> json) {
    final rawSchedule = json['schedule'];
    final schedule = <String, List<Map<String, String>>>{};
    if (rawSchedule is Map) {
      rawSchedule.forEach((day, ranges) {
        if (ranges is! List) return;
        schedule[day.toString()] = [
          for (final r in ranges)
            if (r is Map)
              {
                'from': r['from']?.toString() ?? '',
                'to': r['to']?.toString() ?? '',
              },
        ];
      });
    }
    return RequestDraftDto(
      description: json['description']?.toString(),
      budget: json['budget']?.toString(),
      currency: json['currency']?.toString(),
      deliveryTypes: _strings(json['deliveryTypes']),
      deadline: json['deadline']?.toString(),
      schedule: schedule,
      sellerLanguages: _strings(json['sellerLanguages']),
      categoryIds: (json['categoryIds'] is List)
          ? (json['categoryIds'] as List)
                .map((e) => int.tryParse(e.toString()))
                .whereType<int>()
                .toList()
          : const [],
    );
  }

  static List<String> _strings(dynamic value) =>
      value is List ? value.map((e) => e.toString()).toList() : const [];
}
