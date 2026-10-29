import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import 'package:strongbody_buyer/core/base/failure.dart';

import '../../domain/repositories/home_repository.dart';
import '../datasources/remote/home_remote_datasource.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource _remote;

  HomeRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, int>> getNewOffersCount() async {
    try {
      return Right(await _remote.getNewOffersCount());
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['message']?.toString() : null;
      return Left(
        ServerFailure(
          message ?? 'Cannot load offers',
          statusCode: e.response?.statusCode,
        ),
      );
    } catch (e) {
      return Left(Failure(e.toString()));
    }
  }
}
