import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';

abstract class HomeRepository {
  /// Số offer mới (pending) trên các request của buyer.
  Future<Either<Failure, int>> getNewOffersCount();
}
