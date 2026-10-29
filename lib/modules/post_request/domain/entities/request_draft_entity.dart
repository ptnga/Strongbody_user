import 'package:equatable/equatable.dart';

import 'request_form_values.dart';

/// Thông tin trợ lý AI gửi kèm khi đăng (BE lưu, không hiển thị trên form).
class RequestAssistantMeta extends Equatable {
  final List<int> categoryIds;
  final int? qualityScore;
  final String suggestion;

  const RequestAssistantMeta({
    this.categoryIds = const [],
    this.qualityScore,
    this.suggestion = '',
  });

  @override
  List<Object?> get props => [categoryIds, qualityScore, suggestion];
}

/// Kết quả AI soạn request: giá trị form + meta. `isEmpty` = AI coi nội dung rỗng/vô nghĩa.
class RequestDraftEntity extends Equatable {
  final RequestFormValues values;
  final bool isEmpty;
  final RequestAssistantMeta assistant;

  const RequestDraftEntity({
    required this.values,
    required this.isEmpty,
    required this.assistant,
  });

  @override
  List<Object?> get props => [values, isEmpty, assistant];
}
