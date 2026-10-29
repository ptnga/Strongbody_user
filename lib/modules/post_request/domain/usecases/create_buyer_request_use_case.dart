import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/request_draft_entity.dart';
import '../entities/request_form_values.dart';
import '../repositories/post_request_repository.dart';

class CreateBuyerRequestParams extends Equatable {
  final int userId;
  final RequestFormValues values;
  final RequestAssistantMeta? assistant;

  /// Rỗng = mọi provider phù hợp; có id = chỉ gửi cho các provider đã chọn.
  final List<int> sellerUserIds;

  /// Báo từng seller đã nhận (gửi lần lượt) — xem [PostRequestRepository.createBuyerRequest].
  final void Function(int sellerUserId)? onSellerPosted;

  const CreateBuyerRequestParams({
    required this.userId,
    required this.values,
    this.assistant,
    this.sellerUserIds = const [],
    this.onSellerPosted,
  });

  @override
  List<Object?> get props => [userId, values, assistant, sellerUserIds];
}

class CreateBuyerRequestUseCase
    implements UseCase<String?, CreateBuyerRequestParams> {
  final PostRequestRepository _repository;

  CreateBuyerRequestUseCase(this._repository);

  @override
  Future<Either<Failure, String?>> call(CreateBuyerRequestParams params) =>
      _repository.createBuyerRequest(
        userId: params.userId,
        values: params.values,
        assistant: params.assistant,
        sellerUserIds: params.sellerUserIds,
        onSellerPosted: params.onSellerPosted,
      );
}
