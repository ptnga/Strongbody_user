import 'package:equatable/equatable.dart';

import 'request_form_values.dart';

/// Kết quả `POST /buyer/request`: id để mở trang "Providers for your request".
class CreatedRequest extends Equatable {
  final int? id;

  /// `active` = đã lên; còn lại = chờ duyệt.
  final String? status;

  const CreatedRequest({this.id, this.status});

  bool get isLive => status == 'active';

  @override
  List<Object?> get props => [id, status];
}

/// Request đã đăng (`GET /user/request/{id}`) — web `SentRequest`: đủ để tìm
/// chuyên gia phù hợp và chia sẻ vào chat.
class SentRequest extends Equatable {
  final int id;
  final String description;

  /// Ngân sách dạng chữ như ô nhập: "100" hoặc "120-150"; rỗng = không có.
  final String budget;
  final String currency;

  /// Rỗng khi `delivery_type = all` (mọi hình thức → không lọc theo nơi nhận).
  final List<RequestDeliveryType> deliveryTypes;
  final List<String> sellerLanguages;
  final List<int> categoryIds;
  final String? status;

  const SentRequest({
    required this.id,
    required this.description,
    this.budget = '',
    this.currency = 'USD',
    this.deliveryTypes = const [],
    this.sellerLanguages = const [],
    this.categoryIds = const [],
    this.status,
  });

  bool get isLive => status == 'active';

  @override
  List<Object?> get props => [
    id,
    description,
    budget,
    currency,
    deliveryTypes,
    sellerLanguages,
    categoryIds,
    status,
  ];
}

/// Một dòng bảng `currencies` (`GET /admin/currencies`) cho ô chọn tiền tệ.
class CurrencyOption extends Equatable {
  final int id;

  /// Mã ISO ("USD") — giá trị gửi ở field `currency`.
  final String code;

  const CurrencyOption({required this.id, required this.code});

  @override
  List<Object?> get props => [id, code];
}
