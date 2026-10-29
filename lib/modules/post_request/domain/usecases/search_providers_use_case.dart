import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';
import 'package:strongbody_buyer/core/usecases/usecase.dart';

import '../entities/provider_entity.dart';
import '../repositories/post_request_repository.dart';

class SearchProvidersParams extends Equatable {
  final String keyword;
  final int page;
  final int limit;

  const SearchProvidersParams({
    required this.keyword,
    this.page = 1,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [keyword, page, limit];
}

class SearchProvidersUseCase
    implements UseCase<ProviderPage, SearchProvidersParams> {
  final PostRequestRepository _repository;

  SearchProvidersUseCase(this._repository);

  @override
  Future<Either<Failure, ProviderPage>> call(SearchProvidersParams params) =>
      _repository.searchProviders(
        keyword: params.keyword,
        page: params.page,
        limit: params.limit,
      );
}
