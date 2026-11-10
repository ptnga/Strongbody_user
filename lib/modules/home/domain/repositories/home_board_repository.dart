import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';

import '../entities/board_entities.dart';

abstract class HomeBoardRepository {
  /// Board Requests: feed (lọc nước / chủ đề) hoặc search v2 khi có từ khoá / bộ lọc.
  Future<Either<Failure, BoardPage<BoardRequest>>> getRequests(
    BoardQuery query,
  );

  /// Board Offers (service): feed `order_by=recommended` hoặc search v2.
  Future<Either<Failure, BoardPage<BoardOffer>>> getOffers(BoardQuery query);

  /// Nước có item của board (facet, nhiều item trước).
  Future<Either<Failure, List<BoardCountry>>> getCountries(BoardKind kind);
}
