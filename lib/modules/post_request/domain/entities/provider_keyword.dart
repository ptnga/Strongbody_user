/// Từ khoá nghề để tìm provider. `/expert/balanced?keyword=` chỉ khớp tốt với 1 từ nghề
/// ("physiotherapist" ra kết quả, "lower back pain" thì không).
class ProviderKeyword {
  ProviderKeyword._();

  /// Tên nghề xuất hiện trong nội dung (en/vi); không có thì theo category AI phân loại.
  static String? fromText(String text, List<int> categoryIds) {
    final lower = text.toLowerCase();
    for (final entry in _professionKeywords.entries) {
      if (entry.value.any(lower.contains)) return entry.key;
    }
    for (final id in categoryIds) {
      final keyword = _categoryKeywords[id];
      if (keyword != null) return keyword;
    }
    return null;
  }

  /// Gõ từ khoá ngắn ở Home ("physio", "yoga teacher") → dùng luôn làm từ khoá; câu dài
  /// không khớp nghề nào → rỗng (danh sách chung).
  static String fromSearch(String text) {
    final q = text.trim();
    return q.isNotEmpty && q.split(RegExp(r'\s+')).length <= 3 ? q : '';
  }

  /// Từ khoá BE → các cách nói trong câu (en + vi). Thứ tự = độ ưu tiên.
  static const Map<String, List<String>> _professionKeywords = {
    'physiotherapist': [
      'physiotherap',
      'physical therap',
      'vật lý trị liệu',
      'vật lí trị liệu',
    ],
    'chiropractor': ['chiropract', 'nắn chỉnh'],
    'yoga': ['yoga'],
    'pilates': ['pilates'],
    'nutrition': ['nutrition', 'dietitian', 'diet ', 'dinh dưỡng', 'ăn kiêng'],
    'massage': ['massage', 'mát xa', 'mát-xa', 'xoa bóp'],
    'acupuncture': ['acupunct', 'châm cứu'],
    'psychologist': ['psycholog', 'tâm lý', 'tâm lí'],
    'therapist': ['therapist', 'counsel', 'trị liệu', 'tư vấn tâm'],
    'trainer': [
      'personal trainer',
      'trainer',
      'fitness',
      'gym',
      'huấn luyện viên',
      'tập luyện',
    ],
    'coach': ['coach'],
    'dermatologist': ['dermatolog', 'da liễu'],
    'beauty': ['skincare', 'beauty', 'spa', 'làm đẹp', 'chăm sóc da'],
    'caregiver': [
      'caregiver',
      'carer',
      'nursing',
      'người chăm sóc',
      'chăm sóc người',
    ],
    'doctor': ['doctor', 'physician', 'bác sĩ'],
    'meditation': ['meditat', 'thiền'],
  };

  static const Map<int, String> _categoryKeywords = {
    96652: 'trainer',
    96657: 'doctor',
    96655: 'longevity',
    96659: 'therapist',
    96653: 'beauty',
    96656: 'medical',
    96654: 'massage',
    96658: 'caregiver',
  };
}
