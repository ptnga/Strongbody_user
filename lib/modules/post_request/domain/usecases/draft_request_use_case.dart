import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/request_draft_entity.dart';
import '../repositories/post_request_repository.dart';

class DraftRequestParams extends Equatable {
  final String text;
  final String locale;

  const DraftRequestParams({required this.text, required this.locale});

  @override
  List<Object?> get props => [text, locale];
}

class DraftRequestUseCase
    implements UseCase<RequestDraftEntity, DraftRequestParams> {
  final PostRequestRepository _repository;

  DraftRequestUseCase(this._repository);

  @override
  Future<Either<Failure, RequestDraftEntity>> call(DraftRequestParams params) =>
      _repository.draftRequest(text: params.text, locale: params.locale);
}
