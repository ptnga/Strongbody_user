/// Mapping CỐ ĐỊNH (bảng Mapping.docx, web `_category/needMapping.ts`) giữa 4 nhãn
/// "Browse by need" và các category doanh nghiệp (clinic / wellness / health_product) +
/// profession Health expert. Nhãn KHÔNG còn là category: trang của nhãn hiện mỗi category
/// một section service, section expert lọc theo category (doanh nghiệp) HOẶC profession
/// (expert). Giá trị là slug API; thứ tự = thứ tự section trên trang.
class MarketNeed {
  /// Category Clinic / Wellness — mỗi cái một section service.
  final List<String> services;

  /// Category Health product (app chưa có product — chỉ dùng để lọc expert).
  final List<String> products;

  /// Profession Health expert (con của "Profession 2026") — lọc section expert.
  final List<String> professions;

  const MarketNeed({
    required this.services,
    this.products = const [],
    required this.professions,
  });

  /// Mapping theo route của trang (`longevity`, `mental`, `personal-helper`,
  /// `medical-travel`); null = không phải trang nhãn.
  static MarketNeed? byRoute(String? route) => _needs[route];

  /// Phạm vi service của listing (web `needScope`): [sub] (chip đang chọn) nếu thuộc nhãn,
  /// không thì cả danh sách; nhãn rỗng → slug không tồn tại để BE trả rỗng thay vì bỏ lọc.
  String servicesScope([String? sub]) {
    if (sub != null && services.contains(sub)) return sub;
    return services.isEmpty ? 'none' : services.join(',');
  }

  /// Seller của nhãn (web `needProvidersScope`): doanh nghiệp thuộc mọi category của nhãn
  /// + expert có profession của nhãn (BE kết hợp OR).
  Map<String, dynamic> get providersScope => {
    if ([...services, ...products].isNotEmpty)
      'provider_category_slugs': [...services, ...products].join(','),
    if (professions.isNotEmpty) 'profession_slugs': professions.join(','),
  };

  static const _needs = <String, MarketNeed>{
    'longevity': MarketNeed(
      services: [
        'general-hospital',
        'rehabilitation-hospital',
        'general-practice-family-medicine-clinic',
        'multispecialty-clinic-polyclinic',
        'cardiology-clinic',
        'endocrinology-diabetes-clinic',
        'clinical-nutrition-dietetics-clinic',
        'obesity-bariatric-clinic',
        'physiotherapy-physical-therapy-clinic',
        'clinical-rehabilitation-center',
        'fitness-center-gym',
        'yoga-studio-center',
        'pilates-studio',
        'meditation-mindfulness-center',
        'health-wellness-coaching-company',
        'spa-wellness-center',
        'massage-studio-center',
        'thermal-mineral-springs-center',
        'wellness-retreat-center',
        'wellness-resort-hotel',
        'corporate-wellness-provider',
      ],
      products: [
        'general-health-wellness-supplier',
        'supplements-vitamins-supplier',
        'medical-equipment-supplies-supplier',
        'skincare-dermocosmetics-supplier',
        'pharmacy-2',
      ],
      professions: [
        'medical-doctor-2',
        'pharmacist-2026',
        'physiotherapist-physical-therapist',
        'occupational-therapist',
        'exercise-physiologist',
        'dietitian',
        'nutritionist-2',
        'personal-trainer-fitness-instructor',
        'health-wellness-coach',
        'yoga-teacher-instructor',
        'pilates-instructor-2',
        'massage-therapist-2',
        'traditional-medicine-practitioner-2026',
      ],
    ),
    'mental': MarketNeed(
      services: [
        'general-hospital',
        'psychiatric-hospital',
        'mental-health-clinic-center',
        'yoga-studio-center',
        'pilates-studio',
        'meditation-mindfulness-center',
        'health-wellness-coaching-company',
        'wellness-retreat-center',
        'wellness-resort-hotel',
        'corporate-wellness-provider',
      ],
      professions: [
        'psychologist-2026',
        'counsellor-mental-health-counselor',
        'psychotherapist-2',
        'marriage-family-therapist',
        'health-wellness-coach',
        'yoga-teacher-instructor',
      ],
    ),
    'personal-helper': MarketNeed(
      services: [
        'home-healthcare-provider',
        'fitness-center-gym',
        'yoga-studio-center',
        'pilates-studio',
        'health-wellness-coaching-company',
        'non-medical-home-care-agency',
        'adult-day-care-center',
        'assisted-living-residential-care-facility',
      ],
      products: ['medical-equipment-supplies-supplier'],
      professions: [
        'nurse',
        'midwife-2026',
        'physiotherapist-physical-therapist',
        'occupational-therapist',
        'nutritionist-2',
        'personal-trainer-fitness-instructor',
        'health-wellness-coach',
        'yoga-teacher-instructor',
        'pilates-instructor-2',
        'massage-therapist-2',
        'caregiver-personal-care-assistant',
      ],
    ),
    'medical-travel': MarketNeed(
      services: [
        'general-hospital',
        'specialty-hospital',
        'children-s-hospital',
        'women-s-hospital',
        'rehabilitation-hospital',
        'psychiatric-hospital',
        'multispecialty-clinic-polyclinic',
        'dental-clinic',
        'ophthalmology-eye-clinic',
        'ent-otolaryngology-clinic',
        'dermatology-clinic',
        'cardiology-clinic',
        'cardiovascular-surgery-clinic',
        'vascular-surgery-clinic',
        'respiratory-pulmonology-clinic',
        'gastroenterology-clinic',
        'endocrinology-diabetes-clinic',
        'nephrology-clinic',
        'urology-clinic',
        'neurology-clinic',
        'neurosurgery-clinic',
        'orthopedics-clinic',
        'rheumatology-clinic',
        'allergy-clinical-immunology-clinic',
        'infectious-diseases-clinic',
        'oncology-clinic',
        'general-surgery-clinic',
        'obstetrics-gynecology-clinic',
        'fertility-reproductive-medicine-clinic',
        'pediatric-clinic',
        'mental-health-clinic-center',
        'obesity-bariatric-clinic',
        'physiotherapy-physical-therapy-clinic',
        'clinical-rehabilitation-center',
        'medical-aesthetics-clinic',
        'plastic-surgery-clinic',
        'hair-transplant-clinic',
        'diagnostic-imaging-center',
        'medical-laboratory-pathology-laboratory',
        'dialysis-center',
        'ambulatory-day-surgery-center',
        'medical-travel-agency',
      ],
      professions: ['dentist-2026'],
    ),
  };

  /// Tên category doanh nghiệp theo ngôn ngữ (web `needCategoryName`): tiếng Việt theo
  /// Mapping.docx, locale khác dùng tên trong API.
  static String categoryName(String slug, String name, String locale) =>
      (locale == 'vi' ? _namesVi[slug] : null) ?? name;

  static const _namesVi = <String, String>{
    'general-hospital': 'Bệnh viện đa khoa',
    'specialty-hospital': 'Bệnh viện chuyên khoa',
    'children-s-hospital': 'Bệnh viện nhi',
    'women-s-hospital': 'Bệnh viện chuyên về sức khỏe phụ nữ',
    'rehabilitation-hospital': 'Bệnh viện phục hồi chức năng',
    'psychiatric-hospital': 'Bệnh viện tâm thần',
    'general-practice-family-medicine-clinic':
        'Phòng khám đa khoa ban đầu / Y học gia đình',
    'multispecialty-clinic-polyclinic': 'Phòng khám đa khoa',
    'dental-clinic': 'Phòng khám nha khoa',
    'ophthalmology-eye-clinic': 'Phòng khám mắt',
    'ent-otolaryngology-clinic': 'Phòng khám tai mũi họng',
    'dermatology-clinic': 'Phòng khám da liễu',
    'cardiology-clinic': 'Phòng khám tim mạch',
    'cardiovascular-surgery-clinic':
        'Phòng khám chuyên khoa phẫu thuật tim mạch',
    'vascular-surgery-clinic': 'Phòng khám chuyên khoa phẫu thuật mạch máu',
    'respiratory-pulmonology-clinic': 'Phòng khám hô hấp',
    'gastroenterology-clinic': 'Phòng khám tiêu hóa',
    'endocrinology-diabetes-clinic': 'Phòng khám nội tiết và đái tháo đường',
    'nephrology-clinic': 'Phòng khám nội thận',
    'urology-clinic': 'Phòng khám tiết niệu',
    'neurology-clinic': 'Phòng khám nội thần kinh',
    'neurosurgery-clinic': 'Phòng khám ngoại thần kinh',
    'orthopedics-clinic': 'Phòng khám chấn thương chỉnh hình',
    'rheumatology-clinic': 'Phòng khám cơ xương khớp — chuyên khoa thấp khớp',
    'allergy-clinical-immunology-clinic':
        'Phòng khám dị ứng và miễn dịch lâm sàng',
    'infectious-diseases-clinic': 'Phòng khám bệnh truyền nhiễm',
    'oncology-clinic': 'Phòng khám ung bướu',
    'general-surgery-clinic': 'Phòng khám ngoại tổng quát',
    'obstetrics-gynecology-clinic': 'Phòng khám sản phụ khoa',
    'fertility-reproductive-medicine-clinic':
        'Phòng khám hỗ trợ sinh sản và y học sinh sản',
    'pediatric-clinic': 'Phòng khám nhi',
    'mental-health-clinic-center':
        'Phòng khám / Trung tâm chăm sóc sức khỏe tâm thần',
    'clinical-nutrition-dietetics-clinic': 'Phòng khám dinh dưỡng lâm sàng',
    'obesity-bariatric-clinic':
        'Phòng khám điều trị béo phì và giảm cân y khoa',
    'physiotherapy-physical-therapy-clinic': 'Phòng khám vật lý trị liệu',
    'clinical-rehabilitation-center': 'Trung tâm phục hồi chức năng lâm sàng',
    'medical-aesthetics-clinic': 'Phòng khám thẩm mỹ y khoa',
    'plastic-surgery-clinic': 'Phòng khám phẫu thuật tạo hình và thẩm mỹ',
    'hair-transplant-clinic': 'Phòng khám cấy tóc',
    'integrative-medicine-clinic': 'Phòng khám y học tích hợp',
    'regenerative-medicine-clinic': 'Phòng khám y học tái tạo',
    'diagnostic-imaging-center': 'Trung tâm chẩn đoán hình ảnh',
    'medical-laboratory-pathology-laboratory':
        'Phòng xét nghiệm y khoa / Giải phẫu bệnh',
    'dialysis-center': 'Trung tâm lọc máu',
    'ambulatory-day-surgery-center':
        'Trung tâm phẫu thuật ngoại trú / Trong ngày',
    'home-healthcare-provider': 'Đơn vị chăm sóc y tế tại nhà',
    'fitness-center-gym': 'Trung tâm thể hình / Phòng gym',
    'yoga-studio-center': 'Studio / Trung tâm yoga',
    'pilates-studio': 'Studio Pilates',
    'meditation-mindfulness-center': 'Trung tâm thiền và chánh niệm',
    'health-wellness-coaching-company': 'Đơn vị coaching sức khỏe và lối sống',
    'spa-wellness-center': 'Spa / Trung tâm chăm sóc sức khỏe và thư giãn',
    'massage-studio-center': 'Cơ sở / Trung tâm massage',
    'thermal-mineral-springs-center': 'Cơ sở tắm khoáng và suối nước nóng',
    'wellness-retreat-center': 'Trung tâm retreat chăm sóc sức khỏe',
    'wellness-resort-hotel': 'Khu nghỉ dưỡng / Khách sạn chuyên wellness',
    'corporate-wellness-provider':
        'Đơn vị cung cấp chương trình sức khỏe cho doanh nghiệp',
    'non-medical-home-care-agency':
        'Đơn vị hỗ trợ sinh hoạt và chăm sóc tại nhà',
    'adult-day-care-center': 'Trung tâm chăm sóc ban ngày',
    'assisted-living-residential-care-facility':
        'Cơ sở lưu trú có hỗ trợ sinh hoạt',
    'medical-travel-agency': 'Đơn vị tổ chức du lịch y tế',
    'general-health-wellness-supplier':
        'Nhà cung cấp sản phẩm sức khỏe tổng hợp',
    'supplements-vitamins-supplier':
        'Nhà cung cấp thực phẩm bổ sung và vitamin',
    'medical-equipment-supplies-supplier':
        'Nhà cung cấp thiết bị và vật tư y tế',
    'skincare-dermocosmetics-supplier':
        'Nhà cung cấp sản phẩm chăm sóc da và dược mỹ phẩm',
    'pharmacy-2': 'Nhà thuốc',
  };
}
