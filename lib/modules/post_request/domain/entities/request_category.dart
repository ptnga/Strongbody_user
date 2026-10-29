/// 8 category chính thức mà AI request-draft của web phân loại
/// (`src/lib/ai/request-draft/prompt.ts` — mục 4 CATEGORY CLASSIFICATION).
/// Tên hiển thị dịch qua `LocaleKeys.requestCategory*`.
enum RequestCategory {
  fitness(96652),
  healthPro(96657),
  longevity(96655),
  mentalWellness(96659),
  beauty(96653),
  medicalTravel(96656),
  massageTherapy(96654),
  personalHelper(96658);

  const RequestCategory(this.id);

  final int id;

  static RequestCategory? fromId(int id) {
    for (final category in values) {
      if (category.id == id) return category;
    }
    return null;
  }
}
