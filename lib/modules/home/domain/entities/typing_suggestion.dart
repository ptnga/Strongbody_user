import 'package:equatable/equatable.dart';

/// Gợi ý khi gõ ở ô "Ask StrongBody". Web/Multime không có API gợi ý từ khoá → ghép từ
/// nghề / kỹ năng của provider khớp chữ đang gõ (API expert như web `getExperts`) và bộ
/// từ sẵn có, rồi UI dựng câu "… near me", "… for … at home", "… who speaks …".
class TypingSuggestionSeed extends Equatable {
  /// Chữ người dùng đang gõ (đã trim).
  final String query;

  /// Nghề khớp nhất ("physiotherapist"); = [query] nếu không khớp gì.
  final String primary;

  /// Nghề / cụm khớp thứ hai ("physiotherapy").
  final String? secondary;

  /// Vấn đề hay gặp của nghề đó ("back pain") — câu "… for back pain at home".
  final String? concern;

  const TypingSuggestionSeed({
    required this.query,
    required this.primary,
    this.secondary,
    this.concern,
  });

  /// Chỉ gợi ý khi đang gõ từ khoá ngắn (2+ ký tự, tối đa 4 từ) — câu dài thì để gửi.
  static bool accepts(String text) {
    final q = text.trim();
    return q.length >= 2 && q.split(RegExp(r'\s+')).length <= 4;
  }

  /// Ghép gợi ý; [remoteTerms] = nghề + kỹ năng của provider tìm được (có thể rỗng),
  /// [remoteConcerns] = kỹ năng hay gặp nhất của họ.
  static TypingSuggestionSeed build(
    String text, {
    List<String> remoteTerms = const [],
    List<String> remoteConcerns = const [],
  }) {
    final query = text.trim();
    // Nghề / kỹ năng provider thật trước, bộ từ sẵn có sau.
    final terms = <String>{
      ...matchTerms(query, remoteTerms.where(_isTidy)),
      ...matchTerms(query, _vocabulary),
    }.toList();
    final primary = terms.firstOrNull ?? query;
    final secondary = terms.length > 1 ? terms[1] : null;
    final lowerQuery = query.toLowerCase();
    final concern =
        remoteConcerns
            .where(_isTidy)
            .map((c) => c.trim().toLowerCase())
            .where((c) => c.length <= 24 && !c.contains(lowerQuery))
            .firstOrNull ??
        _concernFor(secondary ?? primary);
    return TypingSuggestionSeed(
      query: query,
      primary: primary,
      secondary: secondary,
      concern: concern,
    );
  }

  /// Cụm khớp [query]: cả cụm bắt đầu bằng query trước, rồi có một từ bắt đầu bằng query;
  /// ngắn trước, bỏ trùng, không lấy chính query.
  static List<String> matchTerms(String query, Iterable<String> candidates) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final whole = <String>[];
    final word = <String>[];
    final seen = <String>{q};
    for (final raw in candidates) {
      final term = raw.trim().toLowerCase();
      if (term.isEmpty || !seen.add(term)) continue;
      if (term.startsWith(q)) {
        whole.add(term);
      } else if (term.split(RegExp(r'[\s/-]+')).any((w) => w.startsWith(q))) {
        word.add(term);
      }
    }
    int byLength(String a, String b) => a.length.compareTo(b.length);
    return [...whole..sort(byLength), ...word..sort(byLength)];
  }

  /// Nghề / kỹ năng do provider tự nhập có thể là cả câu → chỉ lấy cụm gọn (≤ 3 từ).
  static bool _isTidy(String raw) {
    final text = raw.trim();
    return text.isNotEmpty &&
        text.length <= 32 &&
        text.split(RegExp(r'\s+')).length <= 3 &&
        !RegExp(r'[&,.;:()/]').hasMatch(text);
  }

  static String? _concernFor(String term) {
    for (final entry in _concerns.entries) {
      if (term.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Nghề / dịch vụ phổ biến (en + vi) — gợi ý ngay khi chưa có kết quả API.
  static const _vocabulary = [
    'physiotherapist',
    'physiotherapy',
    'physical therapist',
    'personal trainer',
    'fitness coach',
    'yoga teacher',
    'pilates instructor',
    'nutritionist',
    'dietitian',
    'massage therapist',
    'sports massage',
    'psychologist',
    'therapist',
    'life coach',
    'sleep coach',
    'chiropractor',
    'acupuncture',
    'dermatologist',
    'skincare specialist',
    'caregiver',
    'home nurse',
    'doctor',
    'meditation coach',
    'vật lý trị liệu',
    'huấn luyện viên cá nhân',
    'chuyên gia dinh dưỡng',
    'mát xa trị liệu',
    'bác sĩ',
    'chuyên gia tâm lý',
    'châm cứu',
    'chăm sóc da',
    'người chăm sóc',
    'thiền',
  ];

  /// Vấn đề hay gặp theo nghề (khớp chuỗi con, theo thứ tự).
  static const _concerns = {
    'physio': 'back pain',
    'physical': 'back pain',
    'chiro': 'back pain',
    'trainer': 'weight loss',
    'fitness': 'weight loss',
    'nutri': 'weight loss',
    'diet': 'weight loss',
    'massage': 'stress relief',
    'yoga': 'flexibility',
    'pilates': 'core strength',
    'psych': 'anxiety',
    'therap': 'anxiety',
    'sleep': 'better sleep',
    'derma': 'acne',
    'skin': 'acne',
    'vật lý': 'đau lưng',
    'huấn luyện': 'giảm cân',
    'dinh dưỡng': 'giảm cân',
    'mát xa': 'giảm căng thẳng',
    'tâm lý': 'lo âu',
    'chăm sóc da': 'mụn',
  };

  @override
  List<Object?> get props => [query, primary, secondary, concern];
}
